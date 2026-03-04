---
name: diary
description: V1.0 - Comamands: create [date]
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the diary directory (path contains 'diary'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if diary was used (check if any files in diary directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in diary directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
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

- In `📊 Daily Numbers`, always include day-over-day deltas versus yesterday for:
  - GitHub Copilot usage
  - Cloudflare usage metrics (page views, unique visitors, and emails forwarded where applicable)
- If a prior-day value is missing, explicitly state that the delta is unavailable.
