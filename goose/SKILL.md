---
name: goose
description: V1.3 - Use a CLI AI tool called Goose to execute the prompt. Supports local Ollama models and cloud providers with MCP extensions. Includes Windows update workarounds.
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

## Updating Goose

### On Windows (Important!)

**⚠️ Known Issue:** The built-in `goose update` command requires WSL (Windows Subsystem for Linux) and will fail if WSL is broken or not configured properly with the error:

```
WSL ERROR: CreateProcessCommon:800: execvpe(/bin/bash) failed: No such file or directory
```

**Workaround - Manual Update (Recommended):**

```powershell
# Download and install latest version manually
$version = "v1.21.2"  # Check https://github.com/block/goose/releases for latest
Invoke-WebRequest -Uri "https://github.com/block/goose/releases/download/$version/goose-x86_64-pc-windows-gnu.zip" -OutFile "$env:TEMP\goose.zip"
Expand-Archive -Path "$env:TEMP\goose.zip" -DestinationPath "$env:TEMP\goose" -Force
Copy-Item "$env:TEMP\goose\goose-package\*" -Destination "$env:USERPROFILE\.local\bin\" -Force
Remove-Item "$env:TEMP\goose.zip","$env:TEMP\goose" -Recurse -Force
goose --version
```

**Alternative - Fix WSL:**

If you want `goose update` to work natively, ensure WSL is properly installed and configured:

```powershell
wsl --install
wsl --set-default-version 2
```

### On macOS/Linux

```bash
goose update
```

Works natively without issues.

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

## Provider Configuration

**Config Location:** `%APPDATA%\Block\goose\config\config.yaml`

### Available Providers

| Provider | Config Name | Notes |
|----------|-------------|-------|
| GitHub Copilot | `github_copilot` | Use underscore, NOT hyphen |
| Ollama (local) | `ollama` | Requires local Ollama installation |
| OpenAI | `openai` | Requires API key |
| Anthropic | `anthropic` | Requires API key |
| Amazon Bedrock | `amazon_bedrock` | AWS credentials required |

**IMPORTANT:** Provider names use underscores (e.g., `github_copilot`), not hyphens.

### Configure via CLI

```powershell
goose configure
```

Select provider from interactive menu and follow prompts.

## Web Search (Tavily Extension)

**CRITICAL:** Web search requires the Tavily MCP extension. Setting `TAVILY_API_KEY` alone does NOT enable web search.

### Config with Tavily Web Search

```yaml
GOOSE_PROVIDER: ollama
GOOSE_MODEL: qwen3:14b
extensions:
  tavily:
    name: Tavily Web Search
    cmd: npx
    args: ["-y", "tavily-mcp"]
    enabled: true
    envs:
      TAVILY_API_KEY: "{your-tavily-api-key}"
    type: stdio
    timeout: 300
  developer:
    bundled: true
    enabled: true
```

### Tavily API Key

Get key from: <https://tavily.com>

Environment variable: `WebSearch__ApiKey` or `TAVILY_API_KEY`

## Ollama Integration

For local LLM execution with Ollama:

1. **Install Ollama:** `winget install Ollama.Ollama`
2. **Pull a tool-capable model:** `ollama pull qwen3:14b`
3. **Configure Goose:** Set provider to `ollama`

### Tool-Calling Requirement

**CRITICAL:** The Ollama model MUST support tool/function calling for extensions to work.

**Models WITH tool support:** qwen3, qwen2.5, hermes3, llama3.1, mistral-nemo

**Models WITHOUT tool support:** nemotron-3-nano (will NOT call extensions)

See the `ollama` skill for detailed model recommendations.

## Adding Extensions

Extensions are MCP servers that add capabilities to Goose.

### Via Config File

```yaml
extensions:
  {extension-id}:
    name: {Display Name}
    cmd: npx
    args: ["-y", "{npm-package}"]
    enabled: true
    envs:
      {ENV_VAR}: "{value}"
    type: stdio
    timeout: 300
```

### Via CLI (Session Only)

```powershell
goose session --with-extension "npx -y {npm-package}"
```

### Extension Directory

Browse available extensions: <https://block.github.io/goose/extensions>

## Resources

- **Official Site:** <https://block.github.io/goose/>
- **GitHub:** <https://github.com/block/goose>
- **Documentation:** <https://block.github.io/goose/docs/>
- **Discord:** <https://discord.gg/goose-oss>
