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

Centralized alert management for monitoring critical services and infrastructure. Each use case defines what to monitor, thresholds for alerts, and actions to take.

## Structure

```
~/.claude/skills/alerts/
├── hs-conductor/
│   └── config.json
└── {other-use-cases}/
    └── config.json
```

## Alert Configuration Format

Each use case has a `config.json` defining:

```json
{
  "name": "hs-conductor-server-monitor",
  "description": "Monitors HemSoft Conductor backend services",
  "monitors": [
    {
      "id": "backend-server",
      "name": "Backend Server",
      "port": 2900,
      "checkInterval": 60000,
      "failureThreshold": 3,
      "description": "Monitors backend server on port 2900"
    },
    {
      "id": "inngest-server",
      "name": "Inngest Dev Server",
      "port": 2901,
      "checkInterval": 60000,
      "failureThreshold": 3,
      "description": "Monitors Inngest on port 2901"
    }
  ],
  "alertChannels": [
    {
      "type": "log",
      "location": "~/.claude/skills/logs/hs-conductor/",
      "enabled": true
    },
    {
      "type": "file",
      "location": "~/.claude/skills/alerts/hs-conductor/alert-history.json",
      "enabled": true
    }
  ],
  "actions": {
    "onAlert": "restart_process",
    "onRecovery": "log_recovery"
  }
}
```

## Alert Levels

- **Critical**: Service down, immediate action required
- **Warning**: Repeated failures, potential issue
- **Info**: Service recovered, informational alert

## Supported Alert Channels

1. **log** - Write to logs skill
2. **file** - Write to JSON alert history file
3. **console** - Write to console (for development)
4. **event-log** - Write to Windows Event Log

## Use Cases

### hs-conductor-server-monitor

**What to Monitor**:
- Backend Server (port 2900)
- Inngest Dev Server (port 2901)

**Alert Conditions**:
- Port not responding for 3 consecutive checks
- Process exits with non-zero status code
- Memory usage exceeds threshold (if applicable)
- Port already in use (conflict detection)

**Actions**:
- Log the alert with full context
- Attempt process restart (handled by windows-service)
- Record alert history for trend analysis
- Escalate after N repeated failures

**Recovery Action**:
- Log when service recovers
- Clear failure counter

## Best Practices

- Set `failureThreshold >= 2` to avoid false positives
- `checkInterval >= 30000` (30 seconds) for stability
- Always include descriptive names and descriptions
- Test alert channels before deployment
