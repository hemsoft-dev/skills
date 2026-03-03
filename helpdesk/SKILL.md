---
name: helpdesk
description: "V1.0 - Commands: list. Query Jira Service Management (JSM) helpdesk tickets via REST API using existing Atlassian credentials."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the helpdesk directory (path contains 'helpdesk'), verify that history logging occurred.
            
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
            Before stopping, if helpdesk was used (check if any files in helpdesk directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in helpdesk directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Helpdesk

Query Jira Service Management (JSM) helpdesk tickets using the `/rest/servicedeskapi/` REST API.

## Authentication

Uses the same credentials as the JIRA skill:

- `ATLASSIAN_EMAIL` — your Atlassian account email
- `ATLASSIAN_API_TOKEN` — API token from <https://id.atlassian.com/manage-profile/security/api-tokens>

## Commands

### list

List helpdesk tickets (customer requests). Defaults to your own open requests.

```powershell
# List your open requests (default)
& "$PSScriptRoot\scripts\Get-HelpdeskRequests.ps1"

# List requests for a specific service desk
& "$PSScriptRoot\scripts\Get-HelpdeskRequests.ps1" -ServiceDeskId 1

# List with a specific status filter
& "$PSScriptRoot\scripts\Get-HelpdeskRequests.ps1" -Status "OPEN"

# Increase result count
& "$PSScriptRoot\scripts\Get-HelpdeskRequests.ps1" -MaxResults 50
```
