---
name: alerts
description: V1.0 - Centralized alert registry for active and dismissed alerts across all skills. Manages alert state; does not trigger or monitor.
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

The Alerts skill is a **centralized registry** for alert state management:

- Other skills identify issues and hand them to alerts skill for registration
- Alerts skill stores them in active or dismissed folders
- Conductor or other monitoring tools watch alerts/active/ and handle notifications (that's their job)
- All alerts are equal priority; the registry just tracks state

## Structure

All alerts are centrally organized by status with daily JSON files, while skill configurations remain organized by skill:

```
~/.claude/skills/alerts/
├── active/                          # Currently active alerts requiring attention
│   ├── 2026-01-30.json             # All active alerts from all skills today
│   ├── 2026-01-29.json             # Yesterday's active alerts
│   └── ...
├── dismissed/                       # Dismissed alerts (audit trail)
│   ├── 2026-01-30.json             # All dismissed alerts from all skills today
│   ├── 2026-01-29.json             # Yesterday's dismissed alerts
│   └── ...
├── productivity/                    # Skill configuration
│   └── config.json                 # Define alert types this skill generates
├── hs-conductor/                    # Skill configuration
│   └── config.json                 # Define alert types this skill generates
├── {another-skill}/                 # Skill configuration
│   └── config.json
└── SKILL.md
```

**Key Design**:

- `active/` and `dismissed/` at root for unified visibility
- Daily files (YYYY-MM-DD.json) prevent unbounded JSON growth
- Skill folders contain only configuration
- Each file is an array that can contain alerts from multiple skills
- Easily query: check if `active/{today}.json` is empty to see if anything needs attention

## How to Add Alerts from Your Skill

1. Create `~/.claude/skills/alerts/{skill-name}/` directory
2. Add `config.json` describing what alerts this skill generates
3. When an alert occurs, append it to the appropriate file:
   - `~/.claude/skills/alerts/active/YYYY-MM-DD.json` for new active alerts
   - `~/.claude/skills/alerts/dismissed/YYYY-MM-DD.json` when dismissing
4. Use the date-based approach to keep files manageable

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
      "location": "~/.claude/skills/alerts/active/YYYY-MM-DD.json",
      "enabled": true,
      "description": "Append active alerts here"
    }
  ]
}
```

## Alert History Format

Alerts are stored in date-stamped JSON files (YYYY-MM-DD.json) in either `active/` or `dismissed/` folders as arrays:

**Active Alert (in active/2026-01-30.json):**

```json
[
  {
    "timestamp": "2026-01-30T12:22:45Z",
    "status": "active",
    "level": "critical",
    "alertType": "server-down",
    "skillName": "hs-conductor",
    "title": "Backend Server Down",
    "description": "Backend server (port 2900) failed health check",
    "details": {
      "port": 2900,
      "failureCount": 3,
      "lastCheck": "2026-01-30T12:22:40Z"
    }
  }
]
```

**Dismissed Alert (in dismissed/2026-01-30.json):**

```json
[
  {
    "timestamp": "2026-01-30T14:19:44Z",
    "status": "dismissed",
    "dismissedAt": "2026-01-30T14:45:00Z",
    "dismissalReason": "legitimate-author",
    "dismissalNotes": "George DeCherney is a coworker at Relias",
    "level": "warning",
    "alertType": "suspicious-commit",
    "skillName": "productivity",
    "title": "Suspicious Commit Detected",
    "description": "Unknown author detected in commit",
    "details": {
      "author": "George DeCherney",
      "repository": "ai-skills",
      "commit": "41af642"
    }
  }
]
```

**Storage**:

- `active/YYYY-MM-DD.json` - Array of currently active alerts (today's date)
- `dismissed/YYYY-MM-DD.json` - Array of dismissed alerts (today's date)
- New file created each day automatically
- Each object in array includes `skillName` to identify which skill raised it
- Archive old files after retention period (recommend 30-90 days)

## Alert Levels

- **Critical**: Immediate action required (service down, data corruption, security issue)
- **Warning**: Issues detected but not blocking (repeated failures, threshold exceeded)
- **Info**: Informational alerts (recovery, status changes, audit events)

## Dismissing Alerts

When an alert has been reviewed and determined to not require action, dismiss it:

**Steps:**

1. **Review the alert** - Understand why it was triggered in `active/YYYY-MM-DD.json`

2. **Add dismissal metadata and move** - Use PowerShell to move alert from active to dismissed:

   ```powershell
   $date = (Get-Date -Format "yyyy-MM-dd")
   $alert = (Get-Content "~/.claude/skills/alerts/active/$date.json" | ConvertFrom-Json)[0]
   
   # Add dismissal info
   $alert | Add-Member -NotePropertyName dismissedAt -NotePropertyValue (Get-Date -Format "o") -Force
   $alert | Add-Member -NotePropertyName dismissalReason -NotePropertyValue "{reason}" -Force
   $alert | Add-Member -NotePropertyName dismissalNotes -NotePropertyValue "{optional notes}" -Force
   $alert.status = "dismissed"
   
   # Append to dismissed, remove from active
   $alert | ConvertTo-Json | Out-File "~/.claude/skills/alerts/dismissed/$date.json" -Encoding UTF8 -Append
   '[]' | Out-File "~/.claude/skills/alerts/active/$date.json" -Encoding UTF8
   ```

**Dismissal Reasons (suggested categories):**

- `legitimate-author` - Unknown author is a valid contributor (update KnownAuthors list if needed)
- `false-positive` - Alert triggered but no action needed
- `false-alarm` - Condition resolved itself or was transient
- `acknowledged` - Known issue, tracked separately
- `duplicate` - Same issue already tracked elsewhere
- `wontfix` - Decided not to address this condition

**Benefits:**

- `active/{today}.json` always contains only what needs attention
- `dismissed/{date}.json` provides time-stamped audit trail
- Easy to query: if `active/{today}.json` is empty/`[]`, all clear
- Archive old files to manage storage

## For Conductor and Activity Monitors

To query all **active** alerts today across all skills:

```powershell
# Quick check: are there any active alerts today?
$today = (Get-Date -Format "yyyy-MM-dd")
$activeFile = "~/.claude/skills/alerts/active/$today.json"

if ((Test-Path $activeFile) -and ((Get-Content $activeFile) -ne '[]')) {
    Get-Content $activeFile | ConvertFrom-Json | ForEach-Object {
        Write-Host "🚨 $($_.skillName): $($_.title) (Level: $($_.level))"
    }
} else {
    Write-Host "✓ No active alerts today"
}
```

To query **dismissed** alerts for audit trail:

```powershell
# Review what was dismissed in the last 7 days
$dismissedDir = "~/.claude/skills/alerts/dismissed"
Get-ChildItem $dismissedDir -Filter "*.json" -File | 
    Sort-Object Name -Descending | 
    Select-Object -First 7 |
    ForEach-Object {
        Get-Content $_.FullName | ConvertFrom-Json |
            Add-Member -NotePropertyName date -NotePropertyValue $_.BaseName -PassThru
    }
```

**Key advantage**: `active/{today}.json` is either empty (`[]`) or contains only what needs attention - no parsing needed!

## Best Practices

- **Set meaningful alert levels** - Use Critical sparingly, reserve for true emergencies
- **Include context** - Always populate the `details` object with relevant info for investigation
- **Timestamp in ISO 8601 format** - Enables easy sorting and querying
- **Use folder location for state** - Active alerts in `active/`, dismissed in `dismissed/` folders
- **Document your alert types** - Make it clear in config.json what conditions generate alerts
- **Keep history pruned** - Remove resolved/old alerts periodically to prevent growth

## Example: Adding Alerts from Productivity Skill

When the Productivity skill detects suspicious commits:

1. Create: `~/.claude/skills/alerts/productivity/config.json` (defines alert types)
2. Alert occurs → Productivity constructs alert object and appends to: `~/.claude/skills/alerts/active/YYYY-MM-DD.json`

```json
[
  {
    "timestamp": "2026-01-30T13:50:00Z",
    "status": "active",
    "level": "warning",
    "alertType": "suspicious-commit",
    "skillName": "productivity",
    "title": "Suspicious Commit Detected",
    "description": "Unknown author detected in commit",
    "details": {
      "repository": "ai-skills",
      "commit": "41af642",
      "author": "George DeCherney",
      "subject": "Add skill for comparing resume to linkedin profile..."
    }
  }
]
```

**Note:** The alerts skill is NOT responsible for:

- Deciding whether to send notifications
- Taking action on the alert
- Monitoring for changes
- Figuring out if it's a real problem

It just registers what the other skill tells it.
