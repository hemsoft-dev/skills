---
name: logs
description: V1.0 - Centralized log management system for storing, organizing, and querying structured logs organized by use case and date with 7-day retention.
license: Apache-2.0
compatibility: Windows PowerShell, requires write access to ~/.claude/skills/logs/
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the logs directory (path contains 'logs'), verify that history logging occurred.
            
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
            Before stopping, if logs skill was used (check if any files in logs directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in logs directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
---

# Logs Skill

Manages structured, timestamped logs for monitoring services and scripts. Each use case (like hs-conductor server monitoring) gets its own folder with JSON log files organized by date.

## Structure

```
~/.claude/skills/logs/
├── hs-conductor/           # Use case folder
│   ├── 2026-01-30.json    # Daily log file
│   └── 2026-01-29.json
└── {other-use-cases}/
```

## Log Entry Format

Each log file contains a JSON array of timestamped entries:

```json
[
  {
    "timestamp": "2026-01-30T12:22:45Z",
    "level": "info|warn|error",
    "event": "process_started",
    "details": "Backend server started with PID 1234",
    "exitCode": null
  },
  {
    "timestamp": "2026-01-30T13:45:22Z",
    "level": "error",
    "event": "process_crashed",
    "details": "Inngest dev server exited unexpectedly",
    "exitCode": 1
  }
]
```

## Common Log Events

- `process_started` - Process launched successfully
- `process_running` - Periodic health check confirmation
- `process_crashed` - Process exited with non-zero code
- `process_restarted` - Automatic restart triggered
- `cleanup_started` - Cleanup/shutdown initiated

## Log Levels

- `info` - Normal operations
- `warn` - Warnings that don't prevent operation
- `error` - Errors requiring attention

## Usage

When logging from a script (like a Windows Service), append entries to `~/.claude/skills/logs/{use-case}/{YYYY-MM-DD}.json`

When querying logs, read the JSON files and parse the entries.

## Retention

Logs older than 7 days should be automatically cleaned up. A cleanup function runs daily and removes any log files with dates more than 7 days old.
