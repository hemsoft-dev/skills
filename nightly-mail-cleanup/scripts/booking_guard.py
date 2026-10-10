"""Pure, conservative booking holds for mail cleanup. No mailbox actions."""
from __future__ import annotations

import argparse
from datetime import date, datetime, timedelta, timezone
import json
import re
from types import SimpleNamespace
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

BOOKING_WORDS = re.compile(
    r"\byour reservation\b|\breservation (?:for|confirmed|confirmation|details|updated|changed|cancelled|canceled)\b|"
    r"\byour booking\b|\bbooking (?:confirmation|reference|number|code)\b|"
    r"\byour itinerary\b|\bitinerary for\b|\bcheck[ -]?in\b|\bcheck[ -]?out\b|\bcheckout\b|"
    r"\byour (?:trip|stay|flight|rental)\b", re.I)
TRAVEL_DOMAINS = ("airbnb.com", "vrbo.com", "enterprise.com")
CANCELLED = re.compile(
    r"\b(?:reservation|booking|trip|stay|rental)\s+(?:(?:has been|was|is)\s+)?cancel(?:led|ed)\b|"
    r"\b(?:cancellation (?:confirmed|confirmation)|confirmed cancellation)\b", re.I)
RESCHEDULED = re.compile(r"\brescheduled\b|\b(?:reservation|booking|trip) (?:updated|changed)\b|\bnew (?:trip|stay|travel) dates\b", re.I)
REFERENCE = re.compile(r"\b(?:confirmation|reservation|booking)\s+(?:code|number|reference|id)\s*[:#]?\s*([A-Z0-9][A-Z0-9-]{4,24})\b", re.I)
MONTHS = {name.lower(): n for n, name in enumerate(
    ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], 1)}
MONTH_PATTERN = "(?:" + "|".join(MONTHS) + "|" + "|".join(m[:3] for m in MONTHS) + ")"


def text_of(message):
    return str(getattr(message, "subject", "")) + "\n" + str(getattr(message, "body", ""))


def current_text(message):
    lines = []
    for line in str(getattr(message, "body", "")).splitlines():
        if re.match(r"^On .+wrote:\s*$", line.strip(), re.I): break
        if not line.lstrip().startswith(">"):
            lines.append(line)
    return str(getattr(message, "subject", "")) + "\n" + "\n".join(lines)


def needs_booking_body(address, subject):
    domain = address.rsplit("@", 1)[-1].lower()
    return bool(BOOKING_WORDS.search(subject) or any(domain == d or domain.endswith("." + d) for d in TRAVEL_DOMAINS))


def booking_dates(text):
    """Accept only explicit-year date pairs/ranges. Ambiguity retains mail."""
    dates = set()
    for year, month, day in re.findall(r"\b(20\d{2})-(\d{2})-(\d{2})\b", text):
        try: dates.add(date(int(year), int(month), int(day)))
        except ValueError: return None
    for month, day, year in re.findall(r"\b(" + MONTH_PATTERN + r")\s+(\d{1,2})(?:st|nd|rd|th)?\s*,?\s*(20\d{2})\b", text, re.I):
        try: dates.add(date(int(year), next(v for k, v in MONTHS.items() if k.startswith(month.lower())), int(day)))
        except (ValueError, StopIteration): return None
    for month, start, end, year in re.findall(r"\b(" + MONTH_PATTERN + r")\s+(\d{1,2})\s*[–—-]\s*(\d{1,2})\s*,?\s*(20\d{2})\b", text, re.I):
        try:
            n = next(v for k, v in MONTHS.items() if k.startswith(month.lower()))
            dates.update([date(int(year), n, int(start)), date(int(year), n, int(end))])
        except (ValueError, StopIteration): return None
    for month, day, year in re.findall(r"\b(\d{1,2})/(\d{1,2})/(20\d{2})\b", text):
        try: dates.add(date(int(year), int(month), int(day)))
        except ValueError: return None
    return tuple(sorted(dates)) if len(dates) == 2 else None


def provider(address):
    domain = address.rsplit("@", 1)[-1].casefold()
    return next((d for d in TRAVEL_DOMAINS if domain == d or domain.endswith("." + d)), domain)


def booking_holds(messages, now):
    """Map (folder, uid) to a hold reason; latest clear linked updates win."""
    candidates = [m for m in messages if BOOKING_WORDS.search(text_of(m)) or
                  (not getattr(m, "body_complete", True) and needs_booking_body(
                      str(getattr(m, "sender_address", "")), str(getattr(m, "subject", ""))))]
    parents = list(range(len(candidates)))
    def find(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]; i = parents[i]
        return i
    seen = {}
    for i, m in enumerate(candidates):
        domain = provider(str(getattr(m, "sender_address", "")))
        keys = []
        for reference in REFERENCE.finditer(text_of(m)):
            keys.append((domain, "booking", reference.group(1).casefold()))
        for value in [getattr(m, "message_id", ""), *getattr(m, "references", ())]:
            if value: keys.append((domain, "thread", value))
        for key in keys:
            if key in seen: parents[find(i)] = find(seen[key])
            else: seen[key] = i
    groups = {}
    for i, m in enumerate(candidates): groups.setdefault(find(i), []).append(m)
    holds = {}
    for group in groups.values():
        ordered = sorted(group, key=lambda m: m.received)
        latest = ordered[-1]
        subject = str(getattr(latest, "subject", ""))
        content = current_text(latest)
        reason = None
        incomplete = not getattr(latest, "body_complete", True)
        peers = [m for m in group if m.received == latest.received]
        signatures = {(getattr(m, "body_complete", True), bool(CANCELLED.search(current_text(m))),
                       booking_dates(current_text(m))) for m in peers}
        if incomplete:
            reason = "booking content incomplete; keep for review"
        elif len(signatures) > 1:
            reason = "conflicting simultaneous booking updates; keep for review"
        elif CANCELLED.search(subject):
            # A current explicit cancellation, connected by reference/thread,
            # can retire earlier confirmations. A request or policy cannot.
            if any(m.received == latest.received and not CANCELLED.search(str(getattr(m, "subject", ""))) for m in group):
                reason = "conflicting booking status; keep for review"
        elif CANCELLED.search(content):
            if RESCHEDULED.search(subject) or re.search(r"\b(?:your reservation|your booking|your trip) (?:is|has been) confirmed\b", content, re.I):
                reason = "conflicting booking status; keep for review"
        else:
            dates = booking_dates(content)
            if dates is None and not RESCHEDULED.search(content):
                prior = [booking_dates(current_text(m)) for m in ordered[:-1] if getattr(m, "body_complete", True)]
                dates = next((d for d in reversed(prior) if d is not None), None)
            if dates is None:
                reason = "booking dates uncertain; keep for review"
            else:
                end = dates[-1]
                # Known Eastern destination/timezone; otherwise wait until
                # the end date has passed everywhere, avoiding early release.
                eastern = bool(re.search(r"Amelia Island|(?:destination|property|local) time\s*zone\s*[:=]\s*America/New_York", content, re.I))
                try:
                    active = now.astimezone(ZoneInfo("America/New_York")).date() <= end if eastern else now.astimezone(timezone.utc).date() <= end + timedelta(days=1)
                except ZoneInfoNotFoundError:
                    active = now.astimezone(timezone.utc).date() <= end + timedelta(days=1)
                if active: reason = "active booking through " + end.isoformat()
        if reason:
            for m in group: holds[(m.folder, m.uid)] = reason
    return holds


def main():
    parser = argparse.ArgumentParser(description="Read-only booking-protection preview from supplied JSON; never accesses mail")
    parser.add_argument("--preview", action="store_true", required=True)
    parser.add_argument("--now", required=True)
    args = parser.parse_args()
    import sys
    rows = json.load(sys.stdin)
    messages = [SimpleNamespace(folder=r.get("folder", "INBOX"), uid=str(r["id"]),
        received=datetime.fromisoformat(r["received"]), sender_address=r["sender_address"],
        subject=r["subject"], body=r.get("body", ""), body_complete=r.get("body_complete", True),
        message_id=r.get("message_id", ""), references=r.get("references", [])) for r in rows]
    holds = booking_holds(messages, datetime.fromisoformat(args.now))
    print(json.dumps([{"id":m.uid, "protected":(m.folder,m.uid) in holds,
                       "reason":holds.get((m.folder,m.uid))} for m in messages]))


if __name__ == "__main__": main()
