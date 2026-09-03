---
name: minibot
description: Recover, explain, inspect, or change Franz's three-profile Minibot team hosted by Hermes on mini. Use when Franz mentions Minibot, Chief of Staff, Janitor, Developer, the Minibot heartbeat, or the bot-team architecture. Do not use for unrelated Hermes questions.
---

# Minibot

Minibot is Franz's Hermes bot team on `mini`.

## Restore context

Use `/home/franz/minibot` as the authoritative repository on `mini`. If live state shows that it moved, use the live path. If the repository is unavailable, say so instead of reconstructing the design from memory.

Read these files before explaining or changing Minibot:

- `README.md`
- `CONTEXT.md`
- `docs/architecture.md`
- `docs/operating-model.md`
- the relevant file under `bots/`

## Active design

- `default` is Chief of Staff and the only profile that communicates with Franz.
- `janitor` is Janitor and is idle.
- `developer` is Developer and is idle.
- Minibot handles interactive Slack intake. Chief of Staff uses the installed `slack-dm` skill and Slack Skill Bot for structured outbound updates to Franz.
- Hermes Kanban is retired and its old cards are not work.
- The only Minibot schedule is a local no-op Chief of Staff heartbeat every 15 minutes.
- Franz can assign work through Slack or use a CLI session on `mini` to request configuration or schedule changes.

Inspect live Hermes state before reporting what is deployed. Do not restore old responsibilities, schedules, board processing, monitoring, repository work, or fleet access without Franz's explicit direction. Define a role in the repository before changing its profile.

Slack update permission is communication authority, not work authority. Do not send heartbeat messages, internal narration, routine acknowledgements, or duplicate results. Janitor and Developer do not contact Franz directly.

Preserve Hermes runtime data and credentials outside Git. Profiles share Franz's operating-system account and are not security boundaries.
