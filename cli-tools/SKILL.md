---
name: cli-tools
description: V1.8 - Reference guide for CLI tools including installation, updates, version tracking, and usage with release notes reporting. Updated with Windows-specific update quirks.
metadata:
  author: HemSoft Developments
  version: "1.7"
---

# CLI Tools

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Reference guide for command-line tools used in development workflows.

Track tool categories, current versions, and where to check for updates.

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

## Updating Tools with Release Notes

When asked to update one or more CLI tools:

1. **Execute the update** using the tool's update command
2. **Verify the new version** by running the version check command
3. **Fetch release notes** from the tool's GitHub releases or changelog
4. **Present a summary** including:
   - Previous version → New version
   - Significant changes, features, or fixes
   - Breaking changes or important notes (if any)
   - Link to full release notes

### Release Notes Sources

- **GitHub releases**: Use `gh release view {tag}` or WebSearch
- **npm packages**: Check package registry or GitHub repo
- **Other sources**: Use WebSearch with "{tool} release notes {version}"

### Example Update Report Format

```markdown
✅ **{Tool Name} Updated**

**Version:** {old_version} → {new_version}

**Key Changes:**
- Feature/fix 1
- Feature/fix 2
- Breaking change (if any)

**Full Release Notes:** {URL}
```

## Available Tools

### prs - Pull Request Checker

**Category:** Development Tools

**Description:** Unified CLI tool for checking pull requests across GitHub and Bitbucket repositories.

**Author:** HemSoft Developments (Franz Hemmer)

**Current Version:** 0.1.5 (as of 2026-01-19)

**Installation:**

```bash
npm install -g @hemsoft/prs
```

**Update:**

```bash
npm update -g @hemsoft/prs
```

**Version Check:**

```bash
# Check installed version
prs --version

# Check latest available version
npm view @hemsoft/prs version
```

**Links:**

- npm: <https://www.npmjs.com/package/@hemsoft/prs>
- GitHub: <https://github.com/HemSoft/prs>

**Usage:**

Use `prs` to check pull request status across multiple repositories. Particularly useful for checking both GitHub and Bitbucket PRs in a unified way.

---

### edit - Microsoft Edit Text Editor

**Category:** Text Editors

**Description:** Lightweight, open-source command-line text editor from Microsoft written in Rust. Provides a modeless UI with menus, mouse support, multiple file tabs, find & replace with regex support, and word wrap.

**Author:** Microsoft

**Current Version:** 1.2.1 (as of 2026-01-19)

**Installation:**

```powershell
winget install Microsoft.Edit
```

**Update:**

```powershell
winget upgrade Microsoft.Edit
```

**Version Check:**

```bash
# Check installed version
edit --version

# Check latest available version
winget show Microsoft.Edit

# Or check GitHub releases
# https://github.com/microsoft/edit/releases
```

**Links:**

- GitHub: <https://github.com/microsoft/edit>
- Docs: <https://learn.microsoft.com/en-us/windows/edit/>

**Usage:**

```bash
# Open editor
edit

# Open a specific file
edit filename.txt

# Check version
edit --version
```

**Note:** Pre-installed on Windows 11 Build 26200+ (including your current build 26200). If not available, install via winget or download from GitHub releases.

---

### glow - Glow Markdown Viewer/Editor

**Category:** Text Editors

**Description:** Lightweight CLI tool written in Go that renders Markdown files directly in the terminal with stylish formatting and syntax highlighting. Works with both local and remote Markdown files, useful for previewing documentation and README files.

**Author:** Charm (charmbracelet)

**Current Version:** 2.1.1 (as of 2026-01-28)

**Installation:**

Windows (Scoop):

```powershell
scoop install glow
```

Alternative (winget):

```powershell
winget install charmbracelet.Glow
```

**Update:**

```powershell
# Scoop
scoop update glow

# winget
winget upgrade charmbracelet.Glow
```

**Version Check:**

```bash
# Check installed version
glow --version

# Check latest available version
# Visit: https://github.com/charmbracelet/glow/releases
```

**Links:**

- GitHub: <https://github.com/charmbracelet/glow>
- Releases: <https://github.com/charmbracelet/glow/releases>

**Usage:**

```bash
# View a local markdown file
glow README.md

# View a remote markdown file
glow github.com/charmbracelet/glow

# Edit mode (if supported)
glow -p filename.md

# Check version
glow --version
```

**Note:** Excellent tool for viewing and editing Markdown files in the terminal with beautiful formatting. Supports both local files and remote URLs.

---

### nano - GNU Nano Text Editor

**Category:** Text Editors

**Description:** Simple, user-friendly command-line text editor. Excellent CLI editing tool with intuitive keyboard shortcuts and a clean interface. Perfect for quick edits and terminal-based file editing.

**Author:** GNU Project

**Current Version:** (version check needed - as of 2026-01-28)

**Installation:**

Windows (winget):

```powershell
winget install GNU.Nano
```

Alternative (Chocolatey):

```powershell
choco install nano -y
```

**Update:**

```powershell
# winget
winget upgrade GNU.Nano

# Chocolatey
choco upgrade nano -y
```

**Version Check:**

```bash
# Check installed version
nano --version

# Check latest available version
# Visit: https://www.nano-editor.org/download.php
```

**Links:**

- Official Site: <https://www.nano-editor.org>
- Windows Port: <https://github.com/lhmouse/nano-win>

**Usage:**

```bash
# Open/create a file
nano filename.txt

# Edit existing file
nano README.md

# Essential shortcuts:
# Ctrl+O - Save
# Ctrl+X - Exit
# Ctrl+K - Cut line
# Ctrl+U - Paste
# Ctrl+W - Search
# Ctrl+G - Help
```

**Note:** Excellent CLI editing tool. Simple and intuitive interface perfect for terminal-based editing. Essential keyboard shortcuts displayed at bottom of screen.

---

### gemini - Gemini CLI

**Category:** AI

**Description:** Command-line interface for Google Gemini AI. Provides interactive chat sessions and one-shot prompts with support for multiple models (gemini-2.5-pro, gemini-2.5-flash, gemini-3-pro).

**Author:** Google

**Current Version:** 0.27.0-preview.0 (as of 2026-01-27)

**Installation:**

```bash
npm install -g @google/gemini-cli
```

**Update:**

```bash
# Update to latest stable
npm update -g @google/gemini-cli

# Force latest version
npm install -g @google/gemini-cli@latest
```

**⚠️ Update Notes:**

- ❌ **NO auto-update command** (unlike Bun's `bun upgrade`)
- ❌ **NOT available in Scoop** or other Windows package managers
- ✅ npm is the ONLY official distribution method
- Requires manual `npm update` checks

**Version Check:**

```bash
# Check installed version
gemini --version

# Check latest available version
npm view @google/gemini-cli version

# List installed package details
npm list -g @google/gemini-cli
```

**Links:**

- npm: <https://www.npmjs.com/package/@google/gemini-cli>
- GitHub: <https://github.com/google-gemini/gemini-cli>
- Releases: <https://github.com/google-gemini/gemini-cli/releases>
- Docs: <https://geminicli.com>

**Usage:**

```bash
# Interactive mode
gemini

# One-shot prompt
gemini "Your prompt here"

# Specify model
gemini --model gemini-2.5-flash "Your prompt here"

# Check version
gemini --version
```

**Note:** First run prompts OAuth login via browser. Credentials are cached for future use. Uses free tier by default (see gemini skill for billing details). Preview releases available via `npm install -g @google/gemini-cli@latest --tag next`.

---

### claude - Claude Code

**Category:** AI

**Description:** Command-line interface for Claude AI by Anthropic. Provides direct access to Claude models for code generation, assistance, and AI-powered development workflows.

**Author:** Anthropic

**Current Version:** 2.1.12 (as of 2026-01-19)

**Installation:**

Download and install from <https://claude.ai/download>

Alternatively, install via npm:

```bash
npm install -g @anthropic-ai/claude-code
```

**Update:**

```bash
# Check for updates (built-in command)
claude update

# Or reinstall via npm
npm update -g @anthropic-ai/claude-code
```

**Version Check:**

```bash
# Check installed version
claude --version

# Check latest available version
npm view @anthropic-ai/claude-code version

# Or check website
# https://claude.ai/download
```

**Links:**

- Website: <https://claude.ai>
- Docs: <https://docs.anthropic.com>

**Usage:**

```bash
# Run Claude Code
claude

# Check version
claude --version

# Update to latest
claude update
```

**Note:** Uses Pro subscription token for usage.

---

### copilot - GitHub Copilot CLI

**Category:** AI

**Description:** AI-powered coding assistant for terminal with interactive development workflows, command execution, and multi-model support (Claude, GPT, Gemini). Supports both interactive sessions and one-shot prompts.

**Author:** GitHub (Microsoft)

**Current Version:** 0.0.384 (as of 2026-01-19)

**Installation:**

```bash
npm install -g @github/copilot
```

**Update:**

```bash
npm update -g @github/copilot
```

**Version Check:**

```bash
# Check installed version
copilot --version

# Check latest available version
npm view @github/copilot version
```

**Links:**

- npm: <https://www.npmjs.com/package/@github/copilot>
- GitHub: <https://github.com/github/copilot-cli>
- Docs: <https://docs.github.com/en/copilot/github-copilot-in-the-cli>

**Usage:**

```bash
# Interactive mode
copilot

# One-shot prompt
copilot -p "Your prompt here"

# With auto-approval and specific model
copilot -p "Generate function" --allow-all --model claude-sonnet-4.5

# Quick free-tier prompts (via PowerShell helper function)
copilot-free "Your prompt here"

# Resume previous session
copilot --continue

# Check version
copilot --version
```

**Note:** Requires GitHub authentication (`gh auth login`). Supports multiple AI models including Claude Sonnet 4.5, GPT-5, and Gemini 3 Pro. See copilot skill for detailed usage and helper functions.

---

### codex - Codex CLI

**Category:** AI

**Description:** OpenAI's open-source coding agent built in Rust that runs in the terminal. Capable of reading, editing, and running code locally with interactive terminal-based workflows.

**Author:** OpenAI

**Current Version:** 0.87.0 (as of 2026-01-19)

**Installation:**

```bash
npm install -g @openai/codex
```

**Update:**

```bash
npm update -g @openai/codex
```

**Version Check:**

```bash
# Check installed version
codex --version

# Check latest available version
npm view @openai/codex version
```

**Links:**

- npm: <https://www.npmjs.com/package/@openai/codex>
- GitHub: <https://github.com/openai/codex>
- Docs: <https://developers.openai.com/codex/cli/>

**Usage:**

```bash
# Interactive mode (first run prompts authentication)
codex

# Check version
codex --version
```

**Note:** Requires ChatGPT Plus/Pro/Business/Enterprise subscription or OpenAI API key. First run prompts browser-based authentication. By default, requires working directory to be a Git repository. Windows support is experimental (recommended to use WSL2). Written in Rust for performance and security.

---

### goose - Goose CLI

**Category:** AI

**Description:** AI agent by Block (Square) written in Rust. Supports local Ollama models and cloud providers (Anthropic, OpenAI, GitHub Copilot). Features MCP extensions, web search via Tavily, and built-in skills support for Claude skills integration.

**Author:** Block (Square)

**Current Version:** 1.21.2 (as of 2026-01-27)

**Installation:**

Windows (PowerShell):

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/block/goose/main/download_cli.ps1" -OutFile "$env:TEMP\goose_install.ps1" -UseBasicParsing
& "$env:TEMP\goose_install.ps1"
```

macOS (Homebrew):

```bash
brew install --cask block-goose
```

Alternative (Scoop):

```powershell
scoop bucket add extras
scoop install goose
```

**Update:**

```bash
# macOS/Linux (native)
goose update
```

```powershell
# Windows (manual - WSL issues)
$version = "v1.21.2"  # Check releases for latest
Invoke-WebRequest -Uri "https://github.com/block/goose/releases/download/$version/goose-x86_64-pc-windows-gnu.zip" -OutFile "$env:TEMP\goose.zip"
Expand-Archive -Path "$env:TEMP\goose.zip" -DestinationPath "$env:TEMP\goose" -Force
Copy-Item "$env:TEMP\goose\goose-package\*" -Destination "$env:USERPROFILE\.local\bin\" -Force
Remove-Item "$env:TEMP\goose.zip","$env:TEMP\goose" -Recurse -Force
goose --version
```

**⚠️ Windows Update Issue:**

- `goose update` requires WSL (Windows Subsystem for Linux)
- Fails with `CreateProcessCommon:800: execvpe(/bin/bash) failed` if WSL broken
- **Workaround:** Manual download from GitHub releases (see command above)
- Asset name: `goose-x86_64-pc-windows-gnu.zip`
- Contains `goose-package/` subdirectory with `goose.exe` + DLL dependencies

**Version Check:**

```bash
# Check installed version
goose --version

# Check latest available version
# Visit: https://github.com/block/goose/releases
```

**Links:**

- Official Site: <https://block.github.io/goose/>
- GitHub: <https://github.com/block/goose>
- Docs: <https://block.github.io/goose/docs/>
- Releases: <https://github.com/block/goose/releases>

**Usage:**

```bash
# Configure provider (first time)
goose configure

# Interactive session with skills support
goose session start

# Run single prompt with skills
goose run --text "Your prompt here"

# Use specific model
goose run --model claude-haiku-4.5 --text "Your prompt"

# Get help
goose --help
```

**Note:** Written in Rust (NOT Python). Supports Ollama for local models, cloud providers (Anthropic, OpenAI, GitHub Copilot), and MCP extensions. Requires tool-capable models for extensions (e.g., qwen3, llama3.1). See goose skill for detailed configuration and PowerShell wrapper setup.

---

### btop - btop4win System Monitor

**Category:** System Monitoring

**Description:** Beautiful CLI system resource monitor showing usage and stats for CPU, memory, disks, network, processes, and services. Native Windows port of btop++ with game-inspired menu system, full mouse support, and customizable themes.

**Author:** aristocratos

**Current Version:** 1.0.5 (as of 2026-01-20)

**Installation:**

```powershell
scoop install btop
```

For full hardware monitoring (GPU, CPU temps) with LibreHardwareMonitor:

```powershell
scoop install btop-lhm
```

**Update:**

```powershell
scoop update btop
```

**Version Check:**

```bash
# Check installed version
btop --version

# Check latest available version
scoop info btop
```

**Links:**

- GitHub: <https://github.com/aristocratos/btop4win>
- Scoop: <https://scoop.sh/#/apps?q=btop>

**Usage:**

```bash
# Launch btop monitor
btop

# Check version
btop --version
```

**Note:** Requires Windows 10 version 1607+ for ANSI escape sequences. Windows Terminal recommended for best experience. Basic version (btop) doesn't require admin rights but is recommended for full process information. LHM version (btop-lhm) requires admin rights for GPU and temperature monitoring.

---

## Adding New Tools

When adding a new CLI tool to this skill, gather and include ALL of the following metadata:

### Required Fields

1. **Category** - Classify the tool (AI, Development Tools, Text Editors, etc.)
2. **Description** - Brief description of what the tool does
3. **Author** - Who created/maintains the tool
4. **Current Version** - Latest known version with date verified
5. **Installation** - Complete installation command(s)
6. **Update** - How to update the tool
7. **Version Check** - Commands to check both installed and latest available versions
8. **Links** - Documentation, repository, package registry links
9. **Usage** - Basic usage examples
10. **Notes** - Any important details (authentication, pricing, prerequisites)

### Version Tracking

Always include:

- Current version number
- Date version was verified (YYYY-MM-DD format)
- Command to check installed version
- Command/URL to check latest available version

### Example Template

```markdown
### tool-name - Tool Display Name

**Category:** {AI | Development Tools | Text Editors | etc.}

**Description:** {What it does and key features}

**Author:** {Author/Organization}

**Current Version:** {X.Y.Z} (as of YYYY-MM-DD)

**Installation:**

{Installation commands}

**Update:**

{Update commands}

**Version Check:**

{Commands to check installed and latest versions}

**Links:**

- {Primary documentation/website}
- {GitHub/repository}
- {Package registry if applicable}

**Usage:**

{Basic usage examples}

**Note:** {Important details}
```
