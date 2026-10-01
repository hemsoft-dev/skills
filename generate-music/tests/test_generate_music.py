"""Offline tests. No test sends a paid request."""
import argparse
import base64
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "generate_music.py"
spec = importlib.util.spec_from_file_location("generate_music", SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def response(data=b"audio", status="completed"):
    return {"status": status, "id": "test-id", "model": "lyria-3-clip-preview", "steps": [
        {"type": "model_output", "content": [
            {"type": "text", "text": "Test lyrics"},
            {"type": "audio", "data": base64.b64encode(data).decode()},
        ]}
    ]}


class MusicTests(unittest.TestCase):
    def args(self, *extra):
        return m.parser().parse_args(["generate", "--prompt", "Instrumental piano", "--max-cost-usd", ".08", *extra])

    def test_plan_does_not_use_network_or_require_credentials(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(m, "post") as post, patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(m.main(["plan", "--prompt", "Piano"]), 0)
            self.assertFalse(json.loads(output.getvalue())["network_request"])
            post.assert_not_called()

    def test_full_model_is_default(self):
        request, receipt = m.make_request(self.args())
        self.assertEqual(request, {"model": "lyria-3.5", "input": "Instrumental piano"})
        self.assertEqual(receipt["pricing"]["estimated_usd"], "0.08")
        self.assertIsNone(receipt["reported_model"])

    def test_wav_payload(self):
        request, _ = m.make_request(self.args("--format", "wav"))
        self.assertEqual(request["response_format"], {"type": "audio"})

    def test_clip_rejects_wav(self):
        with self.assertRaises(m.MusicError):
            m.make_request(self.args("--model", "lyria-3-clip-preview", "--format", "wav"))

    def test_prompt_file_preserves_lyrics(self):
        with tempfile.TemporaryDirectory() as d:
            file = Path(d) / "prompt.txt"
            file.write_text("[Verse]\nBonjour\n", encoding="utf-8-sig")
            args = m.parser().parse_args(["plan", "--prompt-file", str(file)])
            self.assertEqual(m.make_request(args)[0]["input"], "[Verse]\nBonjour\n")

    def test_empty_prompt_rejected(self):
        with self.assertRaises(m.MusicError):
            m.make_request(self.args("--prompt", "  "))

    def test_unsafe_name_rejected(self):
        for name in ("../escape", "/absolute", "", "a/b", "a\\b"):
            with self.subTest(name=name), self.assertRaises(m.MusicError):
                m.make_request(self.args("--name", name))

    def test_invalid_cost_limits(self):
        for value in ("NaN", "Infinity", "-1", "invalid"):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                m.price_limit(value)

    def test_insufficient_cost_limit_never_posts(self):
        with patch.object(m, "post") as post, self.assertRaises(m.MusicError):
            m.generate(self.args("--max-cost-usd", ".04"))
        post.assert_not_called()

    def test_missing_key_never_posts(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(m, "post") as post, self.assertRaises(m.MusicError):
            m.generate(self.args())
        post.assert_not_called()

    def test_missing_tools_never_posts(self):
        with patch.dict(os.environ, {"GEMINI_API_KEY": "fake-test-key"}), patch.object(m.shutil, "which", return_value=None), patch.object(m, "post") as post, self.assertRaises(m.MusicError):
            m.generate(self.args())
        post.assert_not_called()

    def test_versioned_runs_preserve_files(self):
        with tempfile.TemporaryDirectory() as d:
            first = m.reserve_run(Path(d), "music")
            (first / "keep").write_text("original")
            second = m.reserve_run(Path(d), "music")
            self.assertEqual(second.name, "music-v002")
            self.assertEqual((first / "keep").read_text(), "original")

    def test_current_response(self):
        self.assertEqual(m.parse_audio(response()), (b"audio", "Test lyrics"))

    def test_legacy_response(self):
        blocks = response()["steps"][0]["content"]
        self.assertEqual(m.parse_audio({"outputs": blocks}), (b"audio", "Test lyrics"))

    def test_bad_responses_rejected(self):
        cases = [[], {}, {"error": {"message": "blocked"}}, response(status="failed"), response(data=b"")]
        bad = response()
        bad["steps"][0]["content"][1]["data"] = "!!!"
        cases.append(bad)
        duplicate = response()
        duplicate["steps"] *= 2
        cases.append(duplicate)
        for case in cases:
            with self.subTest(case=case), self.assertRaises(m.MusicError):
                m.parse_audio(case)

    def test_http_error_redacted_and_not_retried(self):
        key = "secret-test-key"
        error = urllib.error.HTTPError(m.ENDPOINT, 429, "Quota", {}, io.BytesIO(key.encode()))
        with patch.dict(os.environ, {"GEMINI_API_KEY": key}), patch.object(m.urllib.request, "build_opener") as builder:
            builder.return_value.open.side_effect = error
            with self.assertRaises(m.MusicError) as caught:
                m.post({}, key, 30)
            self.assertNotIn(key, str(caught.exception))
            self.assertIn("429", str(caught.exception))
            self.assertEqual(builder.return_value.open.call_count, 1)
            self.assertTrue(error.closed)

    def test_redirect_is_refused(self):
        with self.assertRaises(m.MusicError):
            m.NoRedirect().redirect_request(None, None, 302, "", {}, "https://example.org")

    def test_timeout_not_retried(self):
        with patch.object(m.urllib.request, "build_opener") as builder:
            builder.return_value.open.side_effect = TimeoutError("timed out")
            with self.assertRaisesRegex(m.MusicError, "Billing outcome may be unknown"):
                m.post({}, "fake-key", 1)
            self.assertEqual(builder.return_value.open.call_count, 1)

    def test_response_size_limit(self):
        with patch.object(m, "MAX_RESPONSE", 4), patch.object(m.urllib.request, "build_opener") as builder:
            builder.return_value.open.return_value.__enter__.return_value.read.return_value = b"12345"
            with self.assertRaises(m.MusicError):
                m.post({}, "fake-key", 1)

    def test_failed_generation_keeps_response_and_receipt(self):
        with tempfile.TemporaryDirectory() as d, patch.dict(os.environ, {"GEMINI_API_KEY": "fake-key"}), patch.object(m.shutil, "which", return_value="tool"), patch.object(m, "post", return_value=b'{"steps": []}') as post:
            with self.assertRaises(m.MusicError):
                m.generate(self.args("--out-dir", d))
            folder = Path(d) / "music-v001"
            self.assertEqual((folder / "response.json").read_bytes(), b'{"steps": []}')
            self.assertEqual(json.loads((folder / "manifest.json").read_text())["status"], "failed")
            self.assertEqual(post.call_count, 1)

    @unittest.skipUnless(shutil.which("ffprobe") and shutil.which("ffmpeg"), "FFmpeg tools missing")
    def test_real_audio_decode_and_mocked_generation(self):
        with tempfile.TemporaryDirectory() as d:
            wav = Path(d) / "synthetic.wav"
            subprocess.run([shutil.which("ffmpeg"), "-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=0.2", "-ar", "44100", "-ac", "2", str(wav)], check=True)
            tools = {name: shutil.which(name) for name in ("ffmpeg", "ffprobe")}
            details = m.validate_audio(wav, "wav", tools)
            self.assertEqual(details["channels"], 2)
            self.assertEqual(details["sample_rate_hz"], 44100)
            with self.assertRaises(m.MusicError):
                m.validate_audio(wav, "mp3", tools)
            raw = json.dumps(response(wav.read_bytes())).encode()
            with patch.dict(os.environ, {"GEMINI_API_KEY": "fake-key"}), patch.object(m, "post", return_value=raw) as post:
                result = m.generate(self.args("--out-dir", d, "--format", "wav"))
                self.assertEqual(result["status"], "validated")
                manifest = json.loads(Path(result["manifest"]).read_text())
                self.assertEqual(manifest["audio"]["sha256"], details["sha256"])
                self.assertEqual(manifest["listening_review"], "pending")
                self.assertIsNone(manifest["pricing"]["actual_billed_usd"])
                self.assertEqual(post.call_count, 1)

    @unittest.skipUnless(shutil.which("ffprobe") and shutil.which("ffmpeg"), "FFmpeg tools missing")
    def test_invalid_audio_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "bad.mp3"
            path.write_bytes(b"not music")
            with self.assertRaises(m.MusicError):
                m.validate_audio(path, "mp3", {name: shutil.which(name) for name in ("ffmpeg", "ffprobe")})


if __name__ == "__main__":
    unittest.main()
