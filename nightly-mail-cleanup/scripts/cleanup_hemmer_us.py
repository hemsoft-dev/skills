#!/usr/bin/env python3
"""Apply the approved nightly cleanup rules to franz@hemmer.us over IMAP."""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from email import message_from_bytes
from email.header import decode_header
from email.utils import parseaddr, parsedate_to_datetime
import imaplib
import json
import os
import re
import ssl
from html import unescape
from html.parser import HTMLParser

import booking_guard


HOST = "imap.domain.com"
ACCOUNT = "franz@hemmer.us"
TRASH = "INBOX.Trash"
ARCHIVE = "INBOX.Archive"
EXCLUDED_FLAGS = {"\\trash", "\\junk", "\\sent", "\\drafts"}
EXCLUDED_NAME_PARTS = ("trash", "spam", "junk", "sent", "draft", "deleted")


@dataclass(frozen=True)
class Message:
    folder: str
    uid: str
    received: datetime
    sender_address: str
    sender_name: str
    subject: str
    message_id: str
    body: str = ""
    body_complete: bool = True
    references: tuple[str, ...] = ()


def decoded(value: str | None) -> str:
    if not value:
        return ""
    pieces: list[str] = []
    for part, encoding in decode_header(value):
        if isinstance(part, bytes):
            pieces.append(part.decode(encoding or "utf-8", "replace"))
        else:
            pieces.append(part)
    return "".join(pieces)


def domain_is(address: str, domain: str, include_subdomains: bool = False) -> bool:
    actual = address.rsplit("@", 1)[-1].lower() if "@" in address else ""
    expected = domain.lower()
    return actual == expected or (include_subdomains and actual.endswith("." + expected))


def older(message: Message, cutoff: datetime) -> bool:
    return message.received < cutoff


def classify_rule(message: Message, cutoff3: datetime, cutoff7: datetime) -> tuple[str, str] | None:
    address = message.sender_address
    name = message.sender_name.lower()
    subject = message.subject.lower()

    trash_rules = (
        ("Costco", lambda: "costco" in address),
        ("Kilo Team", lambda: older(message, cutoff3) and domain_is(address, "kilocode.ai", True)),
        (
            "Consumer Reports",
            lambda: older(message, cutoff3) and domain_is(address, "email.consumerreports.org"),
        ),
        (
            "Discord",
            lambda: older(message, cutoff7)
            and (domain_is(address, "discord.com") or domain_is(address, "discordapp.com")),
        ),
        ("Vrbo", lambda: older(message, cutoff7) and domain_is(address, "vrbo.com", True)),
        (
            "Microsoft Developer",
            lambda: older(message, cutoff7)
            and address == "replyto@email.microsoft.com"
            and "microsoft developer" in name,
        ),
        ("Venmo", lambda: older(message, cutoff7) and domain_is(address, "venmo.com", True)),
        ("Coinbase", lambda: older(message, cutoff7) and domain_is(address, "coinbase.com", True)),
        (
            "Udemy",
            lambda: older(message, cutoff7)
            and (domain_is(address, "students.udemy.com") or domain_is(address, "e.udemymail.com")),
        ),
        (
            "No Reply DMARC Support",
            lambda: older(message, cutoff7) and address == "noreply-dmarc-support@google.com",
        ),
        (
            "Google Security Alerts",
            lambda: older(message, cutoff7)
            and address == "no-reply@accounts.google.com"
            and "security alert" in subject,
        ),
        (
            "DMARC Aggregate Report",
            lambda: older(message, cutoff7) and address == "dmarcreport@microsoft.com",
        ),
        (
            "NC Quick Pass",
            lambda: older(message, cutoff7)
            and address
            in {
                "no-reply-ncquickpass@ncdot.gov",
                "ncquickpass@ncdot.gov",
                "no-reply@ncquickpass.ccsend.com",
                "ncquickpass-ncdot.gov@shared1.ccsend.com",
            },
        ),
        ("WingsCoin", lambda: older(message, cutoff7) and domain_is(address, "wingscoin.app", True)),
        ("Netflix", lambda: older(message, cutoff7) and domain_is(address, "netflix.com", True)),
        ("Airbnb", lambda: older(message, cutoff7) and domain_is(address, "airbnb.com", True)),
        (
            "Apple Pay",
            lambda: older(message, cutoff7)
            and (
                address == "applepay@insideapple.apple.com"
                or (
                    address == "no-reply@email.apple.com"
                    and "apple payments services" in name
                    and "apple pay" in subject
                )
            ),
        ),
        (
            "Enterprise Rent-A-Car",
            lambda: older(message, cutoff7) and domain_is(address, "enterprise.com", True),
        ),
        (
            "Under Armour",
            lambda: older(message, cutoff7) and address == "underarmour@emails.underarmour.com",
        ),
        ("Polymarket", lambda: older(message, cutoff7) and address == "noreply@polymarket.com"),
        (
            "Telekom promotions",
            lambda: older(message, cutoff7) and address == "telekom@email-telekom.de",
        ),
        (
            "SpaceXAI",
            lambda: older(message, cutoff7)
            and address == "noreply@x.ai"
            and name.strip() in {"spacexai", "xai"},
        ),
        ("Luminar", lambda: older(message, cutoff7) and address == "team@mail.skylum.com"),
        ("HeyGen", lambda: older(message, cutoff7) and domain_is(address, "heygen.com", True)),
        (
            "Cursor Team",
            lambda: older(message, cutoff7)
            and address == "team@mail.cursor.com"
            and "cursor team" in name,
        ),
        ("LinkedIn", lambda: older(message, cutoff7) and domain_is(address, "linkedin.com", True)),
        (
            "Rabbit Inc.",
            lambda: older(message, cutoff7)
            and address == "hello@rabbit.tech"
            and "rabbit inc." in name,
        ),
        ("Claude Team", lambda: older(message, cutoff7) and address == "no-reply@email.claude.com"),
        ("Ollama", lambda: older(message, cutoff7) and address == "hello@ollama.com"),
        ("Pocket Casts", lambda: older(message, cutoff7) and domain_is(address, "pocketcasts.com", True)),
        (
            "Republic investment newsletters",
            lambda: older(message, cutoff7) and domain_is(address, "team.republic.co"),
        ),
        ("Chess.com", lambda: older(message, cutoff7) and address == "hello@chess.com"),
        ("OpenRouter Team", lambda: older(message, cutoff7) and address == "welcome@openrouter.ai"),
        (
            "dbdiagram",
            lambda: older(message, cutoff7)
            and address == "david.bui@holistics.io"
            and "dbdiagram" in name,
        ),
        (
            "Descript marketing",
            lambda: older(message, cutoff7) and domain_is(address, "marketing.descript.com"),
        ),
        (
            "Novant Health promotions",
            lambda: older(message, cutoff7) and address == "reply@email-novanthealth.org",
        ),
        ("Soundstripe Team", lambda: older(message, cutoff7) and address == "team@soundstripe.com"),
        ("Kimi API", lambda: older(message, cutoff7) and address == "team@moonshot.ai"),
        (
            "Labcorp marketing",
            lambda: older(message, cutoff7) and address == "labcorp@labcorpmessage.com",
        ),
        ("USAA Advice", lambda: older(message, cutoff7) and address == "usaaadvice@mem.usaa.com"),
        ("Aura Frames", lambda: older(message, cutoff7) and address == "hello@auraframes.com"),
        ("Danes Worldwide", lambda: older(message, cutoff7) and address == "danes@news.danes.dk"),
        (
            "USAA Documents",
            lambda: older(message, cutoff7)
            and address == "usaa.customer.service@mailcenter.usaa.com"
            and "you have a new usaa document" in subject,
        ),
        (
            "Google AI Studio",
            lambda: older(message, cutoff7) and address == "googleaistudio-noreply@google.com",
        ),
        (
            "Google Store",
            lambda: older(message, cutoff7) and address == "googlestore-noreply@google.com",
        ),
        (
            "Microsoft Store",
            lambda: older(message, cutoff7)
            and address == "microsoftstore@microsoftstore.microsoft.com",
        ),
        (
            "Microsoft account team",
            lambda: older(message, cutoff7)
            and address == "account-security-noreply@accountprotection.microsoft.com"
            and "microsoft account team" in name,
        ),
        (
            "Vercel notifications",
            lambda: older(message, cutoff7) and address == "notifications@vercel.com",
        ),
        (
            "NC Lottery / NC Education Lottery",
            lambda: older(message, cutoff7) and domain_is(address, "nclottery.com", True),
        ),
        (
            "Google Calendar",
            lambda: older(message, cutoff7) and address == "calendar-notification@google.com",
        ),
        (
            "Google Home",
            lambda: older(message, cutoff7)
            and address in {"googlehome@google.com", "googlehome-noreply@google.com"},
        ),
        ("Depot", lambda: older(message, cutoff7) and domain_is(address, "mail.depot.dev")),
        (
            "Mr. Handyman marketing",
            lambda: older(message, cutoff7) and address == "mrhandyman@go.neighborly.com",
        ),
        (
            "Venice.ai marketing",
            lambda: older(message, cutoff7) and address == "mail@venice.ai",
        ),
        (
            "Friseur & Nagelpflege Mausser",
            lambda: older(message, cutoff7) and address == "friseur@friseur-mausser.at",
        ),
        (
            "Apple promotions",
            lambda: older(message, cutoff7) and address == "news@insideapple.apple.com",
        ),
        ("Nexus Mods", lambda: older(message, cutoff7) and domain_is(address, "nexusmods.com", True)),
        (
            "Google Ads",
            lambda: older(message, cutoff7)
            and address in {"ads-noreply@google.com", "ads-account-noreply@google.com"},
        ),
        (
            "Supabase newsletters",
            lambda: older(message, cutoff7)
            and address in {"welcome@supabase.com", "noreply@supabase.com"},
        ),
    )
    for rule, matches in trash_rules:
        if matches():
            return "trash", rule

    archive_rules = (
        (
            "Discord mentions in Egg, Inc.",
            lambda: address in {"noreply@discord.com", "noreply@discordapp.com"}
            and "mentioned you" in subject
            and "egg, inc." in subject,
        ),
        ("Apple News", lambda: older(message, cutoff7) and address == "newsdigest@insideapple.apple.com"),
        (
            "USPS Informed Delivery",
            lambda: older(message, cutoff7)
            and address == "uspsinformeddelivery@email.informeddelivery.usps.com",
        ),
        ("ChessBase", lambda: older(message, cutoff7) and address == "chessletter@chessbase.com"),
        ("Fidelity Investments", lambda: older(message, cutoff7) and domain_is(address, "fidelity.com", True)),
        (
            "The New Yorker",
            lambda: older(message, cutoff7) and address == "newyorker@newsletter.newyorker.com",
        ),
        ("The Atlantic", lambda: older(message, cutoff7) and domain_is(address, "theatlantic.com", True)),
        ("CODE Training", lambda: older(message, cutoff7) and address == "noreply@codemag.com"),
        ("TLDR newsletters", lambda: older(message, cutoff7) and domain_is(address, "tldrnewsletter.com")),
        ("LlamaIndex", lambda: older(message, cutoff7) and domain_is(address, "llamaindex.ai", True)),
    )
    for rule, matches in archive_rules:
        if matches():
            return "archive", rule
    return None


def classify(message: Message, cutoff3: datetime, cutoff7: datetime, booking_holds=None) -> tuple[str, str] | None:
    holds = booking_holds if booking_holds is not None else booking_guard.booking_holds(
        [message], cutoff3 + timedelta(days=3))
    if (message.folder, message.uid) in holds:
        return None
    return classify_rule(message, cutoff3, cutoff7)


class BookingText(HTMLParser):
    def __init__(self):
        super().__init__(); self.parts = []; self.ignored = 0
    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "blockquote"): self.ignored += 1
    def handle_endtag(self, tag):
        if tag in ("script", "style", "blockquote") and self.ignored: self.ignored -= 1
    def handle_data(self, data):
        if not self.ignored: self.parts.append(data)


def booking_body(client, uid):
    # Read only MIME text; never open attachments or mark a message read.
    try:
        status, data = client.uid("FETCH", uid, "(UID BODY.PEEK[])")
        if status != "OK": return "", False
        raw = next((item[1] for item in data or [] if isinstance(item, tuple)), None)
        if raw is None or len(raw) > 2_000_000: return "", False
        message = message_from_bytes(raw)
        plain, html = [], []
        for part in message.walk():
            if part.get_content_disposition() == "attachment" or part.get_filename(): continue
            kind = part.get_content_type()
            if kind not in ("text/plain", "text/html"): continue
            content = part.get_payload(decode=True)
            if content is None: continue
            text = content.decode(part.get_content_charset() or "utf-8", "replace")
            if kind == "text/plain": plain.append(text)
            else:
                parser = BookingText(); parser.feed(text); html.append("\n".join(parser.parts))
        text = "\n".join(plain or html)
        return (text, True) if text and len(text) <= 200_000 else ("", False)
    except (ValueError, LookupError, TypeError, imaplib.IMAP4.error, OSError):
        return "", False


def parse_list_entry(raw: bytes) -> tuple[set[str], str]:
    text = raw.decode("utf-8", "replace")
    match = re.match(r'^\((?P<flags>[^)]*)\)\s+"[^"]*"\s+(?P<name>.+)$', text)
    if not match:
        raise ValueError(f"Unable to parse mailbox listing: {text}")
    flags = {flag.lower() for flag in match.group("flags").split()}
    name = match.group("name")
    if name.startswith('"') and name.endswith('"'):
        name = name[1:-1].replace(r"\\", "\\").replace(r"\"", '"')
    return flags, name


def eligible(flags: set[str], folder: str) -> bool:
    lower = folder.lower()
    return not (flags & EXCLUDED_FLAGS) and not any(part in lower for part in EXCLUDED_NAME_PARTS)


def fetch_messages(
    client: imaplib.IMAP4_SSL,
    folder: str,
    criterion: str = "UNDELETED",
) -> list[Message]:
    status, _ = client.select(f'"{folder}"', readonly=True)
    if status != "OK":
        return []
    status, data = client.uid("SEARCH", None, criterion)
    if status != "OK" or not data or not data[0]:
        client.unselect()
        return []
    uids = data[0].split()
    messages: list[Message] = []
    for start in range(0, len(uids), 100):
        batch = b",".join(uids[start : start + 100])
        status, fetched = client.uid(
            "FETCH",
            batch,
            "(UID INTERNALDATE BODY.PEEK[HEADER.FIELDS (FROM SUBJECT MESSAGE-ID REFERENCES IN-REPLY-TO)])",
        )
        if status != "OK":
            raise RuntimeError(f"FETCH failed in {folder}")
        for item in fetched or []:
            if not isinstance(item, tuple):
                continue
            metadata, payload = item
            uid_match = re.search(rb"\bUID\s+(\d+)", metadata)
            date_match = re.search(rb'INTERNALDATE\s+"([^"]+)"', metadata)
            if not uid_match or not date_match:
                continue
            received = parsedate_to_datetime(date_match.group(1).decode("ascii"))
            if received.tzinfo is None:
                received = received.replace(tzinfo=timezone.utc)
            header = message_from_bytes(payload)
            display_name, address = parseaddr(decoded(header.get("From")))
            subject = decoded(header.get("Subject"))
            body, complete = "", True
            if booking_guard.needs_booking_body(address.lower(), subject):
                body, complete = booking_body(client, uid_match.group(1).decode("ascii"))
            references = tuple(re.findall(r"<[^>]+>", " ".join(
                str(header.get(name) or "") for name in ("References", "In-Reply-To"))))
            messages.append(
                Message(
                    folder=folder,
                    uid=uid_match.group(1).decode("ascii"),
                    received=received.astimezone(timezone.utc),
                    sender_address=address.lower(),
                    sender_name=decoded(display_name),
                    subject=subject,
                    message_id=(header.get("Message-ID") or "").strip(),
                    body=body, body_complete=complete, references=references,
                )
            )
    client.unselect()
    return messages


def scan(client: imaplib.IMAP4_SSL) -> tuple[list[Message], list[str]]:
    status, listed = client.list()
    if status != "OK":
        raise RuntimeError("Unable to list IMAP folders")
    folders: list[str] = []
    for raw in listed or []:
        flags, folder = parse_list_entry(raw)
        if eligible(flags, folder):
            folders.append(folder)
    messages: list[Message] = []
    for folder in folders:
        messages.extend(fetch_messages(client, folder))
    return messages, folders


def move_message(client: imaplib.IMAP4_SSL, message: Message, destination: str) -> None:
    status, _ = client.select(f'"{message.folder}"')
    if status != "OK":
        raise RuntimeError(f"Unable to open {message.folder}")
    status, _ = client.uid("COPY", message.uid, destination)
    if status != "OK":
        client.unselect()
        raise RuntimeError(f"COPY failed for {message.folder} UID {message.uid}")
    status, _ = client.uid("STORE", message.uid, "+FLAGS.SILENT", r"(\Deleted)")
    client.unselect()
    if status != "OK":
        raise RuntimeError(f"STORE failed for {message.folder} UID {message.uid}")


def destination_has_copy(
    client: imaplib.IMAP4_SSL,
    destination: str,
    message_id: str,
) -> bool:
    if not message_id:
        return False
    status, _ = client.select(f'"{destination}"', readonly=True)
    if status != "OK":
        return False
    status, data = client.uid("SEARCH", None, "HEADER", "Message-ID", message_id)
    client.unselect()
    return status == "OK" and bool(data and data[0])


def expunge_verified_sources(
    client: imaplib.IMAP4_SSL,
    folders: list[str],
    cutoff3: datetime,
    cutoff7: datetime,
    booking_context: list[Message] | None = None,
) -> tuple[dict[str, int], list[dict[str, str]]]:
    expunged: dict[str, int] = {}
    held: list[dict[str, str]] = []
    for folder in folders:
        deleted = fetch_messages(client, folder, "DELETED")
        if not deleted:
            continue
        safe = True
        holds = booking_guard.booking_holds([*(booking_context or []), *deleted], cutoff3 + timedelta(days=3))
        for message in deleted:
            result = classify(message, cutoff3, cutoff7, holds)
            if result is None:
                held.append({"folder": folder, "uid": message.uid, "reason": "not-an-approved-match"})
                safe = False
                continue
            action, _ = result
            destination = TRASH if action == "trash" else ARCHIVE
            if folder == destination:
                held.append({"folder": folder, "uid": message.uid, "reason": "already-in-destination"})
                safe = False
                continue
            if not destination_has_copy(client, destination, message.message_id):
                held.append({"folder": folder, "uid": message.uid, "reason": "destination-copy-not-verified"})
                safe = False
        if not safe:
            continue
        status, _ = client.select(f'"{folder}"')
        if status != "OK":
            held.append({"folder": folder, "uid": "*", "reason": "folder-open-failed"})
            continue
        status, _ = client.expunge()
        client.unselect()
        if status == "OK":
            expunged[folder] = len(deleted)
        else:
            held.append({"folder": folder, "uid": "*", "reason": "expunge-failed"})
    return expunged, held


def mark_remaining_read(
    client: imaplib.IMAP4_SSL,
    folders: list[str],
) -> tuple[dict[str, int], list[dict[str, str]]]:
    marked: dict[str, int] = {}
    failures: list[dict[str, str]] = []
    for folder in folders:
        status, _ = client.select(f'"{folder}"')
        if status != "OK":
            failures.append({"folder": folder, "reason": "folder-open-failed"})
            continue
        status, data = client.uid("SEARCH", None, "UNSEEN", "UNDELETED")
        if status != "OK":
            client.unselect()
            failures.append({"folder": folder, "reason": "unseen-search-failed"})
            continue
        uids = data[0].split() if data and data[0] else []
        folder_count = 0
        for start in range(0, len(uids), 500):
            batch = b",".join(uids[start : start + 500])
            status, _ = client.uid("STORE", batch, "+FLAGS.SILENT", r"(\Seen)")
            if status != "OK":
                failures.append({"folder": folder, "reason": "mark-read-failed"})
                break
            folder_count += len(uids[start : start + 500])
        client.unselect()
        if folder_count:
            marked[folder] = folder_count
    return marked, failures


def count_active_messages(
    client: imaplib.IMAP4_SSL,
    folders: list[str],
) -> tuple[int, int, list[dict[str, str]]]:
    active = 0
    unread = 0
    failures: list[dict[str, str]] = []
    for folder in folders:
        status, _ = client.select(f'"{folder}"', readonly=True)
        if status != "OK":
            failures.append({"folder": folder, "reason": "folder-open-failed"})
            continue
        status_active, active_data = client.uid("SEARCH", None, "UNDELETED")
        status_unread, unread_data = client.uid("SEARCH", None, "UNSEEN", "UNDELETED")
        client.unselect()
        if status_active != "OK" or status_unread != "OK":
            failures.append({"folder": folder, "reason": "count-search-failed"})
            continue
        active += len(active_data[0].split()) if active_data and active_data[0] else 0
        unread += len(unread_data[0].split()) if unread_data and unread_data[0] else 0
    return active, unread, failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Apply moves; otherwise perform a dry run")
    parser.add_argument(
        "--mark-remaining-read",
        action="store_true",
        help="After cleanup, mark all remaining active messages read",
    )
    args = parser.parse_args()
    password = os.environ.pop("HEMMER_US_EMAIL_PASSWORD", "")
    if not password:
        raise SystemExit("HEMMER_US_EMAIL_PASSWORD is not set")

    now = datetime.now(timezone.utc)
    cutoff3 = now - timedelta(days=3)
    cutoff7 = now - timedelta(days=7)
    client = imaplib.IMAP4_SSL(HOST, 993, ssl_context=ssl.create_default_context(), timeout=30)
    client.login(ACCOUNT, password)
    messages, folders = scan(client)
    holds = booking_guard.booking_holds(messages, now)

    matches: list[tuple[Message, str, str]] = []
    counts: Counter[tuple[str, str]] = Counter()
    already_destination: Counter[tuple[str, str]] = Counter()
    for message in messages:
        result = classify(message, cutoff3, cutoff7, holds)
        if result is None:
            continue
        action, rule = result
        destination = TRASH if action == "trash" else ARCHIVE
        if message.folder == destination:
            already_destination[(action, rule)] += 1
            continue
        matches.append((message, action, rule))
        counts[(action, rule)] += 1

    failures: list[dict[str, str]] = []
    expunged: dict[str, int] = {}
    held_deleted: list[dict[str, str]] = []
    marked_read: dict[str, int] = {}
    mark_read_failures: list[dict[str, str]] = []
    if args.apply:
        for message, action, rule in matches:
            destination = TRASH if action == "trash" else ARCHIVE
            try:
                move_message(client, message, destination)
            except Exception as exc:
                failures.append(
                    {
                        "folder": message.folder,
                        "uid": message.uid,
                        "action": action,
                        "rule": rule,
                        "error": type(exc).__name__,
                    }
                )
        expunged, held_deleted = expunge_verified_sources(
            client,
            folders,
            cutoff3,
            cutoff7,
            messages,
        )
        if args.mark_remaining_read:
            marked_read, mark_read_failures = mark_remaining_read(client, folders)

    remaining_active, remaining_unread, count_failures = count_active_messages(client, folders)
    client.logout()
    result = {
        "mode": "apply" if args.apply else "dry-run",
        "account": ACCOUNT,
        "scanned_messages": len(messages),
        "booking_protected": len(holds),
        "booking_review_required": sum("review" in reason for reason in holds.values()),
        "scanned_folders": folders,
        "cutoff_3_days_utc": cutoff3.isoformat(),
        "cutoff_7_days_utc": cutoff7.isoformat(),
        "matched": {
            f"{action}: {rule}": count for (action, rule), count in sorted(counts.items())
        },
        "already_in_destination": {
            f"{action}: {rule}": count
            for (action, rule), count in sorted(already_destination.items())
        },
        "failures": failures,
        "expunged_verified_sources": expunged,
        "held_deleted_sources": held_deleted,
        "marked_read": marked_read,
        "mark_read_failures": mark_read_failures,
        "remaining_active_messages": remaining_active,
        "remaining_active_unread": remaining_unread,
        "count_failures": count_failures,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
