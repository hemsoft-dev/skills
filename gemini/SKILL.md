---
name: gemini
description: V1.3 - Interact with Google Gemini AI via CLI for prompts, code assistance, and chat sessions. Installed via npm with update instructions.
---

# Gemini CLI

Execute prompts with Google Gemini AI via command line.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## ALWAYS: Retrospective Check

Before completing, reflect on this interaction:

1. Were new patterns or edge cases discovered?
2. Could instructions be clearer?
3. Do scripts need improvements or bug fixes?
4. Should new capabilities be added?

If improvements identified:

- Present proposed changes with clear rationale
- Wait for user approval before applying
- Keep skill concise (remove/condense when adding if possible)
- Version bump SKILL.md if changes applied

## Installation

### Official Method: npm (Recommended)

Gemini CLI is distributed as an npm package by Google:

```powershell
npm install -g @google/gemini-cli
```

**Installation Details:**

- **Package name:** `@google/gemini-cli` (scoped package)
- **CLI command:** `gemini`
- **Location:** `%APPDATA%\npm\gemini.cmd` (Windows)
- **Official channel:** npm registry

**Important Notes:**

- ✅ Use **npm** - official distribution channel from Google
- ❌ **NOT available in Scoop** - no Windows package manager option
- ❌ **NOT a standalone binary** - requires Node.js/npm
- ⚠️ Requires Node.js installed first

### Verify Installation

```powershell
gemini --version
```

## Updating Gemini CLI

### Check Current Version

```powershell
gemini --version
npm list -g @google/gemini-cli
```

### Update to Latest

```powershell
# Update to latest stable
npm update -g @google/gemini-cli

# Or explicitly install latest
npm install -g @google/gemini-cli@latest
```

### Update to Preview/Pre-release

```powershell
# For preview releases (e.g., v0.27.0-preview.0)
npm install -g @google/gemini-cli@latest --tag next
```

**Update Strategy:**

- Gemini CLI releases preview versions frequently
- Check [GitHub releases](https://github.com/google-gemini/gemini-cli/releases) for latest version
- npm is the ONLY official update method
- No auto-update command like Bun or other native CLIs

## Model Configuration

### Default Model

The Gemini CLI uses **`gemini-2.5-pro`** as its hardcoded default when no model is specified.

### Model Selection Priority

The CLI determines which model to use in this order:

1. **Command line flag**: `--model <model_name>`
2. **Environment variable**: `GEMINI_MODEL`
3. **Settings file**: `model.name` in `~/.gemini/settings.json`
4. **Default fallback**: `gemini-2.5-pro`

### Available Models

| Model | Use Case |
|-------|----------|
| `gemini-2.5-pro` | Default, balanced performance |
| `gemini-2.5-flash` | Faster, cheaper responses |
| `gemini-3-pro` | Latest, most capable |

## Billing & Pricing

### Free Tier

- **Gemini 2.5 Pro** (≤200K tokens): Free input/output up to rate limits
- **Rate limits**: 1,500 grounding requests/day (Search/Maps)
- No billing account required within limits

### Paid Tier (Pay-as-You-Go)

Only charged when exceeding free tier limits. Requires Cloud Billing enabled in Google Cloud project.

**Gemini 2.5 Pro:**

| Token Count | Input | Output |
|-------------|-------|--------|
| ≤200K tokens | $1.25/M | $10.00/M |
| >200K tokens | $2.50/M | $15.00/M |

**Gemini 2.5 Flash-Lite** (cheaper):

- Input: $0.10/M tokens
- Output: $0.40/M tokens

**Note:** Failed requests (4xx/5xx) are not charged.

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
