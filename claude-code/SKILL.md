---
name: claude-code
description: V1.1 - Expert in Claude Code CLI tool by Anthropic. Use when working with Claude Code, managing installations, updates, configurations, or executing Claude-powered development workflows.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the claude-code directory (path contains 'claude-code'), verify that history logging occurred.
            
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
            Before stopping, if claude-code was used (check if any files in claude-code directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in claude-code directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Claude Code

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert in Claude Code CLI tool by Anthropic for AI-powered development workflows.

## Overview

Claude Code is Anthropic's command-line interface that provides direct access to Claude models for code generation, assistance, and AI-powered development workflows.

## Installation

**Download from website:**

- Visit <https://claude.ai/download> and download the installer

**Via npm:**

```bash
npm install -g @anthropic-ai/claude-code
```

## Update

```bash
# Check for updates (built-in command)
claude update

# Or reinstall via npm
npm update -g @anthropic-ai/claude-code
```

## Version Check

```bash
# Check installed version
claude --version

# Check latest available version
npm view @anthropic-ai/claude-code version

# Or check website
# https://claude.ai/download
```

## Usage

```bash
# Run Claude Code
claude

# Check version
claude --version

# Update to latest
claude update
```

## PowerShell Wrapper Function: CC

A PowerShell function `CC` (or `cc`) is available that wraps Claude Code with auto-permissions:

**Function Definition:**

```powershell
function cc { 
    if ($args.Count -eq 0) {
        claude --allow-dangerously-skip-permissions
    } else {
        claude --allow-dangerously-skip-permissions prompt @args
    }
}
```

**What it does:**

- Calls `claude` with `--allow-dangerously-skip-permissions` flag
- **No arguments**: Starts Claude Code in interactive mode
- **With arguments**: Uses `prompt` subcommand and passes through arguments via `@args`

**Usage:**

```powershell
# Interactive mode (no arguments)
cc
# Equivalent to: claude --allow-dangerously-skip-permissions

# Prompt mode (with arguments)
cc "write a hello world script"
# Equivalent to: claude --allow-dangerously-skip-permissions prompt "write a hello world script"
```

**Benefits:**

- Shorter command name (`cc` vs `claude`)
- Automatically skips permission prompts for faster workflow
- Interactive mode when called without arguments
- Prompt mode when arguments are provided
- All arguments are passed through to the underlying `claude` command

## Resources

- Website: <https://claude.ai>
- Documentation: <https://docs.anthropic.com>
- GitHub: <https://github.com/anthropics/claude-code>
- Changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>

## Notes

- Uses Pro subscription token for usage
- Provides direct CLI access to Claude models
- Supports code generation and AI-powered development workflows
