#!/usr/bin/env pwsh
param(
    [Parameter()]
    [string]$RepoPath = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Err([string]$Message) { Write-Host $Message -ForegroundColor Red }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }

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
$activeHooksPath = Get-ActiveHooksPath -RepoRoot $repoRoot
$hooksDir = Join-Path $repoRoot '.git/hooks'
$preCommitPath = Join-Path $hooksDir 'pre-commit'
$preCommitMarkdownPath = Join-Path $hooksDir 'pre-commit-markdown.ps1'
$markdownConfigPath = Join-Path $repoRoot '.markdownlint.jsonc'
$huskyPreCommitPath = Join-Path $repoRoot '.husky/pre-commit'
$copilotHookJsonPath = Join-Path $repoRoot '.github/hooks/hooks.json'
$copilotAutoCommitScriptPath = Join-Path $repoRoot '.github/scripts/auto-commit.sh'
$legacyStandaloneJsonPath = Join-Path $repoRoot '.github/hooks/session-stop-autopush.json'
$legacyStopScriptPath = Join-Path $repoRoot '.github/hooks/Invoke-AgentSessionAutoPush.ps1'
$legacyManagedCopilotScriptPath = Join-Path $repoRoot 'copilot/scripts/Invoke-AgentSessionAutoPush.ps1'

Write-Warn "Detected active hooks path: $activeHooksPath"

$checks = @(
    [pscustomobject]@{ Name = 'pre-commit exists'; Pass = (Test-Path $preCommitPath) },
    [pscustomobject]@{ Name = 'pre-commit-markdown exists'; Pass = (Test-Path $preCommitMarkdownPath) },
    [pscustomobject]@{ Name = '.markdownlint.jsonc exists'; Pass = (Test-Path $markdownConfigPath) },
    [pscustomobject]@{ Name = 'Copilot auto-commit shell script exists'; Pass = (Test-Path $copilotAutoCommitScriptPath) }
)

if (Test-Path $preCommitPath) {
    $preCommitText = Get-Content -Path $preCommitPath -Raw
    $callsMarkdownHook = $preCommitText -match 'pre-commit-markdown\.ps1'
    $checks += [pscustomobject]@{ Name = 'pre-commit calls markdown hook'; Pass = $callsMarkdownHook }
}

if (Test-Path $preCommitMarkdownPath) {
    $psHookText = Get-Content -Path $preCommitMarkdownPath -Raw
    $usesMarkdownlint = $psHookText -match 'markdownlint-cli2'
    $usesSafeVarInterpolation = $psHookText -match 'Issues found in \$\{file\}:'
    $checks += [pscustomobject]@{ Name = 'markdown hook uses markdownlint-cli2'; Pass = $usesMarkdownlint }
    $checks += [pscustomobject]@{ Name = 'markdown hook avoids $file: parser bug'; Pass = $usesSafeVarInterpolation }
}

if (Test-Path $copilotAutoCommitScriptPath) {
    $stopHookText = Get-Content -Path $copilotAutoCommitScriptPath -Raw
    $stagesBeforeBlocking = $stopHookText -match 'git add -A'
    $autoCommitsChanges = $stopHookText -match 'git commit -m'
    $usesTimestampedAutoCommit = $stopHookText -match 'auto-commit:'
    $usesNoVerify = $stopHookText -match '--no-verify'
    $attemptsPush = $stopHookText -match 'git push'
    $disablesTerminalPrompt = $stopHookText -match 'GIT_TERMINAL_PROMPT=0'
    $disablesGcmPrompt = $stopHookText -match 'GCM_INTERACTIVE=Never'
    $usesFastSsh = $stopHookText -match 'BatchMode=yes' -and $stopHookText -match 'ConnectTimeout=5'
    $checks += [pscustomobject]@{ Name = 'sessionEnd hook stages remaining changes'; Pass = $stagesBeforeBlocking }
    $checks += [pscustomobject]@{ Name = 'sessionEnd hook auto-commits staged changes'; Pass = $autoCommitsChanges }
    $checks += [pscustomobject]@{ Name = 'sessionEnd hook uses timestamped auto-commit message'; Pass = $usesTimestampedAutoCommit }
    $checks += [pscustomobject]@{ Name = 'sessionEnd hook bypasses pre-commit with --no-verify'; Pass = $usesNoVerify }
    $checks += [pscustomobject]@{ Name = 'sessionEnd hook attempts to push committed changes'; Pass = $attemptsPush }
    $checks += [pscustomobject]@{ Name = 'sessionEnd hook disables terminal git prompts'; Pass = $disablesTerminalPrompt }
    $checks += [pscustomobject]@{ Name = 'sessionEnd hook disables interactive Git Credential Manager prompts'; Pass = $disablesGcmPrompt }
    $checks += [pscustomobject]@{ Name = 'sessionEnd hook uses fast-fail SSH options'; Pass = $usesFastSsh }
}

if ($activeHooksPath -eq '.husky/_') {
    $hasHuskyBlock = $false
    if (Test-Path $huskyPreCommitPath) {
        $huskyText = Get-Content -Path $huskyPreCommitPath -Raw
        $hasHuskyBlock = ($huskyText -match 'copilot-hooks:begin markdown gate')
    }

    $checks += [pscustomobject]@{ Name = 'Husky pre-commit contains copilot markdown gate'; Pass = $hasHuskyBlock }
}

$copilotHookConfigured = $false
$copilotWindowsHookConfigured = $false
if (Test-Path $copilotHookJsonPath) {
    $hookText = Get-Content -Path $copilotHookJsonPath -Raw
    $copilotHookConfigured = $hookText -match '"sessionEnd"' -and $hookText -match '\.github/scripts/auto-commit\.sh'
    $copilotWindowsHookConfigured = $hookText -match '"windows"' -and $hookText -match 'sh \.\/\.github/scripts/auto-commit\.sh'
}

$checks += [pscustomobject]@{ Name = 'Copilot hooks.json exists'; Pass = (Test-Path $copilotHookJsonPath) }
$checks += [pscustomobject]@{ Name = 'Copilot hooks.json references .github/scripts/auto-commit.sh'; Pass = $copilotHookConfigured }
$checks += [pscustomobject]@{ Name = 'Copilot hooks.json uses sh override on Windows'; Pass = $copilotWindowsHookConfigured }
$checks += [pscustomobject]@{ Name = 'Legacy standalone Stop profile is absent'; Pass = (-not (Test-Path $legacyStandaloneJsonPath)) }
$checks += [pscustomobject]@{ Name = 'Legacy .github/hooks Stop script is absent'; Pass = (-not (Test-Path $legacyStopScriptPath)) }
$checks += [pscustomobject]@{ Name = 'Legacy copilot/scripts PowerShell hook is absent'; Pass = (-not (Test-Path $legacyManagedCopilotScriptPath)) }

$commandCheck = $null -ne (Get-Command markdownlint-cli2 -ErrorAction SilentlyContinue)
$checks += [pscustomobject]@{ Name = 'markdownlint-cli2 installed'; Pass = $commandCheck }

$failed = $checks | Where-Object { -not $_.Pass }
foreach ($check in $checks) {
    if ($check.Pass) {
        Write-Ok "PASS: $($check.Name)"
    } else {
        Write-Err "FAIL: $($check.Name)"
    }
}

if ($failed) {
    Write-Err "Verification failed: $($failed.Count) check(s) did not pass"
    Write-Err 'Run install again: pwsh -NoProfile -ExecutionPolicy Bypass -File .\copilot-hooks\scripts\1-Install-CopilotHooks.ps1'
    exit 1
}

Write-Ok 'All checks passed'
exit 0
