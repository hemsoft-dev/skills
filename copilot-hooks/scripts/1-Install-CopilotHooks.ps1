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
#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [int]$MaxFollowUpCommits = 5,
    [string]$CommitPrefix = 'chore(session): auto-followup',
    [switch]$SkipPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Managed by copilot-hooks skill

if ($env:AGENT_SESSION_HOOK_RUNNING -eq '1') {
    exit 0
}

$env:AGENT_SESSION_HOOK_RUNNING = '1'

function Write-Info([string]$Message) {
    Write-Host "[agent-session-hook] $Message"
}

function Get-StatusPorcelain {
    return (git status --porcelain)
}

function Get-StagedFiles {
    return (git diff --cached --name-only)
}

function Invoke-GitAdd {
    $addOutput = @(& git add -A 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed.`n$($addOutput -join [Environment]::NewLine)"
    }
}

function Invoke-GitCommitFaultTolerant([string]$Message) {
    $commitOutput = @(& git commit -m $Message 2>&1)
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-Info 'git commit failed (likely hook/lint checks). Retrying with --no-verify.'
    $retryOutput = @(& git commit --no-verify -m $Message 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git commit failed (normal + --no-verify).`nFirst:`n$($commitOutput -join [Environment]::NewLine)`nRetry:`n$($retryOutput -join [Environment]::NewLine)"
    }
}

function Invoke-GitPushWithRebaseRetry {
    $pushOutput = @(& git push 2>&1)
    if ($LASTEXITCODE -eq 0) {
        return
    }

    $pushText = ($pushOutput -join [Environment]::NewLine)
    $isNonFastForward = $pushText -match 'non-fast-forward|failed to push some refs|Updates were rejected'
    if (-not $isNonFastForward) {
        throw "git push failed.`n$pushText"
    }

    Write-Info "Push rejected (non-fast-forward). Running 'git pull --rebase' then retrying push."
    $pullOutput = @(& git pull --rebase 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git pull --rebase failed.`n$($pullOutput -join [Environment]::NewLine)"
    }

    $retryOutput = @(& git push 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git push retry failed after rebase.`n$($retryOutput -join [Environment]::NewLine)"
    }
}

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    throw 'Not inside a Git repository.'
}

Write-Info "Running in $repoRoot"

for ($i = 1; $i -le $MaxFollowUpCommits; $i++) {
    $status = Get-StatusPorcelain
    if (-not $status) {
        break
    }

    Write-Info "Detected uncommitted changes. Follow-up pass $i/$MaxFollowUpCommits."
    Invoke-GitAdd

    $staged = Get-StagedFiles
    if (-not $staged) {
        break
    }

    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $message = "$CommitPrefix ($stamp)"
    Invoke-GitCommitFaultTolerant -Message $message
}

$remaining = Get-StatusPorcelain
if ($remaining) {
    throw "Repository is still dirty after $MaxFollowUpCommits follow-up commit attempts."
}

if (-not $SkipPush) {
    Invoke-GitPushWithRebaseRetry
}

Write-Info 'Completed successfully.'
'@

$stopHookConfig = @'
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "windows": "pwsh -NoProfile -ExecutionPolicy Bypass -File ./.github/hooks/Invoke-AgentSessionAutoPush.ps1",
        "timeout": 120
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
$stopScriptPath = Join-Path $copilotHooksDir 'Invoke-AgentSessionAutoPush.ps1'
Set-Content -Path $stopScriptPath -Value $stopAutoPushScript -Encoding utf8NoBOM
Write-Ok "Installed: $stopScriptPath"

$hooksJsonPath = Join-Path $copilotHooksDir 'hooks.json'
if (-not (Test-Path $hooksJsonPath)) {
    Set-Content -Path $hooksJsonPath -Value $stopHookConfig -Encoding utf8NoBOM
    Write-Ok "Created: $hooksJsonPath"
} else {
    try {
        $hooksObj = Get-Content -Path $hooksJsonPath -Raw | ConvertFrom-Json
        if ($null -eq $hooksObj.hooks) {
            $hooksObj | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{})
        }
        if ($null -eq $hooksObj.hooks.Stop) {
            $hooksObj.hooks | Add-Member -MemberType NoteProperty -Name Stop -Value @()
        }

        $existingStop = @($hooksObj.hooks.Stop)
        $targetCmd = './.github/hooks/Invoke-AgentSessionAutoPush.ps1'
        $hasEntry = $false
        foreach ($entry in $existingStop) {
            $w = "$($entry.windows)"
            $c = "$($entry.command)"
            if ($w -match 'Invoke-AgentSessionAutoPush\.ps1' -or $c -match 'Invoke-AgentSessionAutoPush\.ps1') {
                $hasEntry = $true
                break
            }
        }

        if (-not $hasEntry) {
            $newEntry = [pscustomobject]@{
                type = 'command'
                windows = 'pwsh -NoProfile -ExecutionPolicy Bypass -File ./.github/hooks/Invoke-AgentSessionAutoPush.ps1'
                timeout = 120
            }
            $hooksObj.hooks.Stop = @($newEntry) + $existingStop
            $hooksObj | ConvertTo-Json -Depth 10 | Set-Content -Path $hooksJsonPath -Encoding utf8NoBOM
            Write-Ok "Updated Stop hook in: $hooksJsonPath"
        } else {
            Write-Warn "Stop hook already references Invoke-AgentSessionAutoPush.ps1"
        }
    } catch {
        $fallbackPath = Join-Path $copilotHooksDir 'session-stop-autopush.json'
        Set-Content -Path $fallbackPath -Value $stopHookConfig -Encoding utf8NoBOM
        Write-Warn "Could not parse hooks.json. Wrote fallback profile: $fallbackPath"
    }
}

if (-not (Test-Path $markdownConfigPath)) {
    Set-Content -Path $markdownConfigPath -Value $starterMarkdownlintConfig -Encoding utf8NoBOM
    Write-Ok "Created starter config: $markdownConfigPath"
} else {
    Write-Warn "Existing markdownlint config kept: $markdownConfigPath"
}

Write-Ok "Install complete"
