---
name: copilot-license
description: "V1.0 - Commands: ListSeats, InactiveCandidates, AssignLicense, RemoveLicense. Manage GitHub Copilot seat assignments in an organization — list seats, find inactive users, assign and remove licenses via the Copilot billing API."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the copilot-license directory (path contains 'copilot-license'), verify that history logging occurred.

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
            Before stopping, if copilot-license was used (check if any files in copilot-license directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in copilot-license directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Copilot License Manager

Manage GitHub Copilot seat assignments in an organization using the Copilot billing API.

## Default Behavior

When activated without specifying a command, run **ListSeats** for the default organization.

## Prerequisites

- Authenticated via `gh auth login` with an account that has **org owner** or **billing manager** permissions
- Organization must have **Copilot Business** or **Copilot Enterprise** enabled

## Commands

### ListSeats

List all Copilot seat assignments for an organization with activity details.

```powershell
.\scripts\Get-CopilotSeats.ps1 -Org {org}
```

### InactiveCandidates

Find users who have not used Copilot in the current billing month — candidates for license removal.

```powershell
.\scripts\Get-InactiveCopilotUsers.ps1 -Org {org}
.\scripts\Get-InactiveCopilotUsers.ps1 -Org {org} -InactiveDays 30
.\scripts\Get-InactiveCopilotUsers.ps1 -Org {org} -ExportCsv
```

### AssignLicense

Assign Copilot licenses to one or more users.

```powershell
.\scripts\Set-CopilotLicense.ps1 -Org {org} -Action Assign -Users "user1","user2"
```

### RemoveLicense

Remove Copilot licenses from one or more users (sets to pending cancellation).

```powershell
.\scripts\Set-CopilotLicense.ps1 -Org {org} -Action Remove -Users "user1","user2"
```

## API Reference

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/orgs/{org}/copilot/billing/seats` | GET | List all seat assignments with last activity |
| `/orgs/{org}/copilot/billing` | GET | Billing summary with seat breakdown |
| `/orgs/{org}/copilot/billing/selected_users` | POST | Assign licenses to users |
| `/orgs/{org}/copilot/billing/selected_users` | DELETE | Remove licenses (pending cancellation) |

## Script Reference

| Script | Command | Purpose |
| --- | --- | --- |
| `Get-CopilotSeats.ps1` | ListSeats | Lists all seats with activity, editor, and plan info |
| `Get-InactiveCopilotUsers.ps1` | InactiveCandidates | Finds users with no activity in current month |
| `Set-CopilotLicense.ps1` | AssignLicense / RemoveLicense | Assigns or removes licenses for specified users |

## Important Notes

- **RemoveLicense** sets seats to **pending cancellation** — the license remains active until the end of the current billing cycle
- **InactiveCandidates** uses the `last_activity_at` field from the seats API, which tracks the last time the user used Copilot in any editor
- The seats API is paginated (max 100 per page) — scripts handle pagination automatically
- `gh` CLI must be authenticated as an org owner or billing manager
