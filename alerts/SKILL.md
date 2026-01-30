---
name: alerts
description: V1.0 - Alert management system for monitoring services and triggering notifications when issues are detected, organized by use case.
license: Apache-2.0
compatibility: Windows PowerShell 5.1+
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the alerts directory (path contains 'alerts'), verify that history logging occurred.
            
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
            Before stopping, if alerts skill was used (check if any files in alerts directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in alerts directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
---

# Alerts Skill

Centralized, unified alert management system for all Claude skills. Provides a single place to monitor and respond to issues, events, and items requiring attention across your entire skill ecosystem. Each skill that generates alerts contributes its own subfolder, with all alerts treated as equal priority.

## Purpose

The Alerts skill is the **unified attention system** for Claude:

- Skills surface potential issues, anomalies, and items needing review
- All alerts are coordinated through this central location
- Conductor and other activity monitoring tools can query this directory to see what needs attention across all skills
- No alert is more important than another - they all deserve visibility

## Structure

Each skill that generates alerts creates its own subfolder containing configuration and alert history:

```
~/.claude/skills/alerts/
├── hs-conductor/           # Alerts from Conductor skill (server monitoring)
│   ├── config.json
│   └── history.json
├── productivity/           # Alerts from Productivity skill (suspicious commits, etc.)
│   ├── config.json
│   └── history.json
├── {another-skill}/        # Alerts from any other skill
│   ├── config.json
│   └── history.json
└── ...
```

**Key Point**: Each subfolder name is **the skill name**, not a use case. This allows Conductor and other tools to iterate through `alerts/*/` and know exactly which skill each alert came from.

## How to Add Alerts from Your Skill

1. Create `~/.claude/skills/alerts/{skill-name}/` directory
2. Add `config.json` describing what alerts this skill generates
3. Write alerts to `history.json` in the standard format
4. That's it - your skill's alerts are now visible to the entire ecosystem

## Alert Configuration Format

Each skill has a `config.json` defining its alert conditions and channels:

```json
{
  "skillName": "hs-conductor",
  "description": "Server monitoring and health checks for HemSoft Conductor services",
  "alertTypes": [
    {
      "id": "server-down",
      "name": "Server Down",
      "level": "critical",
      "description": "Backend server on port 2900 is not responding"
    },
    {
      "id": "unusual-activity",
      "name": "Unusual Activity",
      "level": "warning",
      "description": "Unexpected process behavior or resource usage"
    }
  ],
  "alertChannels": [
    {
      "type": "file",
      "location": "~/.claude/skills/alerts/{skill-name}/history.json",
      "enabled": true
    }
  ]
}
```

## Alert History Format

Alerts are stored in `history.json` as a structured array:

```json
[
  {
    "timestamp": "2026-01-30T12:22:45Z",
    "level": "critical",
    "alertType": "server-down",
    "skillName": "hs-conductor",
    "title": "Backend Server Down",
    "description": "Backend server (port 2900) failed health check",
    "details": {
      "port": 2900,
      "failureCount": 3,
      "lastCheck": "2026-01-30T12:22:40Z"
    },
    "status": "active"
  },
  {
    "timestamp": "2026-01-30T12:25:10Z",
    "level": "info",
    "alertType": "recovered",
    "skillName": "hs-conductor",
    "title": "Backend Server Recovered",
    "description": "Backend server is responding again",
    "details": {
      "port": 2900,
      "recoveryTime": "2m 30s"
    },
    "status": "resolved"
  }
]
```

## Alert Levels

- **Critical**: Immediate action required (service down, data corruption, security issue)
- **Warning**: Issues detected but not blocking (repeated failures, threshold exceeded)
- **Info**: Informational alerts (recovery, status changes, audit events)

## For Conductor and Activity Monitors

To query all alerts across all skills:

```powershell
# Get all active alerts
Get-ChildItem ~/.claude/skills/alerts -Directory | ForEach-Object {
    $skillName = $_.Name
    $historyFile = Join-Path $_.FullName "history.json"
    if (Test-Path $historyFile) {
        Get-Content $historyFile | ConvertFrom-Json |
            Where-Object { $_.status -eq "active" } |
            Add-Member -NotePropertyName skill -NotePropertyValue $skillName -PassThru
    }
}
```

## Best Practices

- **Set meaningful alert levels** - Use Critical sparingly, reserve for true emergencies
- **Include context** - Always populate the `details` object with relevant info for investigation
- **Timestamp in ISO 8601 format** - Enables easy sorting and querying
- **Update status field** - Mark alerts as `active`, `resolved`, or `investigating`
- **Document your alert types** - Make it clear in config.json what conditions generate alerts
- **Keep history pruned** - Remove resolved/old alerts periodically to prevent growth

## Example: Adding Alerts from Productivity Skill

When the Productivity skill detects suspicious commits:

1. Create: `~/.claude/skills/alerts/productivity/config.json`
2. Alert occurs → Append to: `~/.claude/skills/alerts/productivity/history.json`

```json
{
  "timestamp": "2026-01-30T13:50:00Z",
  "level": "warning",
  "alertType": "suspicious-commit",
  "skillName": "productivity",
  "title": "Suspicious Commit Detected",
  "description": "Unknown author detected in commit",
  "details": {
    "repository": "hs-cli-confluence-search",
    "commit": "7ef3ce3",
    "author": "Unknown Author Name",
    "subject": "Show banner on all help and error output"
  },
  "status": "active"
}
```
