#!/usr/bin/env python3
"""Send a concise, structured Slack direct-message update.

Dry-run is the default. Add --confirm-send after applying the skill's
authorization rules. Messages to the fixed owner ID are preauthorized.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


SLACK_API = "https://slack.com/api"
DEFAULT_USER_ID = "U2XMZDPJ7"
PROJECT_EMOJI = "📦"
CATEGORY_EMOJIS = {
    "merged": "✅",
    "completed": "🎯",
    "review": "🔍",
    "blocked": "🚧",
    "failed": "🚨",
    "deployed": "🚀",
    "tests": "🧪",
    "maintenance": "🛠️",
    "info": "ℹ️",
}


def disable_inherited_ssl_key_logging() -> None:
    """Remove browser-injected SSL key logging that can break HTTPS requests."""
    os.environ.pop("SSLKEYLOGFILE", None)


def slack_request(method: str, token: str, payload: dict | None = None) -> dict:
    disable_inherited_ssl_key_logging()
    data = None
    headers = {"Authorization": f"Bearer {token}"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"

    request = urllib.request.Request(
        f"{SLACK_API}/{method}",
        data=data,
        headers=headers,
        method="POST" if payload is not None else "GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Slack HTTP {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Slack network error: {exc.reason}") from exc

    parsed = json.loads(body)
    if not parsed.get("ok"):
        raise RuntimeError(f"Slack API error from {method}: {parsed.get('error', parsed)}")
    return parsed


def require_token() -> str:
    token = os.environ.get("SLACK_TOKEN", "")
    if not token:
        raise RuntimeError("SLACK_TOKEN is not set")
    if not token.startswith("xoxb-"):
        raise RuntimeError("SLACK_TOKEN must be a bot token beginning with xoxb-")
    return token


def lookup_user_by_email(token: str, email: str) -> str:
    encoded = urllib.parse.quote(email)
    result = slack_request(f"users.lookupByEmail?email={encoded}", token)
    return result["user"]["id"]


def open_dm(token: str, user_id: str) -> str:
    result = slack_request("conversations.open", token, {"users": user_id})
    return result["channel"]["id"]


def clean_single_line(value: str, field_name: str, maximum: int) -> str:
    cleaned = " ".join(value.split())
    if not cleaned:
        raise ValueError(f"{field_name} cannot be empty")
    if len(cleaned) > maximum:
        raise ValueError(f"{field_name} must be {maximum} characters or fewer")
    return cleaned


def clean_summary(value: str) -> str:
    lines = [" ".join(line.split()) for line in value.splitlines() if line.strip()]
    if not lines:
        raise ValueError("summary cannot be empty")
    if len(lines) > 2:
        raise ValueError("summary must contain no more than two non-empty lines")
    summary = "\n".join(lines)
    if len(summary) > 500:
        raise ValueError("summary must be 500 characters or fewer")
    return summary


def parse_detail(value: str) -> tuple[str, str]:
    if "=" not in value:
        raise ValueError('detail must use "Area=Result" format')
    area, result = value.split("=", 1)
    return (
        clean_single_line(area, "detail area", 80),
        clean_single_line(result, "detail result", 500),
    )


def validate_url(value: str | None) -> str | None:
    if not value:
        return None
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("url must be an absolute http or https URL")
    if any(character in value for character in "<>|"):
        raise ValueError("url contains a character Slack cannot safely format")
    return value


def escape_mrkdwn(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def build_fallback(
    project: str,
    task: str,
    summary: str,
    category: str,
    details: list[tuple[str, str]],
    url: str | None,
) -> str:
    lines = [
        f"{PROJECT_EMOJI} {project}",
        f"{CATEGORY_EMOJIS[category]} {task}",
        summary,
    ]
    if details:
        detail_text = "; ".join(f"{area}: {result}" for area, result in details)
        lines.append(f"Details: {detail_text}")
    if url:
        lines.append(f"Link: {url}")
    return "\n".join(lines)


def build_message(
    channel_id: str,
    project: str,
    task: str,
    summary: str,
    category: str,
    details: list[tuple[str, str]],
    url: str | None,
) -> dict:
    fallback = build_fallback(project, task, summary, category, details, url)
    outcome = f"{CATEGORY_EMOJIS[category]} *{escape_mrkdwn(task)}*"
    if url:
        outcome += f" · <{url}|Open link>"

    blocks: list[dict] = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"{PROJECT_EMOJI} {project}",
                "emoji": True,
            },
        },
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": outcome},
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": escape_mrkdwn(summary),
            },
        },
    ]

    if details:
        rows = [
            [
                {"type": "raw_text", "text": "Area"},
                {"type": "raw_text", "text": "Result"},
            ]
        ]
        rows.extend(
            [
                {"type": "raw_text", "text": area},
                {"type": "raw_text", "text": result},
            ]
            for area, result in details
        )
        blocks.extend(
            [
                {
                    "type": "section",
                    "text": {"type": "mrkdwn", "text": "📋 *Details*"},
                },
                {
                    "type": "table",
                    "column_settings": [
                        {"is_wrapped": True},
                        {"is_wrapped": True},
                    ],
                    "rows": rows,
                },
            ]
        )

    return {
        "channel": channel_id,
        "text": fallback,
        "unfurl_links": False,
        "unfurl_media": False,
        "blocks": blocks,
    }


def parse_message_arguments(args: argparse.Namespace) -> tuple:
    missing = [
        flag
        for flag, value in (
            ("--project", args.project),
            ("--task", args.task),
            ("--summary", args.summary),
        )
        if not value
    ]
    if missing:
        raise ValueError(f"required structured arguments missing: {', '.join(missing)}")

    project = clean_single_line(args.project, "project", 140)
    task = clean_single_line(args.task, "task", 180)
    summary = clean_summary(args.summary)
    details = [parse_detail(value) for value in args.detail]
    url = validate_url(args.url)
    return project, task, summary, args.category, details, url


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Send a concise, structured Slack DM update."
    )
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--user-id", default=DEFAULT_USER_ID, help="Slack user ID.")
    target.add_argument("--email", help="Slack email address to resolve and DM.")
    parser.add_argument("--project", help="Repository, product, or workstream.")
    parser.add_argument("--task", help="Short outcome, such as 'PR #83 merged'.")
    parser.add_argument("--summary", help="One- or two-line concise summary.")
    parser.add_argument(
        "--category",
        choices=tuple(CATEGORY_EMOJIS),
        default="info",
        help="Outcome category used to select the standard emoji.",
    )
    parser.add_argument(
        "--detail",
        action="append",
        default=[],
        metavar="AREA=RESULT",
        help="Optional table row. Repeat for multi-part work.",
    )
    parser.add_argument("--url", help="Optional primary link.")
    parser.add_argument(
        "--confirm-send",
        action="store_true",
        help="Actually send after applying the skill's authorization rules.",
    )
    parser.add_argument("--auth-test", action="store_true", help="Validate token identity.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.auth_test:
        token = require_token()
        result = slack_request("auth.test", token)
        print(
            json.dumps(
                {
                    "ok": True,
                    "team": result.get("team"),
                    "user": result.get("user"),
                    "user_id": result.get("user_id"),
                },
                indent=2,
            )
        )
        return 0

    try:
        message_values = parse_message_arguments(args)
    except ValueError as exc:
        parser.error(str(exc))

    if args.email:
        if args.confirm_send:
            token = require_token()
            user_id = lookup_user_by_email(token, args.email)
        else:
            user_id = f"<resolved from {args.email} when sending>"
    else:
        user_id = args.user_id

    if not args.confirm_send:
        payload = build_message("<DM channel resolved when sending>", *message_values)
        print("DRY RUN: no Slack API write was performed.")
        print(json.dumps({"recipient": user_id, "payload": payload}, indent=2))
        return 0

    token = require_token()
    channel_id = open_dm(token, user_id)
    payload = build_message(channel_id, *message_values)
    result = slack_request("chat.postMessage", token, payload)
    print(
        json.dumps(
            {"ok": True, "channel": result.get("channel"), "ts": result.get("ts")},
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
