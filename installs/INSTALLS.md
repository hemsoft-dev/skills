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
scoop install cloc ffmpeg
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
### 8.5. .NET SDK (Latest)

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

### 8.6. Docker Desktop

```powershell
winget install --id Docker.DockerDesktop -e --source winget
```

**Note:** Requires Windows Subsystem for Linux 2 (WSL2). Docker Desktop will prompt to install/enable WSL2 if not already configured.

Verify (after restart):

```powershell
docker --version
docker-compose --version
```

### 9. Claude Code

```powershell
# Install Claude Code globally (requires Node.js)
npm install -g @anthropic-ai/claude-code
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

If not available via winget, download from: https://www.wispr.com/flow

### 18. Directory Opus

Download from: https://www.gpsoft.com.au/

```powershell
Start-Process "https://www.gpsoft.com.au/DScripts/download.asp"
```

Requires license key after installation.

### 19. Corsair iCUE (Xeneon Edge Display)

Control software for Corsair Xeneon Edge 14.5" LCD Touchscreen and other Corsair peripherals.

```powershell
winget install --id Corsair.iCUE.5 -e --source winget
```

If not available via winget, download from: https://www.corsair.com/us/en/s/downloads

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
    "OpenJS.NodeJS.LTS",
    "Python.Python.3.12",
    "Docker.DockerDesktop",
    "Obsidian.Obsidian",
    "Discord.Discord",
    "VideoLAN.VLC",
    "Audacity.Audacity",
    "Valve.Steam",
    "AutoHotkey.AutoHotkey",
    "Corsair.iCUE.5",
    "AlDanial.Cloc"
)

foreach ($app in $apps) {
    Write-Host "Installing $app..." -ForegroundColor Cyan
    winget install --id $app -e --source winget --accept-package-agreements --accept-source-agreements
}

Write-Host "All winget apps installed!" -ForegroundColor Green
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
