---
name: tempo
description: V1.2 - Read and write Tempo time tracking data. Use when retrieving time entries, adding worklogs, checking hours logged, or managing time tracking.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the tempo directory (path contains 'tempo'), verify that history logging occurred.
            
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
            Before stopping, if tempo was used (check if any files in tempo directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in tempo directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Tempo Time Tracking

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Query Tempo time tracking data via the Tempo REST API.

## Environment Variables Required

| Variable | Purpose |
|----------|---------|
| `TEMPO_API_TOKEN` | Tempo API bearer token (system env var) |
| `ATLASSIAN_EMAIL` | Jira email for user lookup and issue enrichment |
| `ATLASSIAN_API_TOKEN` | Jira API token for user lookup and issue enrichment |

## Quick Usage

### Get Worklogs for a Specific Date

```powershell
# Today
& "$env:USERPROFILE\.claude\skills\tempo\scripts\Get-TempoWorklogs.ps1"

# Specific date
& "$env:USERPROFILE\.claude\skills\tempo\scripts\Get-TempoWorklogs.ps1" -Date "2026-01-26"

# Yesterday
& "$env:USERPROFILE\.claude\skills\tempo\scripts\Get-TempoWorklogs.ps1" -Date (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
```

### Add a Worklog Entry

```powershell
# Add 2 hours to INT-14 (meetings) today at 08:00
& "$env:USERPROFILE\.claude\skills\tempo\scripts\Add-TempoWorklog.ps1" -IssueKey "INT-14" -Hours 2

# Add 4 hours to PE-992 at 13:00 with custom account
& "$env:USERPROFILE\.claude\skills\tempo\scripts\Add-TempoWorklog.ps1" -IssueKey "PE-992" -Hours 4 -StartTime "13:00" -Account "GEN-DEV"

# Add entry to a specific date
& "$env:USERPROFILE\.claude\skills\tempo\scripts\Add-TempoWorklog.ps1" -IssueKey "INT-5" -Hours 1.5 -Date "2026-01-27" -Description "Training session"
```

### Default Account Mapping

| Issue Prefix | Default Account |
|--------------|-----------------|
| INT-*        | INT (Internal)  |
| PE-*, RPLAT-*, RCOMM-*, PORT-* | GEN-DEV |

## Common Entries (Natural Language)

See `common-entries.json` for full alias list and Jira descriptions. Use natural language to log time:

| Alias | Issue | Description |
|-------|-------|-------------|
| "time off", "pto", "sick", "holiday" | INT-8 | Time Off (Sick/PTO/Holiday/Volunteer) |
| "meetings", "mtg", "standup" | INT-14 | Company/Team Meetings & Events |
| "relias assistant", "ra", "assistant" | PE-992 | Relias Assistant -- second milestone |
| "ai chapter", "ai", "chapter" | PE-931 | AI Chapter (Foundation & Engineering) |
| "pe support", "support", "devex" | PE-869 | Productivity Engineering Support |
| "professional development", "pd", "training" | INT-5 | Professional Development |
| "assistant beta", "ra beta" | PE-904 | Relias Assistant -- first beta milestone |
| "legacy release", "lrt", "release tool" | PE-889 | Legacy Release Tool |
| "ai task force", "task force", "atf" | RPLAT-17591 | AI Task Force |

**Example natural language requests:**

- "Record 4 hours of meetings and 4 hours of Relias Assistant yesterday"
- "Log 2 hours of AI chapter work and 6 hours on PE support for Monday"
- "Add 8 hours PTO for Friday"

## Weekly Target

- **8 hours/day** | **40 hours/week**
- Adjust for holidays (use INT-8 for time off)
- See `common-entries.json` for 2026 holiday list

## API Reference

- **Base URL**: `https://api.tempo.io/4`
- **Auth**: Bearer token in `Authorization` header
- **Regional endpoints**: `api.us.tempo.io`, `api.eu.tempo.io` (if main fails)

### Key Endpoints

| Endpoint | Description |
|----------|-------------|
| `/worklogs/user/{accountId}?from={date}&to={date}` | User's worklogs for date range |
| `/worklogs?from={date}&to={date}&limit=100` | All worklogs for date range |
| `/accounts` | List all Tempo accounts (billing codes) |
| `/teams` | List all teams |
| `/teams/{id}/members` | Team members |

## Token Scopes

Available scopes when creating a Tempo API token:

| Scope | Access |
|-------|--------|
| Worklogs | View/Manage time entries |
| Teams | View/Manage teams and memberships |
| Accounts | View/Manage billing accounts |
| Plans | Resource planning |
| Periods | Time periods |
| Schemes | Workload/Holiday schemes |

## Example Output

### Get Worklogs

```
Tempo Entries for Franz Hemmer - 2026-01-26

Time  Hours Issue  Title                                      Account
----  ----- -----  -----                                      -------
08:00  1.00 INT-14 Company/Team Meetings & Events             Internal
09:00  4.00 INT-5  Professional Development                   Internal
13:00  3.00 PE-992 Relias Assistant -- Reach second milestone General-Dev and Design

TOTAL: 8 hours
```

### Add Worklog

```
Worklog created successfully!

Date       Time  Hours Issue  Title                          Account WorklogID
----       ----  ----- -----  -----                          ------- ---------
2026-01-28 08:00  2.00 INT-14 Company/Team Meetings & Events INT        749673
```

## Token Setup

### Create New Token

1. Go to Tempo API Integration: `https://relias.atlassian.net/plugins/servlet/ac/io.tempo.jira/tempo-app#!/configuration/api-integration`
2. Click "New Token"
3. Select desired scopes (Worklogs: Manage, Accounts: View, Teams: View)
4. Set expiration (default: 1 year)
5. Copy the token and set as system environment variable: `TEMPO_API_TOKEN`

### Refresh/Regenerate Token

1. Go to same URL: `https://relias.atlassian.net/plugins/servlet/ac/io.tempo.jira/tempo-app#!/configuration/api-integration`
2. Find existing token and click "Regenerate" (invalidates old token) or delete and create new
3. Update the `TEMPO_API_TOKEN` system environment variable with new value

### Current Token

- **Created**: 2026-01-28
- **Expires**: 2027-01-28 (1 year)
- **Scopes**: Worklogs (Manage), Accounts (View), Teams (View)
