---
name: cloudflare
description: V1.0 - Cloudflare usage statistics for web analytics and email routing across managed domains. Use when checking page views, unique visitors, or email forwarding stats.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the cloudflare directory (path contains 'cloudflare'), verify that history logging occurred.

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
            Before stopping, if cloudflare was used (check if any files in cloudflare directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in cloudflare directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Cloudflare

Fetches usage statistics from Cloudflare for managed domains.

## Default Action

When activated without parameters, run `Get-CloudflareUsage.ps1` for yesterday's date and display results.

## Managed Domains

| Domain | Zone ID | Web Analytics | Email Routing |
|---|---|---|---|
| nowleadershipgroup.com | 23882174cdf6c55620b0c186e4e3aaf2 | Yes | Yes |
| setitfreeloop.org | c4fb19a03acf1631cc846cea7b6040b0 | Yes | No |

## Environment

- **Token**: `CLOUDFLARE_API_TOKEN` (system-level environment variable)
- **API**: Cloudflare GraphQL Analytics API (`https://api.cloudflare.com/client/v4/graphql`)

## Usage

```powershell
# Yesterday's stats (default)
& "$PSScriptRoot/scripts/Get-CloudflareUsage.ps1"

# Specific date
& "$PSScriptRoot/scripts/Get-CloudflareUsage.ps1" -Date "2026-03-01"
```

## Output Format

Returns markdown suitable for diary injection:

```markdown
- **nowleadershipgroup.com**: 42 page views, 18 unique visitors, 3 emails forwarded
- **setitfreeloop.org**: 15 page views, 8 unique visitors
```
