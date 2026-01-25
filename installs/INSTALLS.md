# Windows Installation Steps

## Package Managers

**Strategy:** Use winget for mainstream apps, Scoop for dev tools and fonts.

Scoop adds only **1 PATH entry** (`~/scoop/shims`), keeping PATH minimal.

### Install Scoop

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Add nerd-fonts bucket for developer fonts
scoop bucket add nerd-fonts
```

### Install Dev Fonts

```powershell
scoop install JetBrains-Mono GeistMono-NF Victor-Mono Iosevka-NF
```

### Install Dev Tools

```powershell
scoop install cloc ffmpeg btop
```

**Installed tools:**

- `cloc` - Count Lines of Code
- `ffmpeg` - Media processing
- `btop` - Beautiful CLI system monitor (btop4win)

### Install Python Packages

```powershell
# docling - Document processing and parsing for gen AI
pip install docling

# uv - Fast Python package manager (recommended for LangFlow)
pipx install uv
```

### Install LangFlow (venv-based)

LangFlow requires a dedicated virtual environment due to its large dependency tree (591 packages).

```powershell
# Create dedicated directory and venv
$langflowDir = "$env:USERPROFILE\.langflow"
New-Item -ItemType Directory -Path $langflowDir -Force | Out-Null
Set-Location $langflowDir
uv venv .venv --python 3.12

# Activate and install
.\.venv\Scripts\Activate.ps1
uv pip install langflow -U
deactivate
```

**Run LangFlow:**

```powershell
# Option 1: Use the launcher script
& "$env:USERPROFILE\.langflow\Start-LangFlow.ps1"

# Option 2: Manual activation
Set-Location "$env:USERPROFILE\.langflow"
.\.venv\Scripts\Activate.ps1
langflow run
# Opens at http://127.0.0.1:7860
```

**Installed fonts:**

- JetBrains Mono - Clean, modern, highly readable
- GeistMono NF - Vercel's font with Nerd Font icons
- Victor Mono - Elegant cursive italics
- Iosevka NF - Narrow, space-efficient

## Installation Order

Execute in this order to ensure dependencies are met:

### 1. Edge Browser Configuration

```powershell
# Edge is pre-installed on Windows 11
Start-Process "msedge://settings/profiles/sync"
```

1. Sign in with `franz_hemmer@hotmail.com`
2. Enable sync for: Bookmarks, Extensions, Settings, Passwords
3. Wait for sync to complete

### 2. VS Code Insiders

```powershell
winget install --id Microsoft.VisualStudioCode.Insiders -e --source winget
```

#### Restore Settings

```powershell
$skillPath = "$env:USERPROFILE\.claude\skills\windows-install\vscode-insiders"
$vscodeUserPath = "$env:APPDATA\Code - Insiders\User"

# Copy settings.json
Copy-Item -Path "$skillPath\settings.json" -Destination $vscodeUserPath -Force

# Install extensions
Get-Content "$skillPath\extensions.txt" | ForEach-Object {
    if ($_.Trim()) { code-insiders --install-extension $_ }
}
```

### 3. LastPass Edge Extension

```powershell
Start-Process "https://microsoftedge.microsoft.com/addons/detail/lastpass-free-password-ma/bbcinlkgjjkejfdpemiealijmmooekmp"
```

Click "Get" → "Add extension" → Sign in to LastPass

### 4. OneDrive Configuration

```powershell
# OneDrive is pre-installed, launch setup
Start-Process "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
```

1. Sign in with Microsoft account
2. Choose folders to sync (ensure `F:\OneDrive` is the location if available)
3. Enable Files On-Demand

### 5. Git

```powershell
winget install --id Git.Git -e --source winget
```

Configure after install:

```powershell
git config --global user.name "Franz Hemmer"
git config --global user.email "franz_hemmer@hotmail.com"
git config --global init.defaultBranch main
git config --global core.autocrlf true
```

### 6. GitHub CLI

```powershell
winget install --id GitHub.cli -e --source winget
```

Authenticate to HemSoft account:

```powershell
gh auth login
# Select: GitHub.com → HTTPS → Login with web browser
# Authenticate as franz_hemmer@hotmail.com (HemSoft account)
```

Verify:

```powershell
gh auth status
```

### 7. Bun

```powershell
powershell -c "irm bun.sh/install.ps1 | iex"
```

Verify:

```powershell
bun --version
```

**Note:** Restart terminal after installation for PATH to update.

### 8. Node.js (npm/npx)

```powershell
winget install --id OpenJS.NodeJS.LTS -e --source winget
```

Verify:

```powershell
node --version
npm --version
npx --version
```

**Note:** Restart terminal after installation for PATH to update.

### 8.3. Python 3.12

`powershell
winget install --id Python.Python.3.12 -e --source winget
`

**Note:** After install, disable Windows Store Python aliases in Settings > Apps > App execution aliases to prevent conflicts.

#### Install edge-tts (Text-to-Speech)

`powershell
C:\Users\User\AppData\Local\Programs\Python\Python312\python.exe -m pip install edge-tts
`

Creates a speak-clipboard script for AutoHotkey TTS shortcut (CTRL+ALT+P).

### 8.5. Ollama

```powershell
winget install --id Ollama.Ollama -e --source winget
```

Verify:

```powershell
ollama --version
```

### 8.6. .NET SDK (Latest)

The official dotnet-install script installs to user directory (no admin required) and supports any version/channel.

```powershell
# Download and run installer for LTS channel
Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile "$env:TEMP\dotnet-install.ps1"
& "$env:TEMP\dotnet-install.ps1" -Channel LTS
```

**Install location:** `$env:USERPROFILE\AppData\Local\Microsoft\dotnet`

#### Add to PowerShell Profile

The installer only adds to current session PATH. Add to profile for persistence:

```powershell
@"

##---------------------------------------
## PATH Additions
##---------------------------------------
# .NET SDK (installed via dotnet-install.ps1)
`$dotnetPath = "`$env:USERPROFILE\AppData\Local\Microsoft\dotnet"
if ((Test-Path `$dotnetPath) -and (`$env:PATH -notlike "*`$dotnetPath*")) {
    `$env:PATH = "`$dotnetPath;`$env:PATH"
}
"@ | Add-Content -Path $PROFILE
```

Verify (after restarting terminal):

```powershell
dotnet --version
```

**Channel options:** `LTS`, `STS`, `10.0`, `9.0`, `8.0`, etc.

### 8.7. Docker Desktop

```powershell
winget install --id Docker.DockerDesktop -e --source winget
```

**Note:** Requires Windows Subsystem for Linux 2 (WSL2). Docker Desktop will prompt to
install/enable WSL2 if not already configured.

Verify (after restart):

```powershell
docker --version
docker-compose --version
```

#### Neo4j (Docker)

Run Neo4j graph database in a local Docker container.

```powershell
# Pull Neo4j image
docker pull neo4j:latest

# Run Neo4j container
docker run -d `
  --name neo4j `
  -p 7474:7474 -p 7687:7687 `
  -e NEO4J_AUTH=neo4j/password `
  -v neo4j_data:/data `
  -v neo4j_logs:/logs `
  neo4j:latest
```

**Access Neo4j Browser:**

- URL: <http://localhost:7474>
- Username: `neo4j`
- Password: `password` (change on first login)

**Connection details:**

- Bolt protocol: `bolt://localhost:7687`
- HTTP: `http://localhost:7474`

**Useful commands:**

```powershell
# Stop Neo4j
docker stop neo4j

# Start Neo4j
docker start neo4j

# View logs
docker logs neo4j

# Remove container (preserves data volume)
docker rm neo4j

# Remove data volume (WARNING: deletes all data)
docker volume rm neo4j_data neo4j_logs
```

### 9. Claude Code

```powershell
# Install Claude Code globally (requires Node.js)
npm install -g @anthropic-ai/claude-code
```

### 9.5. Gemini CLI

```powershell
# Install Gemini CLI globally (requires Node.js)
npm install -g @google/gemini-cli
```

Verify:

```powershell
gemini --version
```

### 10. Clone HemSoft Repos

#### Skills Repository

```powershell
cd $env:USERPROFILE
gh repo clone HemSoft/skills

# Copy skills to Claude skills directory
Copy-Item -Path "$env:USERPROFILE\skills\*" -Destination "$env:USERPROFILE\.claude\skills\" -Recurse -Force
```

#### Agents Repository

```powershell
cd $env:USERPROFILE
gh repo clone HemSoft/agents

# Copy agents to VSCode Insiders global chat agents directory
$agentsPath = "$env:APPDATA\Code - Insiders\User\globalStorage\github.copilot-chat\agents"
New-Item -ItemType Directory -Path $agentsPath -Force
Copy-Item -Path "$env:USERPROFILE\agents\*.agent.md" -Destination $agentsPath -Force
```

**Note**: VSCode Insiders global agents location:
`%APPDATA%\Code - Insiders\User\globalStorage\github.copilot-chat\agents\`

### 11. Obsidian

```powershell
winget install --id Obsidian.Obsidian -e --source winget
```

After install, open Obsidian and configure vault location (typically synced via OneDrive).

### 12. Discord

```powershell
winget install --id Discord.Discord -e --source winget
```

### 13. VLC Media Player

```powershell
winget install --id VideoLAN.VLC -e --source winget
```

### 13.5. Audacity

```powershell
winget install --id Audacity.Audacity -e --source winget
```

### 14. Todoist (Edge App)

```powershell
Start-Process "msedge" -ArgumentList "--app=https://app.todoist.com"
```

Then in Edge: `...` menu → Apps → Install Todoist

### 15. Steam

```powershell
winget install --id Valve.Steam -e --source winget
```

### 16. AutoHotkey

```powershell
winget install --id AutoHotkey.AutoHotkey -e --source winget
```

#### Install Startup Script

```powershell
# Copy the bundled AutoHotkey script to Documents
$skillPath = "$env:USERPROFILE\.claude\skills\windows-install\autohotkey"
Copy-Item -Path "$skillPath\AutoHotkey.ahk" -Destination "$env:USERPROFILE\Documents\AutoHotkey.ahk" -Force

# Create startup shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\AutoHotkey.lnk")
$Shortcut.TargetPath = "$env:USERPROFILE\Documents\AutoHotkey.ahk"
$Shortcut.Save()

# Launch script now
Start-Process "$env:USERPROFILE\Documents\AutoHotkey.ahk"
```

### 17. Wispr Flow

```powershell
winget install --id Wispr.Flow -e --source winget
```

If not available via winget, download from: <https://www.wispr.com/flow>

### 18. Directory Opus

Download from: <https://www.gpsoft.com.au/>

```powershell
Start-Process "https://www.gpsoft.com.au/DScripts/download.asp"
```

Requires license key after installation.

### 19. Corsair iCUE (Xeneon Edge Display)

Control software for Corsair Xeneon Edge 14.5" LCD Touchscreen and other Corsair peripherals.

```powershell
winget install --id Corsair.iCUE.5 -e --source winget
```

If not available via winget, download from: <https://www.corsair.com/us/en/s/downloads>

### 20. OpenCode

Open source code editor and IDE.

```powershell
winget install --id SST.opencode -e --source winget
```

### 21. Microsoft 365

Microsoft 365 subscription suite (formerly Office 365) including Word, Excel, PowerPoint, Outlook, and more.

**Recommended:** Install directly from Microsoft (winget often has hash mismatch issues):

- Web: <https://www.office.com/setup>
- Direct: <https://www.microsoft.com/microsoft-365/get-started-with-office-365>

**Alternative (winget):** May fail with hash mismatch error - use web installer instead:

```powershell
winget install --id Microsoft.Office -e --source winget
```

After installation, sign in with your Microsoft account to activate your subscription.

### 22. GitHub Copilot CLI

AI-powered coding assistant that runs directly in your terminal.

```powershell
npm install -g @github/copilot
```

**Verify installation:**

```powershell
copilot --version
```

**Features:**

- Interactive AI coding sessions
- Non-interactive prompt execution
- Multiple AI models (Claude, GPT, Gemini)
- Built-in MCP server support
- Session persistence and resumption
- Permission management for tools, paths, and URLs

**Basic usage:**

```powershell
# Interactive mode
copilot

# Quick prompt
copilot -p "Generate password validator function" --silent

# With auto-approval
copilot --allow-all
```

### 23. Codex CLI

OpenAI's open-source coding agent built in Rust that allows developers to read, change, and run code directly from the terminal.

```powershell
npm install -g @openai/codex
```

**Verify installation:**

```powershell
codex --version
```

**Features:**

- Interactive terminal-based coding agent
- Read, modify, and execute code from terminal
- Uses OpenAI models (requires ChatGPT Plus/Pro/Business/Enterprise or API key)
- Experimental Windows support with sandboxed filesystem access

**Initial setup:**

After installation, launch Codex and authenticate:

```powershell
# Launch interactive mode
codex

# Authenticate via browser (for ChatGPT plans)
# OR set API key environment variable:
$env:OPENAI_API_KEY="your-api-key-here"
```

**Note:** Native Windows support is experimental. For best performance, consider using WSL2.

**Xeneon Edge 14.5" Specs:**

- 2560x720 resolution (32:9 ultrawide), 60Hz, 5-point touchscreen
- USB-C DP-Alt Mode and HDMI 2.0 inputs
- Magnetic mount for desktop, case, or metal surfaces

**iCUE Features:**

- Custom widget layouts and system metrics display
- Virtual Stream Deck integration
- RGB lighting sync across Corsair devices
- iCUE Murals for immersive lighting effects

## Quick Install Script

Run all winget installations at once:

```powershell
$apps = @(
    "Git.Git",
    "GitHub.cli",
    "Microsoft.VisualStudioCode.Insiders",
    "Microsoft.Office",
    "OpenJS.NodeJS.LTS",
    "Python.Python.3.12",
    "Ollama.Ollama",
    "Docker.DockerDesktop",
    "Obsidian.Obsidian",
    "Discord.Discord",
    "VideoLAN.VLC",
    "Audacity.Audacity",
    "Valve.Steam",
    "AutoHotkey.AutoHotkey",
    "Corsair.iCUE.5",
    "AlDanial.Cloc",
    "SST.opencode"
)

foreach ($app in $apps) {
    Write-Host "Installing $app..." -ForegroundColor Cyan
    winget install --id $app -e --source winget --accept-package-agreements --accept-source-agreements
}

# Install Python packages
Write-Host "Installing Python packages..." -ForegroundColor Cyan
pip install docling
pipx install uv

# Install LangFlow in dedicated venv
Write-Host "Installing LangFlow..." -ForegroundColor Cyan
$langflowDir = "$env:USERPROFILE\.langflow"
New-Item -ItemType Directory -Path $langflowDir -Force | Out-Null
Push-Location $langflowDir
uv venv .venv --python 3.12
.\.venv\Scripts\Activate.ps1
uv pip install langflow -U
deactivate
Pop-Location

# Install npm packages
Write-Host "Installing npm packages..." -ForegroundColor Cyan
npm install -g @github/copilot
npm install -g @openai/codex

Write-Host "All apps installed!" -ForegroundColor Green
```

## Troubleshooting

### winget not found

```powershell
Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
```

### GitHub CLI authentication fails

```powershell
gh auth login --web
```

### AutoHotkey script won't start

1. Verify AutoHotkey v2 is installed
2. Check script syntax with: `C:\Program Files\AutoHotkey\v2\AutoHotkey.exe "$env:USERPROFILE\Documents\AutoHotkey.ahk"`
3. Run as administrator if needed

### Microsoft Office winget hash mismatch

If `winget install --id Microsoft.Office` fails with "Installer hash does not match", use the web installer instead:

- <https://www.office.com/setup>
