---
name: openrouter
description: V1.0 - Check OpenRouter credit balance and API usage via the /api/v1/credits endpoint
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the openrouter directory (path contains 'openrouter'), verify that history logging occurred.
            
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
            Before stopping, if openrouter was used (check if any files in openrouter directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in openrouter directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# OpenRouter

Check OpenRouter credit balance and API usage statistics.

## Quick Check

Use the built-in script to check your current balance:

```powershell
& ~/.claude/skills/openrouter/scripts/Get-OpenRouterBalance.ps1
```

## API Response Format

The OpenRouter credits endpoint returns:

```json
{
  "data": {
    "total_credits": 70.00,
    "total_usage": 45.48
  }
}
```

## Manual API Call

```bash
curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" https://openrouter.ai/api/v1/credits
```

## Environment Variable

Requires `OPENROUTER_API_KEY` environment variable to be set.

Get your API key at: <https://openrouter.ai/keys>
