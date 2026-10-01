#!/usr/bin/env python3
"""One paid Lyria request at a time. Python standard library plus FFmpeg tools."""
from __future__ import annotations

import argparse
import base64
import binascii
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request

ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/interactions"
PRICING_URL = "https://ai.google.dev/gemini-api/docs/pricing"
PRICES = {"lyria-3.5": Decimal("0.08"), "lyria-3-clip-preview": Decimal("0.04")}
PRICE_CHECKED = "2026-09-18"
MAX_RESPONSE = 100 * 1024 * 1024


class MusicError(Exception):
    """An actionable failure with no credentials attached."""


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise MusicError("API redirect refused; credentials were not forwarded.")


def redact(text: str) -> str:
    for name in ("GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_GENERATIVE_AI_API_KEY"):
        secret = os.environ.get(name)
        if secret:
            text = text.replace(secret, "[REDACTED]")
    return re.sub(r"AIza[A-Za-z0-9_-]{20,}", "[REDACTED]", text)[:1500]


def price_limit(value: str) -> Decimal:
    try:
        result = Decimal(value)
    except InvalidOperation as exc:
        raise argparse.ArgumentTypeError("Cost limit must be a decimal USD amount.") from exc
    if not result.is_finite() or result < 0:
        raise argparse.ArgumentTypeError("Cost limit must be finite and nonnegative.")
    return result


def write_json(path: Path, data: dict) -> None:
    # Atomic replacement is only used for this run's own receipt.
    temporary = path.with_suffix(".tmp")
    with temporary.open("x", encoding="utf-8") as stream:
        json.dump(data, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    os.replace(temporary, path)


def make_request(args) -> tuple[dict, dict]:
    prompt = args.prompt_file.read_text(encoding="utf-8-sig") if args.prompt_file else args.prompt
    if not prompt or not prompt.strip():
        raise MusicError("Prompt must not be empty.")
    if len(prompt.encode("utf-8")) > 65536:
        raise MusicError("Prompt exceeds this helper's 64 KiB limit.")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", args.name):
        raise MusicError("Name must be 1-64 ASCII letters, digits, underscores or hyphens.")
    if args.model == "lyria-3-clip-preview" and args.format != "mp3":
        raise MusicError("The clip model supports MP3 only. Use lyria-3.5 for WAV.")
    request = {"model": args.model, "input": prompt}
    if args.format == "wav":
        request["response_format"] = {"type": "audio"}
    receipt = {
        "schema_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "provider": "Google Gemini API",
        "endpoint": ENDPOINT,
        "requested_model": args.model,
        "reported_model": None,
        "prompt": prompt,
        "requested_format": args.format,
        "pricing": {
            "estimated_usd": str(PRICES[args.model]),
            "checked_on": PRICE_CHECKED,
            "source": PRICING_URL,
            "actual_billed_usd": None,
            "note": "Published estimate, not a provider-enforced spending cap. Verify current pricing.",
        },
        "watermark": "Google documents SynthID on generated music; not detected locally.",
        "listening_review": "pending",
        "approval_state": "not approved for final use",
        "status": "planned",
    }
    return request, receipt


def reserve_run(parent: Path, name: str) -> Path:
    parent.mkdir(parents=True, exist_ok=True)
    for version in range(1, 10000):
        path = parent / f"{name}-v{version:03d}"
        try:
            path.mkdir(mode=0o700)
        except FileExistsError:
            continue
        return path.resolve()
    raise MusicError("No unused versioned output directory remains.")


def post(request: dict, key: str, timeout: int) -> bytes:
    req = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(request).encode("utf-8"),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
        method="POST",
    )
    # No automatic retry: a timed-out POST may already have incurred a charge.
    opener = urllib.request.build_opener(NoRedirect())
    try:
        with opener.open(req, timeout=timeout) as response:
            raw = response.read(MAX_RESPONSE + 1)
    except urllib.error.HTTPError as exc:
        with exc:
            body = redact(exc.read(8192).decode("utf-8", errors="replace"))
        raise MusicError(f"Gemini HTTP {exc.code}: {body}. No retry was made.") from None
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise MusicError(f"Request failed: {redact(str(exc))}. Billing outcome may be unknown; do not blindly resubmit.") from None
    if len(raw) > MAX_RESPONSE:
        raise MusicError("API response exceeded 100 MiB; generation may have been billed. No retry was made.")
    return raw


def parse_audio(response: dict) -> tuple[bytes, str]:
    if not isinstance(response, dict):
        raise MusicError("API response must be a JSON object.")
    if response.get("error"):
        raise MusicError("API returned an error: " + redact(json.dumps(response["error"])))
    if response.get("status") not in (None, "completed"):
        raise MusicError(f"Interaction is not completed: {response.get('status')}. Retain the response; do not resubmit.")
    # Current Interactions API uses steps; older releases used outputs.
    if "steps" in response:
        blocks = [block for step in response["steps"] if step.get("type") == "model_output"
                  for block in step.get("content", [])]
    else:
        blocks = response.get("outputs", [])
    audio = [block for block in blocks if block.get("type") == "audio"]
    if len(audio) != 1:
        raise MusicError(f"Expected one audio block, received {len(audio)}. Response retained; no automatic retry.")
    try:
        data = base64.b64decode(audio[0]["data"], validate=True)
    except (KeyError, ValueError, TypeError, binascii.Error) as exc:
        raise MusicError("Audio block does not contain valid base64 data.") from exc
    if not data:
        raise MusicError("Generated audio is empty.")
    lyrics = "\n\n".join(block["text"] for block in blocks if block.get("type") == "text")
    return data, lyrics


def validate_audio(path: Path, requested_format: str, tools: dict) -> dict:
    probe = subprocess.run(
        [tools["ffprobe"], "-v", "error", "-show_entries",
         "format=duration,format_name:stream=codec_type,codec_name,sample_rate,channels",
         "-of", "json", str(path)], capture_output=True, text=True, timeout=60, check=False,
    )
    if probe.returncode:
        raise MusicError("ffprobe rejected the audio: " + redact(probe.stderr))
    info = json.loads(probe.stdout)
    streams = [s for s in info.get("streams", []) if s.get("codec_type") == "audio"]
    duration = float(info.get("format", {}).get("duration", 0))
    if len(streams) != 1 or not math.isfinite(duration) or duration <= 0:
        raise MusicError("Expected one audio stream with a positive, finite duration.")
    stream = streams[0]
    if int(stream.get("sample_rate", 0)) <= 0 or int(stream.get("channels", 0)) <= 0:
        raise MusicError("Invalid sample rate or channel count.")
    formats = info.get("format", {}).get("format_name", "").split(",")
    if requested_format not in formats:
        raise MusicError(f"Requested {requested_format}, received {formats}. Original retained without conversion.")
    decoded = subprocess.run(
        [tools["ffmpeg"], "-v", "error", "-xerror", "-i", str(path), "-map", "0:a:0", "-f", "null", "-"],
        capture_output=True, text=True, timeout=120, check=False,
    )
    if decoded.returncode:
        raise MusicError("Full audio decode failed: " + redact(decoded.stderr))
    return {
        "duration_seconds": duration,
        "sample_rate_hz": int(stream["sample_rate"]),
        "channels": int(stream["channels"]),
        "codec": stream["codec_name"],
        "container": requested_format,
        "full_decode": "passed",
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "bytes": path.stat().st_size,
    }


def generate(args) -> dict:
    request, receipt = make_request(args)
    cost = PRICES[args.model]
    if args.max_cost_usd < cost:
        raise MusicError(f"Estimated cost ${cost} exceeds approved limit ${args.max_cost_usd}.")
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        raise MusicError("GEMINI_API_KEY is not set. Never paste the key into chat or command arguments.")
    tools = {tool: shutil.which(tool) for tool in ("ffprobe", "ffmpeg")}
    if not all(tools.values()):
        raise MusicError("Both ffprobe and ffmpeg must be on PATH before a paid request.")
    folder = reserve_run(args.out_dir, args.name)
    receipt.update(status="request_started", approved_limit_usd=str(args.max_cost_usd))
    write_json(folder / "manifest.json", receipt)
    try:
        raw = post(request, key, args.timeout)
        # Keep the unmodified response for local recovery without another paid call.
        with (folder / "response.json").open("xb") as stream:
            stream.write(raw)
        response = json.loads(raw)
        if isinstance(response, dict):
            receipt["interaction_id"] = response.get("id")
            receipt["reported_model"] = response.get("model")
        audio, lyrics = parse_audio(response)
        target = folder / f"track.{args.format}"
        with target.open("xb") as stream:
            stream.write(audio)
        (folder / "lyrics.txt").write_text(lyrics, encoding="utf-8")
        receipt["audio"] = validate_audio(target, args.format, tools)
        receipt["status"] = "validated"
        receipt["warnings"] = []
        if receipt["audio"]["sample_rate_hz"] != 44100 or receipt["audio"]["channels"] != 2:
            receipt["warnings"].append("Output differs from the documented 44.1 kHz stereo format.")
        if args.model == "lyria-3-clip-preview" and not 29 <= receipt["audio"]["duration_seconds"] <= 31:
            receipt["warnings"].append("Clip duration differs from the documented 30 seconds.")
        write_json(folder / "manifest.json", receipt)
        return {"status": "validated", "audio": str(target), "manifest": str(folder / "manifest.json"),
                "lyrics": str(folder / "lyrics.txt"), "warnings": receipt["warnings"],
                "listening_review": "pending"}
    except Exception as exc:
        receipt.update(status="failed", error=redact(str(exc)))
        write_json(folder / "manifest.json", receipt)
        raise MusicError(f"{redact(str(exc))}\nRun retained at {folder}. No automatic retry was made.") from None


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    for name in ("plan", "generate"):
        cmd = commands.add_parser(name, help="Offline preview" if name == "plan" else "One explicitly approved paid request")
        prompt = cmd.add_mutually_exclusive_group(required=True)
        prompt.add_argument("--prompt")
        prompt.add_argument("--prompt-file", type=Path, help="UTF-8 text including any lyrics and musical direction")
        cmd.add_argument("--model", choices=PRICES, default="lyria-3.5")
        cmd.add_argument("--format", choices=("mp3", "wav"), default="mp3")
        cmd.add_argument("--name", default="music")
        cmd.add_argument("--out-dir", type=Path, default=Path("output/musicgen"))
        if name == "generate":
            cmd.add_argument("--max-cost-usd", required=True, type=price_limit,
                             help="Approved estimate for this one request; not a Google billing cap")
            cmd.add_argument("--timeout", type=int, choices=range(1, 1801), metavar="SECONDS", default=300)
    return root


def main(argv=None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == "plan":
            _, result = make_request(args)
            result["output_parent"] = str(args.out_dir.resolve())
            result["network_request"] = False
        else:
            result = generate(args)
        print(json.dumps(result, indent=2, ensure_ascii=True))
        return 0
    except (MusicError, OSError, ValueError) as exc:
        print(json.dumps({"error": redact(str(exc))}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
