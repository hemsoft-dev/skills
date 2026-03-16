---
name: diary
description: V1.1 - Commands: create [date], update [date]. Personal diary management with scaffolded entries where Today's Highlight is always the main news headline of the day.
---

# Diary

> **Reference (dev only):** `D:\Backup\.agents\skills\diary` — Legacy diary skill for inspiration during development. Remove this reference once migration is complete.

Personal diary management.

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `create` | `/diary create` or `/diary create 2026-03-01` | Create a new diary entry. Defaults to today. Aborts if entry already exists (use `update` instead). |
| `update` | `/diary update` or `/diary update 2026-03-01` | Update an existing diary entry. *(coming soon)* |

## Scripts

| File | Role |
|------|------|
| `create.ps1` | Entry point — validates no entry exists, then calls orchestrator |
| `diary-orchestrator.ps1` | Runs all `###-*.ps1` section scripts in order |
| `010-diary-header.ps1` | Scaffolds entry file from `config/yyyy-mm-dd.md` template |
| `020-slack-activity.ps1` | Curates Slack briefing into 5-8 bullet summary via Copilot CLI, falls back to raw briefing |

## Scaffolding Defaults

- `🎯 Today's Highlight` is not a work summary, task summary, or personal accomplishment.
- It must always be the main news headline of the day, chosen from the same day's `📰 News Headlines` section.
- If the entry is saved with a placeholder, the placeholder should still tell the user to provide a news headline plus source URL, not a work-related update.
- In `📊 Daily Numbers`, always include day-over-day deltas versus yesterday for:
  - GitHub Copilot usage
  - Cloudflare usage metrics (page views, unique visitors, and emails forwarded where applicable)
- If a prior-day value is missing, explicitly state that the delta is unavailable.
