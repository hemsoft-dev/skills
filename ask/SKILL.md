---
name: ask
description: V1.2 - Unified AI CLI interface for Claude, Gemini, Copilot, and OpenCode with 22 model variants, clean output, and interactive model listing. Golden rule - defaults to cheapest/fastest model.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the ask directory (path contains 'ask'), verify that history logging occurred.
            
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
            Before stopping, if ask was used (check if any files in ask directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in ask directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Ask - Unified AI CLI Interface

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

A PowerShell function that provides a unified, simplified interface for **4 AI CLI tools** (Claude Code, Gemini CLI, GitHub Copilot CLI, and OpenCode) with **22 model variants**, clean output, and helpful model listings.

## Overview

The `ask` function lives in your PowerShell profile (`$PROFILE.CurrentUserAllHosts`) and provides:

- **Unified syntax** across 4 AI providers (Claude, Gemini, Copilot, OpenCode)
- **22 model variants** with simple colon notation
- **Golden rule**: Defaults to cheapest/fastest model for each tool
- **Clean output** with automatic noise suppression (stderr redirection)
- **Interactive help** showing available models per tool
- **Auto-approval** for faster workflows

## Installation

The function is automatically available after restarting your terminal (it's in your PowerShell profile at `D:\OneDrive\Documents\PowerShell\profile.ps1`).

## Usage

### Basic Syntax

```powershell
ask <tool>[:<model>] "your prompt"
```

### Show Available Tools

```powershell
# Show all tools
ask

# Output:
# Available AI CLI tools:
#   claude
#   gemini
#   copilot
#   opencode
#
# Usage: ask <tool> - Show available models
#        ask <tool>[:<model>] "prompt" - Run prompt
#
# Golden Rule: Defaults use cheapest/fastest model
```

### Show Available Models

```powershell
# Show Claude models
ask claude

# Show Gemini models
ask gemini

# Show Copilot models
ask copilot

# Show OpenCode models
ask opencode
```

### Claude Examples (4 models)

```powershell
# Use default model (Haiku 4.5 - cheapest)
ask claude "What is the weather in 28117?"

# Use specific models
ask claude:haiku "What is 2+2?"
ask claude:sonnet "Write a hello world script"
ask claude:opus "Explain quantum computing"
```

**Claude models:**

- `claude` / `claude:haiku` - Haiku 4.5 (default, fastest, cheapest)
- `claude:sonnet` - Sonnet 4.5 (balanced)
- `claude:opus` - Opus 4.5 (most capable)

### Gemini Examples (3 models)

```powershell
# Use default model (Flash 3 - cheapest)
ask gemini "What is the weather in 28117?"

# Use specific models
ask gemini:flash "What is 2+2?"
ask gemini:pro "Explain machine learning"
```

**Gemini models:**

- `gemini` / `gemini:flash` - Gemini 3 Flash (default, fastest, cheapest)
- `gemini:pro` - Gemini 3 Pro (most capable)

### Copilot Examples (6 models)

```powershell
# Use default model (GPT-5 Mini - cheapest)
ask copilot "What is the weather in 28117?"

# Use specific models
ask copilot:mini "What is 2+2?"
ask copilot:codex "Write a binary search"
ask copilot:claude "Explain async/await"
ask copilot:gemini "Translate to Spanish"
ask copilot:gpt5 "Write a poem"
```

**Copilot models:**

- `copilot` / `copilot:mini` - GPT-5 Mini (default, fastest, cheapest)
- `copilot:codex` - GPT-5.1 Codex Max (best for coding)
- `copilot:claude` - Claude Haiku 4.5 (Claude via Copilot)
- `copilot:gemini` - Gemini 3 Pro (Gemini via Copilot)
- `copilot:gpt5` - GPT-5.2 (latest GPT)

### OpenCode Examples (7 models)

```powershell
# Use default model (Claude Haiku 4.5 - cheapest)
ask opencode "What is the weather in 28117?"

# Use specific models
ask opencode:haiku "What is 2+2?"
ask opencode:sonnet "Write a REST API"
ask opencode:opus "Explain concurrency"
ask opencode:gpt "Write a loop"
ask opencode:grokfree "Hi"
ask opencode:kimi "你好"
ask opencode:glm "Hello"
```

**OpenCode models:**

- `opencode` / `opencode:haiku` - Claude Haiku 4.5 (default, fastest, cheapest)
- `opencode:sonnet` - Claude Sonnet 4.5 (balanced)
- `opencode:opus` - Claude Opus 4.5 (most capable)
- `opencode:gpt` - GPT-5.2 Codex (coding optimized)
- `opencode:grokfree` - Grok Code Fast (free tier)
- `opencode:kimi` - Kimi K2.5 (MoonshotAI)
- `opencode:glm` - GLM-4.7 (Z-AI)

## How It Works

### Claude Integration

- Command: `claude --dangerously-skip-permissions --print --model <variant> "<prompt>"`
- Model selection via `--model` flag
- Default model: `haiku` (Haiku 4.5 - cheapest/fastest)

### Gemini Integration

- Command: `gemini --yolo --model gemini-3-<variant> "<prompt>" 2>$null`
- Uses `--yolo` for auto-approval
- **Stderr suppression** via `2>$null` for clean output (removes INFO messages)
- Default model: `gemini-3-flash` (Flash 3 - cheapest/fastest)

### Copilot Integration

- Command: `copilot --allow-all --model <model> -p "<prompt>" --silent`
- Uses `--allow-all` for full permissions (tools, paths, URLs)
- Uses `--silent` to suppress progress output
- Model map translates short names (mini, codex, claude, gemini, gpt5) to full names
- Default model: `gpt-5-mini` (GPT-5 Mini - cheapest/fastest)

### OpenCode Integration

- Command: `opencode run -m "<provider/model>" "<prompt>" 2>$null`
- Uses `-m` flag for model specification
- **Stderr suppression** via `2>$null` for clean output (removes INFO messages)
- Model map translates short names to full provider/model format
- Supports both github-copilot and openrouter providers
- Default model: `github-copilot/claude-haiku-4.5` (Haiku 4.5 - cheapest/fastest)

### Model Variant Parsing

The function:

1. Splits the tool name by colon (`:`)
2. Extracts tool (`claude`, `gemini`, `copilot`, `opencode`) and optional model variant
3. Routes to appropriate CLI with model flag if specified
4. Falls back to default model if no variant provided (follows golden rule: cheapest/fastest)

## Implementation Details

### Function Location

```
D:\OneDrive\Documents\PowerShell\profile.ps1
```

### Core Logic

```powershell
function ask {
    # Parse tool and model from first argument
    $toolParts = $args[0] -split ':'
    $tool = $toolParts[0]
    $model = if ($toolParts.Count -gt 1) { $toolParts[1] } else { $null }
    
    # Show models if no prompt provided
    if ($args.Count -eq 1) {
        # Display available models for the tool
        return
    }
    
    # Join remaining arguments as prompt
    $prompt = $args[1..($args.Count-1)] -join ' '
    
    # Route to appropriate CLI
    switch ($tool.ToLower()) {
        'claude' { 
            # Call claude with optional model flag
        }
        'gemini' { 
            # Call gemini with yolo, optional model, and stderr suppression
        }
    }
}
```

## Troubleshooting

### Claude Issues

- **Command not found**: Ensure Claude Code CLI is installed (`claude --version`)
- **Authentication**: Run `claude` once interactively to authenticate

### Gemini Issues

- **Noisy output**: The function includes `2>$null` to suppress stderr
- **Extension errors**: If you see chrome-devtools-mcp errors, check `C:\Users\User\.gemini\extensions\extension-enablement.json` and remove orphaned extension references
- **Rate limits**: Free tier has rate limits; use `gemini:flash` for faster/cheaper queries
- **Command not found**: Ensure Gemini CLI is installed (`npm install -g @google/generative-ai-cli`)

### Copilot Issues

- **Hangs on queries**: Use `--allow-all` instead of `--allow-all-tools` for web searches/weather
- **Model not found**: Check available models with `copilot models list`
- **Command not found**: Ensure GitHub Copilot CLI is installed (`npm install -g @githubnext/github-copilot-cli`)

### OpenCode Issues

- **Hangs in scripts**: OpenCode requires an interactive terminal (TTY). Works in PowerShell terminal but not via automation tools
- **Noisy output**: The function includes `2>$null` to suppress INFO messages
- **Command not found**: Ensure OpenCode is installed (`winget install --id SST.opencode -e`)
- **Model not found**: Check available models with `opencode models github-copilot` or `opencode models openrouter`

### Profile Reload

**NEVER run `. $PROFILE`** - it freezes terminals. Instead, **restart your terminal** to load profile changes.

## Development History

Created on 2026-01-28 with the following evolution:

1. **Initial creation** - Basic Claude support with model variants (haiku, sonnet, opus)
2. **Gemini integration** - Added Gemini CLI with stderr suppression for clean output
3. **Model listing** - Added interactive help showing available models when called without prompt
4. **Fixed Gemini hang** - Removed orphaned chrome-devtools-mcp extension reference
5. **Golden rule** - Changed default to cheapest/fastest model for all tools
6. **Copilot integration** - Added GitHub Copilot CLI with 6 model variants
7. **OpenCode integration** - Added OpenCode with 7 model variants (Claude, GPT, Grok, Kimi, GLM)
8. **22 total models** - Now supports 4 CLI tools with 22 model variants total

## Summary

| Tool | Default Model | Model Count | Variants |
|------|--------------|-------------|----------|
| **claude** | Haiku 4.5 | 4 | haiku, sonnet, opus |
| **gemini** | Flash 3 | 3 | flash, pro |
| **copilot** | GPT-5 Mini | 6 | mini, codex, claude, gemini, gpt5 |
| **opencode** | Claude Haiku 4.5 | 7 | haiku, sonnet, opus, gpt, grokfree, kimi, glm |
| **TOTAL** | - | **22** | - |

**Golden Rule:** All tools default to their cheapest/fastest model!

## Related Skills

- `claude-code` - Claude Code CLI documentation
- `gemini` - Gemini CLI documentation and troubleshooting
- `copilot` - GitHub Copilot CLI documentation
- `opencode` - OpenCode CLI documentation
- `create-alias` - PowerShell alias creation tool
- `powershell` - PowerShell scripting and profile management

## Notes

- The function uses `Write-Host` for colored output (always visible)
- Model names are case-insensitive
- The function is available globally after terminal restart
- No PATH modifications needed - uses full CLI names
- Stderr suppression (`2>$null`) for Gemini and OpenCode removes noisy INFO messages
