---
name: goose
description: V1.1 - Use a CLI AI tool called Goose to execute the prompt.
---

# Goose

Execute prompts using the Goose AI agent by Block (Square).

## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:

```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```

## Installation

### Windows (Recommended: Official PowerShell Script)

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/block/goose/main/download_cli.ps1" -OutFile "$env:TEMP\goose_install.ps1" -UseBasicParsing
& "$env:TEMP\goose_install.ps1"
```

**CLI Location:** `~\.local\bin\goose.exe`  
**PATH:** Automatically added to user PATH  
**Configuration:** Interactive setup during first run

### Alternative: Scoop (Desktop UI)

```powershell
scoop bucket add extras
scoop install goose
```

Installs Desktop application instead of CLI.

### macOS

```bash
# Homebrew
brew install --cask block-goose

# Or download directly
# https://github.com/block/goose/releases/download/stable/Goose.zip
```

## Important Notes

**NOT a Python Package:**

- Goose is written in **Rust**, not Python
- Do NOT install via pip/pipx
- The `goose-ai` package on PyPI is a different, broken project
- Always use official installation methods above

## Using Goose

**IMPORTANT:** Always enable the Skills extension so Goose can access your Claude skills.

### PowerShell Function Setup

Add this to your PowerShell profile to automatically enable skills:

```powershell
function goose {
    if ($args[0] -eq "run" -or $args[0] -eq "session") {
        & "$env:USERPROFILE\.local\bin\goose.exe" $args[0] --with-builtin skills $args[1..($args.Count-1)]
    } else {
        & "$env:USERPROFILE\.local\bin\goose.exe" @args
    }
}
```

To add this to your profile:

```powershell
@"

# Goose CLI with automatic skills support
function goose {
    if (`$args[0] -eq `"run`" -or `$args[0] -eq `"session`") {
        & `"`$env:USERPROFILE\.local\bin\goose.exe`" `$args[0] --with-builtin skills `$args[1..(`$args.Count-1)]
    } else {
        & `"`$env:USERPROFILE\.local\bin\goose.exe`" @args
    }
}
"@ | Add-Content -Path $PROFILE
```

Then restart your terminal or run `. $PROFILE`

### CLI Commands

**Configure provider (first time):**

```powershell
goose configure
```

**Start interactive session (with skills):**

```powershell
goose session start
```

**Run single prompt (with skills):**

```powershell
goose run --text "{your prompt here}"
```

**Use specific model:**

```powershell
goose run --model claude-haiku-4.5 --text "{prompt}"
```

**List available commands:**

```powershell
goose --help
```

**Manual skills flag (if function not set up):**

```powershell
goose run --with-builtin skills --text "{prompt}"
```

### Desktop Application (if installed via Scoop)

Launch the app and interact via GUI. Supports:

- LLM provider configuration (OpenAI, Anthropic, etc.)
- Project context awareness
- File operations and code generation
- MCP server extensions

## Resources

- **Official Site:** <https://block.github.io/goose/>
- **GitHub:** <https://github.com/block/goose>
- **Documentation:** <https://block.github.io/goose/docs/>
- **Discord:** <https://discord.gg/goose-oss>
