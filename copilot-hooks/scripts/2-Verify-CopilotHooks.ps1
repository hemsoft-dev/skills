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
$copilotHooksJsonPath = Join-Path $repoRoot '.github/hooks/hooks.json'
$copilotFallbackJsonPath = Join-Path $repoRoot '.github/hooks/session-stop-autopush.json'
$copilotStopScriptPath = Join-Path $repoRoot '.github/hooks/Invoke-AgentSessionAutoPush.ps1'

Write-Warn "Detected active hooks path: $activeHooksPath"

$checks = @(
    [pscustomobject]@{ Name = 'pre-commit exists'; Pass = (Test-Path $preCommitPath) },
    [pscustomobject]@{ Name = 'pre-commit-markdown exists'; Pass = (Test-Path $preCommitMarkdownPath) },
    [pscustomobject]@{ Name = '.markdownlint.jsonc exists'; Pass = (Test-Path $markdownConfigPath) },
    [pscustomobject]@{ Name = 'Copilot Stop script exists'; Pass = (Test-Path $copilotStopScriptPath) }
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

if (Test-Path $copilotStopScriptPath) {
    $stopHookText = Get-Content -Path $copilotStopScriptPath -Raw
    $stagesBeforeBlocking = $stopHookText -match 'git add -A'
    $autoCommitsChanges = $stopHookText -match 'git commit -m'
    $attemptsPush = $stopHookText -match 'git push' -and $stopHookText -match 'Invoke-GitPush'
    $pushesAheadBranches = $stopHookText -match 'AheadCount -gt 0' -and $stopHookText -match 'Working tree is clean; nothing to commit or push'
    $generatesSemanticCommit = $stopHookText -match 'Get-CommitSubject' -and $stopHookText -match 'Get-CommitType'
    $avoidsStaticAutoFollowup = $stopHookText -notmatch 'CommitPrefix\s*=\s*''chore\(session\): auto-followup''' -and $stopHookText -notmatch 'Invoke-GitCommitFaultTolerant'
    $keepsStdoutJsonClean = $stopHookText -match '\[Console\]::Error\.WriteLine' -and $stopHookText -notmatch 'Write-Host'
    $checks += [pscustomobject]@{ Name = 'Stop hook stages remaining changes before blocking'; Pass = $stagesBeforeBlocking }
    $checks += [pscustomobject]@{ Name = 'Stop hook auto-commits staged changes'; Pass = $autoCommitsChanges }
    $checks += [pscustomobject]@{ Name = 'Stop hook attempts to push committed changes'; Pass = $attemptsPush }
    $checks += [pscustomobject]@{ Name = 'Stop hook pushes ahead branches even when tree is clean'; Pass = $pushesAheadBranches }
    $checks += [pscustomobject]@{ Name = 'Stop hook generates semantic commit messages'; Pass = $generatesSemanticCommit }
    $checks += [pscustomobject]@{ Name = 'Stop hook avoids static auto-followup subjects'; Pass = $avoidsStaticAutoFollowup }
    $checks += [pscustomobject]@{ Name = 'Stop hook keeps stdout clean for structured JSON responses'; Pass = $keepsStdoutJsonClean }
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
$hasDuplicateFallback = $false
if (Test-Path $copilotHooksJsonPath) {
    $hooksText = Get-Content -Path $copilotHooksJsonPath -Raw
    $copilotHookConfigured = $hooksText -match 'Invoke-AgentSessionAutoPush\.ps1'
    $hasDuplicateFallback = Test-Path $copilotFallbackJsonPath
} elseif (Test-Path $copilotFallbackJsonPath) {
    $fallbackText = Get-Content -Path $copilotFallbackJsonPath -Raw
    $copilotHookConfigured = $fallbackText -match 'Invoke-AgentSessionAutoPush\.ps1'
}

$checks += [pscustomobject]@{ Name = 'Copilot Stop hook references managed Stop script'; Pass = $copilotHookConfigured }
$checks += [pscustomobject]@{ Name = 'Copilot Stop hook does not have a duplicate fallback profile'; Pass = (-not $hasDuplicateFallback) }

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
