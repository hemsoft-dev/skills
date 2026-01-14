---
name: opencode
description: V1.1 - Executes AI prompts using OpenCode CLI with OpenRouter models for clean, configuration-free execution.
compatibility: Requires opencode CLI installed via winget and OPENROUTER_API_KEY environment variable
metadata:
  author: skills-agent
  version: "1.1"
---

# OpenCode

Executes AI prompts using the OpenCode CLI with OpenRouter models (Claude 3.5 Haiku by default). Uses OPENROUTER_API_KEY from environment for authentication.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Command Format

**Basic execution:**

```powershell
opencode run -m "openrouter/anthropic/claude-3.5-haiku" "{prompt}"
```

**With different model:**

```powershell
opencode run -m "openrouter/anthropic/claude-3.5-sonnet" "{prompt}"
```

## Available Models

- `openrouter/anthropic/claude-3.5-haiku` - Fast, cost-effective (default)
- `openrouter/anthropic/claude-3.5-sonnet` - More capable
- `openrouter/openai/gpt-4o` - OpenAI's latest
- `openrouter/google/gemini-2.0-flash-exp:free` - Free tier option

## Prerequisites

OpenCode uses the `OPENROUTER_API_KEY` environment variable for authentication. Ensure this is set in your PowerShell profile or system environment variables.

## Workflow

1. **Receive user prompt** - Get the question or task
2. **Execute opencode** - Run with specified model and prompt
3. **Return output** - Display results to user

## Example Usage

**User request:** "What is the weather in 28117?"

**Command:**

```powershell
opencode run -m "openrouter/anthropic/claude-3.5-haiku" "What is the weather in 28117?"
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `opencode: command not found` | Install via `winget install --id SST.opencode -e` |
| Google AI key error | Ensure dummy env var is set in same command |
| Model not found | Verify model name follows openrouter format |

## Notes

- OpenCode uses OpenRouter by default if configured
- The dummy Google AI key prevents unnecessary API key checks
- Authentication error | Verify `OPENROUTER_API_KEY` is set in environment |
| Model not found | Verify model name follows openrouter format |

## Notes

- OpenCode automatically detects and uses `OPENROUTER_API_KEY` from environment
- No additional authentication setup required