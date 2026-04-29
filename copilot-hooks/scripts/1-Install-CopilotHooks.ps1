#!/usr/bin/env pwsh
param(
    [Parameter()]
    [string]$RepoPath = '.',

    [Parameter()]
    [switch]$SkipPreCommit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Err([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Get-ActiveHooksPath {
    param([string]$RepoRoot)

    $configured = (git -C $RepoRoot config --get core.hooksPath 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($configured)) {
        return '.git/hooks'
    }

    return $configured.Trim()
}

function Get-RepoRoot {
    param([string]$Path)

    $resolved = Resolve-Path -Path $Path -ErrorAction Stop
    $candidate = $resolved.Path

    if (Test-Path -Path (Join-Path $candidate '.git')) {
        return $candidate
    }

    $gitTop = git -C $candidate rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitTop) {
        return $gitTop.Trim()
    }

    throw "Path '$candidate' is not inside a git repository."
}

$repoRoot = Get-RepoRoot -Path $RepoPath
$hooksDir = Join-Path $repoRoot '.git/hooks'
New-Item -Path $hooksDir -ItemType Directory -Force | Out-Null

$activeHooksPath = Get-ActiveHooksPath -RepoRoot $repoRoot
Write-Info "Detected active hooks path: $activeHooksPath"

# ─────────────────────────────────────────────────────────────────────────────
# Copilot CLI hooks (postToolUse, userPromptSubmitted, sessionEnd)
# ─────────────────────────────────────────────────────────────────────────────

$copilotHooksDir = Join-Path $repoRoot '.github/hooks'
New-Item -Path $copilotHooksDir -ItemType Directory -Force | Out-Null

$logsDir = Join-Path $repoRoot 'logs'
New-Item -Path $logsDir -ItemType Directory -Force | Out-Null

# --- hooks.json (the master config) ---
$hooksJsonContent = @'
{
  "version": 1,
  "hooks": {
    "userPromptSubmitted": [
      {
        "type": "command",
        "powershell": "powershell -NoProfile -ExecutionPolicy Bypass -File ./.github/hooks/Log-Prompt.ps1",
        "bash": "bash ./.github/hooks/log-prompt.sh",
        "timeoutSec": 5
      }
    ],
    "postToolUse": [
      {
        "type": "command",
        "powershell": "powershell -NoProfile -ExecutionPolicy Bypass -File ./.github/hooks/play-done.ps1",
        "bash": "bash ./.github/hooks/play-done.sh",
        "timeoutSec": 5
      }
    ],
    "sessionEnd": [
      {
        "type": "command",
        "powershell": "sh ./.github/hooks/auto-commit.sh",
        "bash": ".github/hooks/auto-commit.sh",
        "timeoutSec": 10
      }
    ]
  }
}
'@

# --- play-done.ps1 (audio on task_complete) ---
$playDonePs1Content = @'
# Managed by copilot-hooks skill
# Audio notification for postToolUse hook.
# Plays done.mp3 immediately when the tool is task_complete (turn is over).
$debugLog = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\logs\hook-debug.log'))
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'

# Read stdin for tool metadata
$toolName = '(unknown)'
$raw = try { [Console]::In.ReadToEnd() } catch { '' }
if ($raw) {
    try {
        $json = $raw | ConvertFrom-Json
        if ($json.toolName) { $toolName = $json.toolName }
        elseif ($json.tool) { $toolName = $json.tool }
        elseif ($json.name) { $toolName = $json.name }
    } catch { }
}

Add-Content $debugLog "[$ts] postToolUse [$toolName] fired"

# Only play audio on task_complete
if ($toolName -ne 'task_complete') { exit 0 }

$audioEnabled = $true
$settingsPath = '.github/hooks/hooks-settings.json'
if (Test-Path $settingsPath) {
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($null -ne $settings.audioEnabled) { $audioEnabled = $settings.audioEnabled }
    } catch { }
}
if (-not $audioEnabled) {
    Add-Content $debugLog "[$ts] task_complete but audio disabled - skipping"
    exit 0
}

$audioFile = (Resolve-Path '.github/hooks/done.mp3').Path
Add-Content $debugLog "[$ts] ── AUDIO PLAYING ── task_complete detected"
Start-Process -NoNewWindow -FilePath 'ffplay' -ArgumentList '-nodisp','-autoexit','-volume','50','-loglevel','quiet',$audioFile
'@

# --- play-done.sh (audio on task_complete - bash) ---
$playDoneShContent = @'
#!/bin/bash
# Managed by copilot-hooks skill
# Audio notification for postToolUse hook.
# Plays done.mp3 immediately when the tool is task_complete (turn is over).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEBUG_LOG="$SCRIPT_DIR/../../logs/hook-debug.log"
TS=$(date '+%Y-%m-%d %H:%M:%S.%3N')

# Read stdin for tool metadata
RAW=$(cat 2>/dev/null || echo '')
TOOL_NAME="(unknown)"
if [ -n "$RAW" ] && command -v jq &>/dev/null; then
    TOOL_NAME=$(echo "$RAW" | jq -r '.toolName // .tool // .name // "(unknown)"' 2>/dev/null)
fi

echo "[$TS] postToolUse [$TOOL_NAME] fired" >> "$DEBUG_LOG"

# Only play audio on task_complete
[ "$TOOL_NAME" != "task_complete" ] && exit 0

SETTINGS=".github/hooks/hooks-settings.json"
AUDIO_ENABLED=true
if [ -f "$SETTINGS" ]; then
    AUDIO_ENABLED=$(jq -r '.audioEnabled // true' "$SETTINGS")
fi
if [ "$AUDIO_ENABLED" != "true" ]; then
    echo "[$TS] task_complete but audio disabled - skipping" >> "$DEBUG_LOG"
    exit 0
fi

AUDIO_FILE="$(pwd)/.github/hooks/done.mp3"
echo "[$TS] ── AUDIO PLAYING ── task_complete detected" >> "$DEBUG_LOG"
ffplay -nodisp -autoexit -volume 50 -loglevel quiet "$AUDIO_FILE" &>/dev/null &
'@

# --- Log-Prompt.ps1 (prompt logging) ---
$logPromptPs1Content = @'
# Managed by copilot-hooks skill
# Log-Prompt.ps1 - Captures the actual prompt text from UserPromptSubmit stdin JSON
$debugLog = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\logs\hook-debug.log'))
$raw = try { [Console]::In.ReadToEnd() } catch { '' }

$prompt = 'N/A'
if ($raw) {
    try {
        $json = $raw | ConvertFrom-Json
        $prompt = if ($json.prompt) { $json.prompt }
                  elseif ($json.userPrompt) { $json.userPrompt }
                  elseif ($json.content) { $json.content }
                  else { $raw }
    } catch {
        $prompt = $raw
    }
}

# Normalize whitespace and truncate to keep logs manageable
$prompt = ($prompt -replace '[\r\n]+', ' ').Trim()
if ($prompt.Length -gt 300) { $prompt = $prompt.Substring(0, 300) + '...' }

$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'

# Log to hook-debug.log (marks the start of a turn)
Add-Content $debugLog "[$ts] ── TURN START ── userPromptSubmitted: $prompt"

# Also log to session log
$dir = 'logs/session'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$logFile = Join-Path $dir ((Get-Date -Format 'yyyy-MM-dd') + '.log')
Add-Content -Path $logFile -Value ('[{0}] [UserPrompt] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $prompt)
'@

# --- log-prompt.sh (prompt logging - bash) ---
$logPromptShContent = @'
#!/bin/bash
# Managed by copilot-hooks skill
# log-prompt.sh - Captures the actual prompt text from UserPromptSubmit stdin JSON
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEBUG_LOG="$SCRIPT_DIR/../../logs/hook-debug.log"

raw=$(cat 2>/dev/null || echo '')
if command -v jq &>/dev/null; then
    prompt=$(echo "$raw" | jq -r '.prompt // .userPrompt // .content // .' 2>/dev/null)
else
    prompt="$raw"
fi
prompt=$(echo "$prompt" | tr '\n' ' ' | cut -c1-300)

TS=$(date '+%Y-%m-%d %H:%M:%S.%3N')

# Log to hook-debug.log (marks the start of a turn)
echo "[$TS] ── TURN START ── userPromptSubmitted: $prompt" >> "$DEBUG_LOG"

# Also log to session log
dir="logs/session"
mkdir -p "$dir"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UserPrompt] $prompt" >> "$dir/$(date '+%Y-%m-%d').log"
'@

# --- auto-commit.sh (session-end auto-commit) ---
$autoCommitShContent = @'
#!/bin/sh
# Managed by copilot-hooks skill

LOCK_ROOT="${TMPDIR:-${TEMP:-/tmp}}"
LOCK_FILE="$LOCK_ROOT/copilot-session-hook-$(git rev-parse --show-toplevel 2>/dev/null | tr '/:\\' '_' | tr -cd '[:alnum:]_-').lock"

if [ -f "$LOCK_FILE" ]; then
    NOW=$(date +%s 2>/dev/null || echo 0)
    LAST=$(cat "$LOCK_FILE" 2>/dev/null || echo 0)
    if [ "$NOW" -gt 0 ] && [ "$LAST" -gt 0 ] && [ $((NOW - LAST)) -lt 30 ]; then
        echo "Auto-commit skipped (duplicate hook invocation)"
        exit 0
    fi
fi

date +%s 2>/dev/null > "$LOCK_FILE" || true

if [ "$SKIP_AUTO_COMMIT" = "true" ]; then
    echo "Auto-commit skipped (SKIP_AUTO_COMMIT=true)"
    exit 0
fi

export GIT_TERMINAL_PROMPT=0
export GCM_INTERACTIVE=Never

if [ -z "$GIT_ASKPASS" ]; then
    export GIT_ASKPASS=echo
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not in a git repository"
    exit 0
fi

if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    echo "No changes to commit"
    exit 0
fi

echo "Auto-committing changes from Copilot session..."

if ! git add -A >/dev/null 2>&1; then
    echo "Staging failed"
    exit 0
fi

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
if ! git commit -m "auto-commit: $TIMESTAMP" --no-verify >/dev/null 2>&1; then
    echo "Commit failed"
    exit 0
fi

BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
REMOTE=$(git remote | head -n 1)

if [ -z "$REMOTE" ]; then
    echo "No remote configured - changes committed locally"
    exit 0
fi

if [ -z "$BRANCH" ]; then
    echo "Detached HEAD - changes committed locally"
    exit 0
fi

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    PUSH_CMD="git push"
else
    PUSH_CMD="git push --set-upstream $REMOTE $BRANCH"
fi

if GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=5}" sh -c "$PUSH_CMD" >/dev/null 2>&1; then
    echo "Changes committed and pushed successfully"
else
    echo "Push failed fast - changes committed locally"
fi

exit 0
'@

# --- hooks-settings.json (optional config) ---
$hooksSettingsContent = @'
{
  "audioEnabled": true
}
'@

# ─────────────────────────────────────────────────────────────────────────────
# Install Copilot CLI hooks
# ─────────────────────────────────────────────────────────────────────────────

$hooksJsonPath = Join-Path $copilotHooksDir 'hooks.json'
$playDonePs1Path = Join-Path $copilotHooksDir 'play-done.ps1'
$playDoneShPath = Join-Path $copilotHooksDir 'play-done.sh'
$logPromptPs1Path = Join-Path $copilotHooksDir 'Log-Prompt.ps1'
$logPromptShPath = Join-Path $copilotHooksDir 'log-prompt.sh'
$autoCommitShPath = Join-Path $copilotHooksDir 'auto-commit.sh'
$hooksSettingsPath = Join-Path $copilotHooksDir 'hooks-settings.json'
$audioFilePath = Join-Path $copilotHooksDir 'done.mp3'

# Only write hooks.json if it doesn't exist (preserve user customizations)
if (-not (Test-Path $hooksJsonPath)) {
    Set-Content -Path $hooksJsonPath -Value $hooksJsonContent -Encoding utf8NoBOM
    Write-Ok "Installed: $hooksJsonPath"
} else {
    Write-Warn "Existing hooks.json preserved: $hooksJsonPath"
    Write-Info "  If you want a fresh config, delete it and re-run install."
}

Set-Content -Path $playDonePs1Path -Value $playDonePs1Content -Encoding utf8NoBOM
Write-Ok "Installed: $playDonePs1Path"

Set-Content -Path $playDoneShPath -Value $playDoneShContent -Encoding utf8NoBOM
Write-Ok "Installed: $playDoneShPath"

Set-Content -Path $logPromptPs1Path -Value $logPromptPs1Content -Encoding utf8NoBOM
Write-Ok "Installed: $logPromptPs1Path"

Set-Content -Path $logPromptShPath -Value $logPromptShContent -Encoding utf8NoBOM
Write-Ok "Installed: $logPromptShPath"

Set-Content -Path $autoCommitShPath -Value $autoCommitShContent -Encoding utf8NoBOM
Write-Ok "Installed: $autoCommitShPath"

if (-not (Test-Path $hooksSettingsPath)) {
    Set-Content -Path $hooksSettingsPath -Value $hooksSettingsContent -Encoding utf8NoBOM
    Write-Ok "Installed: $hooksSettingsPath"
} else {
    Write-Warn "Existing hooks-settings.json preserved: $hooksSettingsPath"
}

if (-not (Test-Path $audioFilePath)) {
    Write-Warn "Audio file missing: $audioFilePath"
    Write-Info "  Place a done.mp3 (notification sound) at .github/hooks/done.mp3"
    Write-Info "  Without it, the postToolUse hook will error silently on task_complete."
}

# Ensure logs/ is in .gitignore
$gitignorePath = Join-Path $repoRoot '.gitignore'
if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content -Path $gitignorePath -Raw
    if ($gitignoreContent -notmatch '(?m)^logs/?$') {
        Add-Content -Path $gitignorePath -Value "`nlogs/"
        Write-Ok "Added logs/ to .gitignore"
    }
} else {
    Set-Content -Path $gitignorePath -Value "logs/`n" -Encoding utf8NoBOM
    Write-Ok "Created .gitignore with logs/ entry"
}

# ─────────────────────────────────────────────────────────────────────────────
# Legacy cleanup (remove old skill artifacts)
# ─────────────────────────────────────────────────────────────────────────────

# Remove old .github/scripts/auto-commit.sh location
$legacyScriptsDir = Join-Path $repoRoot '.github/scripts'
$legacyAutoCommitPath = Join-Path $legacyScriptsDir 'auto-commit.sh'
if (Test-Path $legacyAutoCommitPath) {
    $legacyText = Get-Content -Path $legacyAutoCommitPath -Raw
    if ($legacyText -match 'Managed by copilot-hooks skill') {
        Remove-Item -Path $legacyAutoCommitPath -Force
        Write-Ok "Removed legacy script: $legacyAutoCommitPath"
    }
}

$legacyStandalonePath = Join-Path $copilotHooksDir 'session-stop-autopush.json'
if (Test-Path $legacyStandalonePath) {
    Remove-Item -Path $legacyStandalonePath -Force
    Write-Ok "Removed legacy standalone hook profile: $legacyStandalonePath"
}

$legacyStopScriptPath = Join-Path $copilotHooksDir 'Invoke-AgentSessionAutoPush.ps1'
if (Test-Path $legacyStopScriptPath) {
    Remove-Item -Path $legacyStopScriptPath -Force
    Write-Ok "Removed legacy managed script: $legacyStopScriptPath"
}

$legacyManagedCopilotDir = Join-Path $repoRoot 'copilot/scripts'
$legacyManagedCopilotScript = Join-Path $legacyManagedCopilotDir 'Invoke-AgentSessionAutoPush.ps1'
if (Test-Path $legacyManagedCopilotScript) {
    Remove-Item -Path $legacyManagedCopilotScript -Force
    Write-Ok "Removed legacy managed script: $legacyManagedCopilotScript"
}

# ─────────────────────────────────────────────────────────────────────────────
# Pre-commit hooks (optional)
# ─────────────────────────────────────────────────────────────────────────────

if ($SkipPreCommit) {
    Write-Info "Skipping pre-commit markdown linting installation (-SkipPreCommit)"
    Write-Ok "Install complete"
    exit 0
}

$preCommitPath = Join-Path $hooksDir 'pre-commit'
$preCommitMarkdownPath = Join-Path $hooksDir 'pre-commit-markdown.ps1'
$markdownConfigPath = Join-Path $repoRoot '.markdownlint.jsonc'

$preCommitContent = @'
#!/bin/sh
# Managed by copilot-hooks skill
# Windows Git hook wrapper - calls PowerShell and Markdown quality checks

POWERSHELL_EXIT=0
if [ -f ".git/hooks/pre-commit.ps1" ]; then
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ".git/hooks/pre-commit.ps1"
  POWERSHELL_EXIT=$?
fi

pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ".git/hooks/pre-commit-markdown.ps1"
MARKDOWN_EXIT=$?

if [ $POWERSHELL_EXIT -ne 0 ] || [ $MARKDOWN_EXIT -ne 0 ]; then
  exit 1
fi

exit 0
'@

$preCommitMarkdownContent = @'
#!/usr/bin/env pwsh
# Managed by copilot-hooks skill
# Git pre-commit hook that enforces Markdown quality standards.
# Runs markdownlint-cli2 on staged Markdown files.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Success([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }
function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }

Write-Info "Running Markdown quality checks..."

$markdownlintInstalled = $null -ne (Get-Command markdownlint-cli2 -ErrorAction SilentlyContinue)
if (-not $markdownlintInstalled) {
    Write-Fail "markdownlint-cli2 is not installed."
    Write-Info "Install it with: npm install -g markdownlint-cli2"
    exit 1
}

$stagedFiles = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -match '\.md$' }
if (-not $stagedFiles) {
    Write-Success "No Markdown files staged for commit"
    exit 0
}

$repoRoot = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Could not determine repository root"
    exit 1
}

if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    $repoRoot = $repoRoot -replace '/', '\\'
}

$configPath = Join-Path $repoRoot '.markdownlint.jsonc'
if (-not (Test-Path $configPath)) {
    Write-Fail "Missing markdownlint config at $configPath"
    Write-Info "Run copilot-hooks install again to create a starter config."
    exit 1
}

$hasErrors = $false
foreach ($file in $stagedFiles) {
    $filePath = Join-Path $repoRoot $file
    if (-not (Test-Path $filePath)) {
        continue
    }

    Write-Info "Checking: $file"
    $output = markdownlint-cli2 --config $configPath $filePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $hasErrors = $true
        Write-Fail "Issues found in ${file}:"
        Write-Host $output -ForegroundColor Gray
    }
}

if ($hasErrors) {
    Write-Fail "COMMIT BLOCKED: Markdown linting failed"
    Write-Info "Auto-fix many issues with: markdownlint-cli2 --fix \"**/*.md\""
    exit 1
}

Write-Success "All Markdown files passed quality checks"
exit 0
'@

$huskyMarkdownBlock = @'
# copilot-hooks:begin markdown gate
# Block commits on markdownlint violations for staged .md files
if [ -f ".git/hooks/pre-commit-markdown.ps1" ]; then
  pwsh -NoProfile -ExecutionPolicy Bypass -File ".git/hooks/pre-commit-markdown.ps1"
else
  echo "Missing .git/hooks/pre-commit-markdown.ps1. Reinstall copilot-hooks."
  exit 1
fi
# copilot-hooks:end markdown gate
'@

$starterMarkdownlintConfig = @'
// Managed by copilot-hooks skill
{
  "$schema": "https://json.schemastore.org/markdownlint-cli2.json",
  "config": {
    "default": true,
    "MD013": false,
    "MD033": false,
    "MD041": false
  }
}
'@

Set-Content -Path $preCommitPath -Value $preCommitContent -Encoding utf8NoBOM
Set-Content -Path $preCommitMarkdownPath -Value $preCommitMarkdownContent -Encoding utf8NoBOM
Write-Ok "Installed: $preCommitPath"
Write-Ok "Installed: $preCommitMarkdownPath"

if ($activeHooksPath -eq '.husky/_') {
    $huskyPreCommitPath = Join-Path $repoRoot '.husky/pre-commit'
    if (Test-Path $huskyPreCommitPath) {
        $huskyContent = Get-Content -Path $huskyPreCommitPath -Raw
        if ($huskyContent -notmatch 'copilot-hooks:begin markdown gate') {
            $newHuskyContent = $huskyContent.TrimEnd() + "`r`n`r`n" + $huskyMarkdownBlock + "`r`n"
            Set-Content -Path $huskyPreCommitPath -Value $newHuskyContent -Encoding utf8NoBOM
            Write-Ok "Updated Husky pre-commit: $huskyPreCommitPath"
        } else {
            Write-Warn "Husky markdown gate already present: $huskyPreCommitPath"
        }
    } else {
        Write-Warn "Active hooks path is Husky, but .husky/pre-commit was not found."
    }
}

if (-not (Test-Path $markdownConfigPath)) {
    Set-Content -Path $markdownConfigPath -Value $starterMarkdownlintConfig -Encoding utf8NoBOM
    Write-Ok "Created starter config: $markdownConfigPath"
} else {
    Write-Warn "Existing markdownlint config kept: $markdownConfigPath"
}

Write-Ok "Install complete"
