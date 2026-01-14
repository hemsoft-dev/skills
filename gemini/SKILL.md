---
name: gemini
description: V1.0 - Interact with Google Gemini AI via CLI for prompts, code assistance, and chat sessions.
---

# Gemini CLI

Execute prompts with Google Gemini AI via command line.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Basic Usage

### One-Shot Prompt

```powershell
gemini "Your prompt here"
```

### Interactive Chat

```powershell
gemini
```

### Continue Interactive After Prompt

```powershell
gemini -i "Initial prompt" 
```

## Common Options

| Option | Description |
|--------|-------------|
| `-m, --model` | Specify model |
| `-y, --yolo` | Auto-approve all actions |
| `--approval-mode` | Set approval: `default`, `auto_edit`, `yolo` |
| `-r, --resume` | Resume session (use `latest` or index) |
| `--list-sessions` | List available sessions |

## Authentication

First run prompts OAuth login via browser:

```powershell
gemini "test"
```

Credentials cached for future use.

## IDE Integration

Install VS Code companion extension:

```powershell
gemini /ide install
```
