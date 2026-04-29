---
name: copilot-hooks
description: "V2.0 - Commands: install, verify, uninstall. Deploy the full Copilot CLI hook system: audio notifications on task_complete, prompt logging, debug tracing, session-end auto-commit, and pre-commit markdown linting."
---

# Copilot Hooks

When user activates this skill without specifying an action, do `install` against the current working directory.

This skill installs a proven, battle-tested Copilot CLI hook system with four capabilities:

1. **Audio notification** — plays a sound when `task_complete` fires (turn is over).
2. **Prompt logging** — captures user prompts to a debug log (marks turn starts).
3. **Session-end auto-commit** — stages + commits + pushes remaining changes on session end.
4. **Pre-commit markdown linting** — blocks commits with markdownlint violations.

The install process is Husky-aware and avoids the common trap where `.git/hooks/pre-commit` exists but Git actually executes `.husky/_`.

## What This Skill Installs

| File | Location | Purpose |
| --- | --- | --- |
| `hooks.json` | `.github/hooks/hooks.json` | Registers all Copilot CLI hooks (postToolUse, userPromptSubmitted, sessionEnd) |
| `play-done.ps1` | `.github/hooks/play-done.ps1` | Audio notification on task_complete (Windows/PowerShell) |
| `play-done.sh` | `.github/hooks/play-done.sh` | Audio notification on task_complete (macOS/Linux) |
| `Log-Prompt.ps1` | `.github/hooks/Log-Prompt.ps1` | Prompt logging + debug tracing (Windows/PowerShell) |
| `log-prompt.sh` | `.github/hooks/log-prompt.sh` | Prompt logging + debug tracing (macOS/Linux) |
| `auto-commit.sh` | `.github/hooks/auto-commit.sh` | Session-end auto-commit + push |
| `hooks-settings.json` | `.github/hooks/hooks-settings.json` | Optional settings (audio enable/disable) |
| `done.mp3` | `.github/hooks/done.mp3` | Audio file (user must provide) |
| `pre-commit` | `.git/hooks/pre-commit` | Shell wrapper for pre-commit checks |
| `pre-commit-markdown.ps1` | `.git/hooks/pre-commit-markdown.ps1` | Lints staged Markdown files |
| `.markdownlint.jsonc` | Repo root | Starter markdownlint config if missing |
| Husky markdown gate block | `.husky/pre-commit` | Calls markdown lint when Husky is active |

## Commands

| Command | Script | Typical Use |
| --- | --- | --- |
| `install` | `scripts/1-Install-CopilotHooks.ps1` | Add all hook files to a repo |
| `verify` | `scripts/2-Verify-CopilotHooks.ps1` | Confirm hook files and wiring |
| `uninstall` | `scripts/3-Uninstall-CopilotHooks.ps1` | Remove all managed files |

## Prerequisites

- **FFmpeg** — required for audio notification (`ffplay` command). Install via `winget install ffmpeg` or `brew install ffmpeg`.
- **jq** — required on Linux/macOS for JSON parsing in bash hooks. Install via package manager.
- **markdownlint-cli2** — required for pre-commit markdown linting. Install via `npm install -g markdownlint-cli2`.

## Hook Architecture

### hooks.json Format (Copilot CLI 1.0.37+)

The hooks.json file uses the `"powershell"` key for Windows (invokes PowerShell directly) and `"bash"` for Unix. Valid event names: `sessionStart`, `sessionEnd`, `userPromptSubmitted`, `preToolUse`, `postToolUse`, `agentStop`, `subagentStop`, `errorOccurred`.

### postToolUse — Audio Notification

**Trigger**: Every tool call completion. **Behavior**: Reads stdin JSON for `toolName`. If `toolName === "task_complete"`, plays `done.mp3` via `ffplay`. All other tool calls are logged but produce no audio.

**Stdin JSON format**: `{ "toolName": "...", "args": {...}, "cwd": "...", "status": "...", "stdout": "...", "stderr": "...", "durationMs": N, "timestamp": "..." }`

**Why task_complete only**: Earlier approaches used debounce timers on all tool calls to detect "turn over". This was fragile (complex timer spawning, race conditions). The `task_complete` tool name reliably signals turn completion — much simpler and 100% reliable.

### userPromptSubmitted — Prompt Logging

**Trigger**: Every user prompt submission. **Behavior**: Reads stdin JSON for prompt text. Logs a `── TURN START ──` marker to `logs/hook-debug.log` and the prompt text to `logs/session/{date}.log`.

**Stdin JSON format**: `{ "prompt": "...", "userPrompt": "...", "content": "..." }` (field names vary by CLI version; scripts try all three).

### sessionEnd — Auto-Commit

**Trigger**: Session termination. **Behavior**: Stages all changes, creates `auto-commit: YYYY-MM-DD HH:MM:SS` with `--no-verify`, attempts push. Never blocks session shutdown.

### Debug Log

All hooks write to `logs/hook-debug.log` with millisecond timestamps. This provides a complete trace of:
- `── TURN START ──` markers with prompt text (from userPromptSubmitted)
- `postToolUse [toolName] fired` entries (every tool call)
- `── AUDIO PLAYING ──` markers (when task_complete triggers audio)

## Settings

Optional `hooks-settings.json` supports:
```json
{
  "audioEnabled": true
}
```

Set `audioEnabled: false` to silence notifications without removing the hook.

## Decision Table

| Situation | Action |
| --- | --- |
| User says "set up hooks" with no path | Run `install` with default `.` |
| User gives a repo path | Run chosen command with `-RepoPath` |
| User asks for safety check | Run `verify` |
| User wants rollback | Run `uninstall` |
| User wants audio only (no markdown lint) | Run `install -SkipPreCommit` |

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

### Step 4: Add Audio File

Place a `done.mp3` (or any audio file) at `.github/hooks/done.mp3`. The install script warns if this file is missing. Any short notification sound works.

### Step 5: Restart Copilot Session

Copilot hook configuration is loaded at session start. After changing `.github/hooks/hooks.json`, start a fresh Copilot session.

## Parameters

| Script | Parameter | Required | Default |
| --- | --- | --- | --- |
| `1-Install-CopilotHooks.ps1` | `-RepoPath` | No | `.` |
| `1-Install-CopilotHooks.ps1` | `-SkipPreCommit` | No | `false` |
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

- **PowerShell spawning**: Use `-File` flag (not `-Command`) when spawning background PowerShell scripts. `-Command` silently fails with complex string interpolation.
- **task_complete is the signal**: Do NOT debounce postToolUse calls with timers. Just check `toolName === "task_complete"`.
- **ffplay -nodisp -autoexit**: These flags prevent ffplay from opening a window and ensure it exits after playback.
- Markdown hook uses `${file}` string interpolation to avoid the `$file:` parser error.
- sessionEnd hook uses `--no-verify` to avoid recursive pre-commit during shutdown.
- sessionEnd hook disables interactive git prompts and uses fast-fail SSH options.
- sessionEnd hook guards against duplicate invocations within 30 seconds (both `agentStop` and `sessionEnd` may fire).
- All hooks exit 0 on failure — never block the CLI.
- The `logs/` directory is created automatically by hooks. Add `logs/` to `.gitignore`.
