---
name: create-alias
description: V1.0 - Creates PowerShell aliases in the global profile that work across all terminals. Supports both simple aliases and function-based aliases with arguments.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the create-alias directory (path contains 'create-alias'), verify that history logging occurred.
            
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
            Before stopping, if create-alias was used (check if any files in create-alias directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in create-alias directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Create Alias

Creates PowerShell aliases in the global profile (`$PROFILE.CurrentUserAllHosts`) that work across all terminals (Windows Terminal, VS Code, PowerShell console, PowerShell 7).

## Parameters

- `{alias-name}` - The name of the alias (e.g., "play", "gs", "dc")
- `{command}` - The command to execute when the alias is triggered (e.g., "ffplay --nodisp -autoexit $args", "git status", "docker-compose @args")

## Usage

Use the script `scripts/New-Alias.ps1`:

```powershell
& "$env:USERPROFILE\.claude\skills\create-alias\scripts\New-Alias.ps1" -AliasName "play" -Command "ffplay --nodisp -autoexit `$args"
```

## Behavior

1. **Checks if alias exists** - If the alias already exists in the profile, prompts for replacement
2. **Uses CurrentUserAllHosts profile** - Adds to `$PROFILE.CurrentUserAllHosts` (profile.ps1) for global availability
3. **Creates function-based aliases** - Uses functions with `@args` for proper argument handling
4. **Backs up profile** - Creates timestamped backup before modifications
5. **Validates command** - Ensures the command syntax is valid

## Important Notes

- **Never sources the profile** - After creating an alias, tell the user to restart their terminal or open a new one
- **Works across all terminals** - Uses CurrentUserAllHosts profile location
- **Functions vs Aliases** - Prefers functions over `New-Alias` for better argument handling and flexibility

## Examples

**Simple command:**

```powershell
New-Alias.ps1 -AliasName "gs" -Command "git status"
```

**Command with arguments:**

```powershell
New-Alias.ps1 -AliasName "play" -Command "ffplay --nodisp -autoexit `$args"
```

**Command with @args splatting:**

```powershell
New-Alias.ps1 -AliasName "dc" -Command "docker-compose @args"
```
