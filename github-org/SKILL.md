---
name: github-org
description: "V1.0 - Commands: admins. Repeatable GitHub organization inventory and governance queries using GitHub CLI/API, including deterministic org admin listings."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the github-org directory (path contains 'github-org'), verify that history logging occurred.

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
            Before stopping, if github-org was used (check if any files in github-org directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in github-org directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}
---

# GitHub Org

Use this skill for repeatable GitHub organization inventory, ownership, and governance queries.

## Commands

| Command | Script | Purpose |
| --- | --- | --- |
| `admins` | `scripts/Get-GitHubOrgAdmins.ps1` | List organization admins/owners with public profile names. |

## Admin Inventory

Generic:

```powershell
& "$env:USERPROFILE\.agents\skills\github-org\scripts\Get-GitHubOrgAdmins.ps1" -Owner relias-engineering
```

Relias shortcut:

```powershell
& "$env:USERPROFILE\.agents\skills\github-org\scripts\Get-ReliasEngineeringOrgAdmins.ps1"
```

The admin script:

- Uses `gh api --paginate --slurp "/orgs/{org}/members?role=admin&per_page=100"`.
- Fetches each user's public profile via `/users/{login}` for the `Name` column.
- Sorts by login for deterministic output.
- Supports `-Format Table|Json|Csv`.
- Does not modify GitHub state.

