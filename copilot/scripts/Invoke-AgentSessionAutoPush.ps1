#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [int]$MaxFollowUpCommits = 5,
    [string]$CommitPrefix = 'chore(session): auto-followup',
    [switch]$SkipPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Prevent recursive session-stop hook execution in case stop automation loops.
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

function Get-StagedFile {
    return (git diff --cached --name-only)
}

function Get-CurrentBranch {
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw 'Unable to resolve current branch.'
    }

    return $branch
}

function Invoke-GitAdd {
    $addOutput = @(& git add -A 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $details = ($addOutput -join [Environment]::NewLine)
        throw "git add failed during follow-up pass.$([Environment]::NewLine)$details"
    }

    # Suppress common line-ending conversion noise while preserving actionable warnings.
    $filtered = @(
        $addOutput |
            ForEach-Object { "$($_)" } |
            Where-Object { $_ -and ($_ -notmatch 'will be replaced by') }
    )

    foreach ($line in $filtered) {
        Write-Info "git add: $line"
    }
}

function Invoke-GitCommitFaultTolerant([string]$Message) {
    $commitOutput = @(& git commit -m $Message 2>&1)
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-Info 'git commit failed (likely hook/lint checks). Retrying with --no-verify for session-stop fault tolerance.'
    $retryOutput = @(& git commit --no-verify -m $Message 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $firstAttempt = ($commitOutput -join [Environment]::NewLine)
        $secondAttempt = ($retryOutput -join [Environment]::NewLine)
        throw "git commit failed during follow-up pass (both normal and --no-verify attempts failed).$([Environment]::NewLine)First attempt:$([Environment]::NewLine)$firstAttempt$([Environment]::NewLine)Retry:$([Environment]::NewLine)$secondAttempt"
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
        Write-Info 'Working tree is clean.'
        break
    }

    Write-Info "Detected uncommitted changes after commit. Follow-up pass $i/$MaxFollowUpCommits."
    Invoke-GitAdd

    $staged = Get-StagedFile
    if (-not $staged) {
        Write-Info 'No staged changes remain. Stopping follow-up loop.'
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
    $branch = Get-CurrentBranch
    Write-Info "Pushing branch '$branch'"
    git push
    if ($LASTEXITCODE -ne 0) {
        throw 'git push failed during session-stop automation.'
    }
}

Write-Info 'Completed successfully.'
