#!/usr/bin/env pwsh
param(
    [Parameter()]
    [string]$RepoPath = '.'
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

$stopAutoPushScript = @'
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

$stopHookConfig = @'
{
    "version": 1,
    "hooks": {
        "agentStop": [
            {
                "type": "command",
                "windows": "sh ./.github/scripts/auto-commit.sh",
                "bash": ".github/scripts/auto-commit.sh",
                "timeoutSec": 10
            }
        ],
        "sessionEnd": [
            {
                "type": "command",
                "windows": "sh ./.github/scripts/auto-commit.sh",
                "bash": ".github/scripts/auto-commit.sh",
                "timeoutSec": 10
            }
        ]
    }
}
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

$copilotHooksDir = Join-Path $repoRoot '.github/hooks'
New-Item -Path $copilotHooksDir -ItemType Directory -Force | Out-Null
$githubScriptsDir = Join-Path $repoRoot '.github/scripts'
New-Item -Path $githubScriptsDir -ItemType Directory -Force | Out-Null

$stopScriptPath = Join-Path $githubScriptsDir 'auto-commit.sh'
Set-Content -Path $stopScriptPath -Value $stopAutoPushScript -Encoding utf8NoBOM
Write-Ok "Installed: $stopScriptPath"

$hooksJsonPath = Join-Path $copilotHooksDir 'hooks.json'
Set-Content -Path $hooksJsonPath -Value $stopHookConfig -Encoding utf8NoBOM
Write-Ok "Installed: $hooksJsonPath"

$legacyStandalonePath = Join-Path $copilotHooksDir 'session-stop-autopush.json'
if (Test-Path $legacyStandalonePath) {
    Remove-Item -Path $legacyStandalonePath -Force
    Write-Ok "Removed legacy standalone hook profile: $legacyStandalonePath"
}

$legacyManagedCopilotDir = Join-Path $repoRoot 'copilot/scripts'
$legacyManagedCopilotScript = Join-Path $legacyManagedCopilotDir 'Invoke-AgentSessionAutoPush.ps1'
if (Test-Path $legacyManagedCopilotScript) {
    $legacyManagedText = Get-Content -Path $legacyManagedCopilotScript -Raw
    if ($legacyManagedText -match 'Managed by copilot-hooks skill') {
        Remove-Item -Path $legacyManagedCopilotScript -Force
        Write-Ok "Removed legacy managed script: $legacyManagedCopilotScript"
    }
    else {
        Write-Warn "Kept existing unmanaged legacy script: $legacyManagedCopilotScript"
    }
}

if (Test-Path $hooksJsonPath) {
    try {
        $hooksObj = Get-Content -Path $hooksJsonPath -Raw | ConvertFrom-Json
        if ($null -eq $hooksObj.version) {
            $hooksObj | Add-Member -MemberType NoteProperty -Name version -Value 1 -Force
        }
        if ($null -eq $hooksObj.hooks) {
            $hooksObj | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{}) -Force
        }
        $removedLegacyProperty = $false
        if ($null -ne $hooksObj.hooks.PSObject.Properties['Stop']) {
            $hooksObj.hooks.PSObject.Properties.Remove('Stop')
            $removedLegacyProperty = $true
        }
        if ($removedLegacyProperty) {
            $hooksObj | ConvertTo-Json -Depth 10 | Set-Content -Path $hooksJsonPath -Encoding utf8NoBOM
            Write-Ok "Removed legacy Stop event from: $hooksJsonPath"
        }
    }
    catch {
        Write-Warn "Could not parse hooks.json for legacy cleanup: $hooksJsonPath"
    }
}

$legacyStopScriptPath = Join-Path $copilotHooksDir 'Invoke-AgentSessionAutoPush.ps1'
if (Test-Path $legacyStopScriptPath) {
    $legacyScriptText = Get-Content -Path $legacyStopScriptPath -Raw
    if ($legacyScriptText -match 'Managed by copilot-hooks skill') {
        Remove-Item -Path $legacyStopScriptPath -Force
        Write-Ok "Removed legacy managed script: $legacyStopScriptPath"
    }
    else {
        Write-Warn "Kept existing unmanaged legacy script: $legacyStopScriptPath"
    }
}

if (-not (Test-Path $markdownConfigPath)) {
    Set-Content -Path $markdownConfigPath -Value $starterMarkdownlintConfig -Encoding utf8NoBOM
    Write-Ok "Created starter config: $markdownConfigPath"
} else {
    Write-Warn "Existing markdownlint config kept: $markdownConfigPath"
}

Write-Ok "Install complete"
