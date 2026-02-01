---
name: verbiage
description: V1.0 - Creates and manages VERBIAGE.md terminology dictionary in repo root. Invoke without parameters for empty table, or specify terms to add.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the verbiage directory (path contains 'verbiage'), verify that history logging occurred.
            
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
            Before stopping, if verbiage was used (check if any files in verbiage directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in verbiage directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Verbiage

Manage repository terminology dictionary.

## Usage

- **No parameters**: Create empty VERBIAGE.md
- **With terms**: Add specified term definitions

## File Location

`{repo-root}/VERBIAGE.md`

## Format

```markdown
# Verbiage

Project terminology dictionary.

| Term | Definition |
|------|------------|
| Activity Bar | Vertical icon strip on the far left of the app |
```

## Actions

### Create/Update VERBIAGE.md

1. Check if `VERBIAGE.md` exists in repo root
2. If not, create with header and empty table
3. If terms provided, add them to the table
4. Keep entries alphabetically sorted

### Add Terms

When user provides terms:

- `"Activity Bar: Vertical icon strip"` → Add as new row
- Multiple terms can be added at once
