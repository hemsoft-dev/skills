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

# File paths
$preCommitPath = Join-Path $hooksDir 'pre-commit'
$preCommitMarkdownPath = Join-Path $hooksDir 'pre-commit-markdown.ps1'
$markdownConfigPath = Join-Path $repoRoot '.markdownlint.jsonc'
$huskyPreCommitPath = Join-Path $repoRoot '.husky/pre-commit'

$copilotHooksDir = Join-Path $repoRoot '.github/hooks'
$copilotHookJsonPath = Join-Path $copilotHooksDir 'hooks.json'
$playDonePs1Path = Join-Path $copilotHooksDir 'play-done.ps1'
$playDoneShPath = Join-Path $copilotHooksDir 'play-done.sh'
$logPromptPs1Path = Join-Path $copilotHooksDir 'Log-Prompt.ps1'
$logPromptShPath = Join-Path $copilotHooksDir 'log-prompt.sh'
$autoCommitShPath = Join-Path $copilotHooksDir 'auto-commit.sh'
$audioFilePath = Join-Path $copilotHooksDir 'done.mp3'

# Legacy paths (should be absent)
$legacyStandaloneJsonPath = Join-Path $copilotHooksDir 'session-stop-autopush.json'
$legacyStopScriptPath = Join-Path $copilotHooksDir 'Invoke-AgentSessionAutoPush.ps1'
$legacyManagedCopilotScriptPath = Join-Path $repoRoot 'copilot/scripts/Invoke-AgentSessionAutoPush.ps1'
$legacyScriptsAutoCommitPath = Join-Path $repoRoot '.github/scripts/auto-commit.sh'

Write-Warn "Detected active hooks path: $activeHooksPath"

$checks = @()

# ─────────────────────────────────────────────────────────────────────────────
# Copilot CLI hook files
# ─────────────────────────────────────────────────────────────────────────────

$checks += [pscustomobject]@{ Name = 'hooks.json exists'; Pass = (Test-Path $copilotHookJsonPath) }
$checks += [pscustomobject]@{ Name = 'play-done.ps1 exists'; Pass = (Test-Path $playDonePs1Path) }
$checks += [pscustomobject]@{ Name = 'play-done.sh exists'; Pass = (Test-Path $playDoneShPath) }
$checks += [pscustomobject]@{ Name = 'Log-Prompt.ps1 exists'; Pass = (Test-Path $logPromptPs1Path) }
$checks += [pscustomobject]@{ Name = 'log-prompt.sh exists'; Pass = (Test-Path $logPromptShPath) }
$checks += [pscustomobject]@{ Name = 'auto-commit.sh exists'; Pass = (Test-Path $autoCommitShPath) }
$checks += [pscustomobject]@{ Name = 'done.mp3 audio file exists'; Pass = (Test-Path $audioFilePath) }

# hooks.json content checks
if (Test-Path $copilotHookJsonPath) {
    $hookText = Get-Content -Path $copilotHookJsonPath -Raw
    $hasPostToolUse = $hookText -match '"postToolUse"'
    $hasUserPromptSubmitted = $hookText -match '"userPromptSubmitted"'
    $hasSessionEnd = $hookText -match '"sessionEnd"'
    $refsPlayDone = $hookText -match 'play-done'
    $refsLogPrompt = $hookText -match '[Ll]og-[Pp]rompt'
    $refsAutoCommit = $hookText -match 'auto-commit\.sh'

    $checks += [pscustomobject]@{ Name = 'hooks.json has postToolUse event'; Pass = $hasPostToolUse }
    $checks += [pscustomobject]@{ Name = 'hooks.json has userPromptSubmitted event'; Pass = $hasUserPromptSubmitted }
    $checks += [pscustomobject]@{ Name = 'hooks.json has sessionEnd event'; Pass = $hasSessionEnd }
    $checks += [pscustomobject]@{ Name = 'hooks.json references play-done script'; Pass = $refsPlayDone }
    $checks += [pscustomobject]@{ Name = 'hooks.json references log-prompt script'; Pass = $refsLogPrompt }
    $checks += [pscustomobject]@{ Name = 'hooks.json references auto-commit.sh'; Pass = $refsAutoCommit }
}

# play-done.ps1 content checks
if (Test-Path $playDonePs1Path) {
    $playText = Get-Content -Path $playDonePs1Path -Raw
    $checksTaskComplete = $playText -match 'task_complete'
    $usesFfplay = $playText -match 'ffplay'

    $checks += [pscustomobject]@{ Name = 'play-done.ps1 triggers only on task_complete'; Pass = $checksTaskComplete }
    $checks += [pscustomobject]@{ Name = 'play-done.ps1 uses ffplay for audio'; Pass = $usesFfplay }
}

# Log-Prompt.ps1 content checks
if (Test-Path $logPromptPs1Path) {
    $promptText = Get-Content -Path $logPromptPs1Path -Raw
    $readsStdin = $promptText -match 'ReadToEnd'

    $checks += [pscustomobject]@{ Name = 'Log-Prompt.ps1 reads stdin'; Pass = $readsStdin }
}

# auto-commit.sh content checks
if (Test-Path $autoCommitShPath) {
    $stopHookText = Get-Content -Path $autoCommitShPath -Raw
    $stagesChanges = $stopHookText -match 'git add -A'
    $autoCommits = $stopHookText -match 'git commit -m'
    $usesTimestamp = $stopHookText -match 'auto-commit:'
    $usesNoVerify = $stopHookText -match '--no-verify'
    $attemptsPush = $stopHookText -match 'git push'
    $disablesPrompt = $stopHookText -match 'GIT_TERMINAL_PROMPT=0'
    $disablesGcm = $stopHookText -match 'GCM_INTERACTIVE=Never'
    $usesFastSsh = $stopHookText -match 'BatchMode=yes' -and $stopHookText -match 'ConnectTimeout=5'
    $duplicateGuard = $stopHookText -match 'duplicate hook invocation'

    $checks += [pscustomobject]@{ Name = 'auto-commit.sh stages remaining changes'; Pass = $stagesChanges }
    $checks += [pscustomobject]@{ Name = 'auto-commit.sh creates timestamped commit'; Pass = ($autoCommits -and $usesTimestamp) }
    $checks += [pscustomobject]@{ Name = 'auto-commit.sh uses --no-verify'; Pass = $usesNoVerify }
    $checks += [pscustomobject]@{ Name = 'auto-commit.sh attempts push'; Pass = $attemptsPush }
    $checks += [pscustomobject]@{ Name = 'auto-commit.sh disables interactive prompts'; Pass = ($disablesPrompt -and $disablesGcm) }
    $checks += [pscustomobject]@{ Name = 'auto-commit.sh uses fast-fail SSH'; Pass = $usesFastSsh }
    $checks += [pscustomobject]@{ Name = 'auto-commit.sh guards against duplicate invocations'; Pass = $duplicateGuard }
}

# ─────────────────────────────────────────────────────────────────────────────
# Pre-commit hooks
# ─────────────────────────────────────────────────────────────────────────────

$checks += [pscustomobject]@{ Name = 'pre-commit hook exists'; Pass = (Test-Path $preCommitPath) }
$checks += [pscustomobject]@{ Name = 'pre-commit-markdown.ps1 exists'; Pass = (Test-Path $preCommitMarkdownPath) }
$checks += [pscustomobject]@{ Name = '.markdownlint.jsonc exists'; Pass = (Test-Path $markdownConfigPath) }

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

if ($activeHooksPath -eq '.husky/_') {
    $hasHuskyBlock = $false
    if (Test-Path $huskyPreCommitPath) {
        $huskyText = Get-Content -Path $huskyPreCommitPath -Raw
        $hasHuskyBlock = ($huskyText -match 'copilot-hooks:begin markdown gate')
    }
    $checks += [pscustomobject]@{ Name = 'Husky pre-commit contains copilot markdown gate'; Pass = $hasHuskyBlock }
}

# ─────────────────────────────────────────────────────────────────────────────
# Tool availability
# ─────────────────────────────────────────────────────────────────────────────

$ffplayInstalled = $null -ne (Get-Command ffplay -ErrorAction SilentlyContinue)
$checks += [pscustomobject]@{ Name = 'ffplay installed (for audio)'; Pass = $ffplayInstalled }

$markdownlintInstalled = $null -ne (Get-Command markdownlint-cli2 -ErrorAction SilentlyContinue)
$checks += [pscustomobject]@{ Name = 'markdownlint-cli2 installed'; Pass = $markdownlintInstalled }

# ─────────────────────────────────────────────────────────────────────────────
# Legacy artifacts (should be absent)
# ─────────────────────────────────────────────────────────────────────────────

$checks += [pscustomobject]@{ Name = 'Legacy standalone Stop profile is absent'; Pass = (-not (Test-Path $legacyStandaloneJsonPath)) }
$checks += [pscustomobject]@{ Name = 'Legacy .github/hooks Stop script is absent'; Pass = (-not (Test-Path $legacyStopScriptPath)) }
$checks += [pscustomobject]@{ Name = 'Legacy copilot/scripts PowerShell hook is absent'; Pass = (-not (Test-Path $legacyManagedCopilotScriptPath)) }
$checks += [pscustomobject]@{ Name = 'Legacy .github/scripts/auto-commit.sh is absent'; Pass = (-not (Test-Path $legacyScriptsAutoCommitPath)) }

# ─────────────────────────────────────────────────────────────────────────────
# Results
# ─────────────────────────────────────────────────────────────────────────────

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
