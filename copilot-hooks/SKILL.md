---
name: copilot-hooks
description: "V1.0 - Commands: install, verify, uninstall. Reuse this repo's proven pre-commit hook setup in other repositories with script-first and manual fallback workflows."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the copilot-hooks directory (path contains 'copilot-hooks'), verify that history logging occurred.

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
            Before stopping, if copilot-hooks was used (check if any files in copilot-hooks directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in copilot-hooks directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Copilot Hooks

When user activates this skill without specifying an action, do `install` against the current working directory.

This skill now installs two related systems:

1. Git commit-time Markdown quality gates (`pre-commit` flow).
2. Copilot session-end Stop automation (`auto-commit + push` flow).

The install process is Husky-aware and avoids the common trap where `.git/hooks/pre-commit` exists but Git actually executes `.husky/_`.

## What This Skill Installs

| File | Location | Purpose |
| --- | --- | --- |
| `pre-commit` | `.git/hooks/pre-commit` | Shell wrapper that runs PowerShell-based checks |
| `pre-commit-markdown.ps1` | `.git/hooks/pre-commit-markdown.ps1` | Lints staged Markdown files with `markdownlint-cli2` |
| `.markdownlint.jsonc` (optional) | Repo root | Starter markdownlint config if missing |
| Husky markdown gate block | `.husky/pre-commit` | Calls `.git/hooks/pre-commit-markdown.ps1` when `core.hooksPath=.husky/_` |
| `Invoke-AgentSessionAutoPush.ps1` | `.github/hooks/Invoke-AgentSessionAutoPush.ps1` | Copilot Stop hook session-end auto-commit/push |
| Stop hook entry | `.github/hooks/hooks.json` | Registers Stop command to run `Invoke-AgentSessionAutoPush.ps1` |

## Commands

| Command | Script | Typical Use |
| --- | --- | --- |
| `install` | `scripts/1-Install-CopilotHooks.ps1` | Add hook files to a repo |
| `verify` | `scripts/2-Verify-CopilotHooks.ps1` | Confirm hook files and baseline wiring |
| `uninstall` | `scripts/3-Uninstall-CopilotHooks.ps1` | Remove files managed by this skill |

## Scope Clarification

- `Git hooks`: run at commit time (`pre-commit`).
- `Copilot Stop hook`: runs when the Copilot session ends.

If Stop automation is not firing, debug `.github/hooks/hooks.json` first.

## Decision Table

| Situation | Action |
| --- | --- |
| User says "set up hooks" with no path | Run `install` with default `.` |
| User gives a repo path | Run chosen command with `-RepoPath` |
| User asks for safety check | Run `verify` |
| User wants rollback | Run `uninstall` |

## Script-First Workflow

### Step 1: Install

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\copilot-hooks\scripts\1-Install-CopilotHooks.ps1
```

### Step 2: Verify

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\copilot-hooks\scripts\2-Verify-CopilotHooks.ps1
```

### Step 3: Optional Uninstall

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\copilot-hooks\scripts\3-Uninstall-CopilotHooks.ps1
```

### Step 4: Restart Copilot Session

Copilot hook configuration is often loaded at session start. After changing `.github/hooks/*.json`, start a fresh Copilot session before testing Stop behavior.

## Manual Fallback Workflow

### Step 1: Create `.git/hooks/pre-commit`

```sh
#!/bin/sh
# Managed by copilot-hooks skill
# Windows Git hook wrapper - calls PowerShell and Markdown quality checks

POWERSHELL_EXIT=0
if [ -f ".git/hooks/pre-commit.ps1" ]; then
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ".git/hooks/pre-commit.ps1"
  POWERSHELL_EXIT=$?
fi

pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ".git/hooks/pre-commit-markdown.ps1"
MARKDOWN_EXIT=$?

if [ $POWERSHELL_EXIT -ne 0 ] || [ $MARKDOWN_EXIT -ne 0 ]; then
  exit 1
fi

exit 0
```

### Step 2: Create `.git/hooks/pre-commit-markdown.ps1`

Run `scripts/1-Install-CopilotHooks.ps1` if possible. If manual creation is required, use the script content in that file exactly.

### Step 3: Create `.markdownlint.jsonc` if missing

Use a project-specific config or the starter config generated by `install`.

### Step 4: Wire Copilot Stop hook

Create or update `.github/hooks/hooks.json` with a Stop command:

```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "windows": "pwsh -NoProfile -ExecutionPolicy Bypass -File ./.github/hooks/Invoke-AgentSessionAutoPush.ps1",
        "timeout": 120
      }
    ]
  }
}
```

Create `.github/hooks/Invoke-AgentSessionAutoPush.ps1` using the script generated by `install`.

## Parameters

| Script | Parameter | Required | Default |
| --- | --- | --- | --- |
| `1-Install-CopilotHooks.ps1` | `-RepoPath` | No | `.` |
| `2-Verify-CopilotHooks.ps1` | `-RepoPath` | No | `.` |
| `3-Uninstall-CopilotHooks.ps1` | `-RepoPath` | No | `.` |
| `3-Uninstall-CopilotHooks.ps1` | `-Force` | No | `false` |

## Expected Output

| Command | Success Signal | Failure Signal |
| --- | --- | --- |
| `install` | "Install complete" | Non-zero exit code with missing prerequisite message |
| `verify` | "All checks passed" | Non-zero exit code with failed check summary |
| `uninstall` | "Uninstall complete" | Non-zero exit code if non-managed files would be removed without `-Force` |

## Hardening Notes

- Install scripts place `param(...)` first so PowerShell parses them correctly.
- Markdown hook uses `${file}` string interpolation to avoid the `$file:` parser error.
- Stop auto-push handles non-fast-forward push failures by running `git pull --rebase` and retrying push.
- Verify checks Husky-vs-Git-hook wiring so mismatched hook paths are caught immediately.
