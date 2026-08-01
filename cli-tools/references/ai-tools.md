# AI Tools

Read this file only for tools in the AI or AI review categories.

## gemini - Gemini CLI

| Field | Value |
|---|---|
| Author | Google |
| Current version | 0.27.0-preview.0, verified 2026-01-27 |
| Purpose | Interactive and one-shot access to Google Gemini coding models. |
| Authentication | Browser OAuth on first use. |

```powershell
npm install --global @google/gemini-cli
npm install --global @google/gemini-cli@latest
gemini --version
npm view @google/gemini-cli version
npm list --global @google/gemini-cli --depth=0

gemini
gemini "Explain this repository"
gemini --model gemini-2.5-flash "Explain this repository"
```

- npm: <https://www.npmjs.com/package/@google/gemini-cli>
- GitHub: <https://github.com/google-gemini/gemini-cli>
- Documentation: <https://geminicli.com>
- Releases: <https://github.com/google-gemini/gemini-cli/releases>

Gemini CLI has no built-in updater. Use npm for stable releases; preview releases use the `next` distribution tag.

## claude - Claude Code

| Field | Value |
|---|---|
| Author | Anthropic |
| Current version | 2.1.12, verified 2026-01-19 |
| Purpose | Interactive coding agent for terminal-based development workflows. |
| Authentication | Anthropic account or supported API configuration. |

```powershell
# Install with npm; the native installer is also available from the official site
npm install --global @anthropic-ai/claude-code

# Update and verify
claude update
claude --version
npm view @anthropic-ai/claude-code version

# Start
claude
```

- Website: <https://claude.ai/download>
- Documentation: <https://docs.anthropic.com/en/docs/claude-code/overview>

## copilot - GitHub Copilot CLI

| Field | Value |
|---|---|
| Author | GitHub |
| Current version | 0.0.384, verified 2026-01-19 |
| Purpose | Interactive and one-shot coding agent with multiple model choices. |
| Authentication | GitHub authentication and an eligible Copilot plan or allowance. |

```powershell
npm install --global @github/copilot
npm update --global @github/copilot
copilot --version
npm view @github/copilot version

copilot
copilot -p "Explain this repository"
copilot --continue
```

- npm: <https://www.npmjs.com/package/@github/copilot>
- GitHub: <https://github.com/github/copilot-cli>
- Documentation: <https://docs.github.com/en/copilot/github-copilot-in-the-cli>

Use the dedicated `copilot` skill for detailed model, billing, and helper-function guidance.

## codex - Codex CLI

| Field | Value |
|---|---|
| Author | OpenAI |
| Current version | 0.87.0, verified 2026-01-19 |
| Purpose | Open-source coding agent for reading, editing, and running code from a terminal. |
| Authentication | ChatGPT subscription login or OpenAI API key. |

```powershell
npm install --global @openai/codex
npm update --global @openai/codex
codex --version
npm view @openai/codex version

codex
```

- npm: <https://www.npmjs.com/package/@openai/codex>
- GitHub: <https://github.com/openai/codex>
- Documentation: <https://developers.openai.com/codex/cli/>

Windows support is experimental; WSL2 is recommended by the project for the broadest compatibility.

## greptile - Greptile CLI

| Field | Value |
|---|---|
| Author | Greptile |
| Current version | 3.3.1, verified 2026-08-01 |
| Purpose | Review the current local branch against a selected base branch. |
| Requirements | Node.js 22 or newer, a Git repository, and Greptile authentication. |

```powershell
# Install, update, and verify
npm install --global greptile
greptile update
greptile --version
npm view greptile version
npm list --global greptile --depth=0

# Authenticate
greptile login
greptile login --api-key

# Review
greptile review
greptile review --branch main
greptile review --diff
greptile review --json
greptile review --agent

# Inspect configuration and disable telemetry
greptile whoami
greptile config
greptile settings set telemetry false
```

- Official CLI page: <https://www.greptile.com/cli>
- npm: <https://www.npmjs.com/package/greptile>
- GitHub: <https://github.com/greptileai/cli>
- Changelog: <https://www.greptile.com/changelog>

Use `greptile onboard` for interactive account and repository setup. Never place an API key directly in shell
history; `greptile login --api-key` reads it from a secure prompt or standard input.

## goose - Goose CLI

| Field | Value |
|---|---|
| Author | Block |
| Current version | 1.21.2, verified 2026-01-27 |
| Purpose | Rust-based coding agent supporting local Ollama and multiple cloud providers through extensions. |
| Authentication | Depends on the configured model provider. |

### Install

```powershell
# Official Windows installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/block/goose/main/download_cli.ps1" `
    -OutFile "$env:TEMP\goose_install.ps1" -UseBasicParsing
& "$env:TEMP\goose_install.ps1"

# Scoop alternative
scoop bucket add extras
scoop install goose
```

```bash
# macOS
brew install --cask block-goose
```

### Update on Windows

The built-in `goose update` requires a working WSL installation on Windows. If it fails, download the current
`goose-x86_64-pc-windows-gnu.zip` release and replace the files in `%USERPROFILE%\.local\bin`.

```powershell
goose --version
goose configure
goose session start
goose run --text "Explain this repository"
```

- Website: <https://block.github.io/goose/>
- GitHub: <https://github.com/block/goose>
- Documentation: <https://block.github.io/goose/docs/>
- Releases: <https://github.com/block/goose/releases>

Use tool-capable models when enabling Goose extensions.
