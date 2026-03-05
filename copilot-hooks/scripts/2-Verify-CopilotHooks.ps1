#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [Parameter()]
    [string]$RepoPath = '.'
)

function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Err([string]$Message) { Write-Host $Message -ForegroundColor Red }

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
$preCommitPath = Join-Path $hooksDir 'pre-commit'
$preCommitMarkdownPath = Join-Path $hooksDir 'pre-commit-markdown.ps1'
$markdownConfigPath = Join-Path $repoRoot '.markdownlint.jsonc'

$checks = @(
    [pscustomobject]@{ Name = 'pre-commit exists'; Pass = (Test-Path $preCommitPath) },
    [pscustomobject]@{ Name = 'pre-commit-markdown exists'; Pass = (Test-Path $preCommitMarkdownPath) },
    [pscustomobject]@{ Name = '.markdownlint.jsonc exists'; Pass = (Test-Path $markdownConfigPath) }
)

if (Test-Path $preCommitPath) {
    $preCommitText = Get-Content -Path $preCommitPath -Raw
    $callsMarkdownHook = $preCommitText -match 'pre-commit-markdown\.ps1'
    $checks += [pscustomobject]@{ Name = 'pre-commit calls markdown hook'; Pass = $callsMarkdownHook }
}

if (Test-Path $preCommitMarkdownPath) {
    $psHookText = Get-Content -Path $preCommitMarkdownPath -Raw
    $usesMarkdownlint = $psHookText -match 'markdownlint-cli2'
    $checks += [pscustomobject]@{ Name = 'markdown hook uses markdownlint-cli2'; Pass = $usesMarkdownlint }
}

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
    exit 1
}

Write-Ok 'All checks passed'
exit 0
