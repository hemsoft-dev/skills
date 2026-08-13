#!/usr/bin/env pwsh
# Managed by Install-GitHooks.ps1 — source of truth is the hooks/ folder in this repo.
# Git pre-commit hook that enforces PowerShell quality standards.
# Runs PSScriptAnalyzer on staged .ps1 files using the repo settings.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Success([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }
function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }

Write-Info 'Running PowerShell quality checks...'

# Check PSScriptAnalyzer is available
$psaInstalled = $null -ne (Get-Module -ListAvailable -Name PSScriptAnalyzer)
if (-not $psaInstalled) {
    Write-Fail 'PSScriptAnalyzer is not installed.'
    Write-Info 'Install it with: Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser'
    exit 1
}

Import-Module PSScriptAnalyzer -ErrorAction Stop

# Get staged .ps1 files (Added, Copied, Modified - exclude Deleted)
$stagedFiles = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -match '\.ps1$' }
if (-not $stagedFiles) {
    Write-Success 'No PowerShell files staged for commit'
    exit 0
}

$repoRoot = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Fail 'Could not determine repository root'
    exit 1
}

if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    $repoRoot = $repoRoot -replace '/', '\\'
}

# Locate settings file
$settingsPath = Join-Path $repoRoot '.PSScriptAnalyzerSettings.psd1'
if (-not (Test-Path $settingsPath)) {
    Write-Info 'No .PSScriptAnalyzerSettings.psd1 found - using default rules'
    $settingsPath = $null
}

$hasErrors = $false
$totalIssues = 0

foreach ($file in $stagedFiles) {
    $filePath = Join-Path $repoRoot $file
    if (-not (Test-Path $filePath)) {
        continue
    }

    Write-Info "Checking: $file"

    $analyzerParams = @{ Path = $filePath }
    if ($settingsPath) {
        $analyzerParams['Settings'] = $settingsPath
    }

    $results = @(Invoke-ScriptAnalyzer @analyzerParams)

    if ($results.Count -gt 0) {
        $hasErrors = $true
        $totalIssues += $results.Count
        Write-Fail "  Issues found in ${file}:"
        foreach ($result in $results) {
            $color = if ($result.Severity -eq 'Error') { 'Red' } else { 'Yellow' }
            Write-Host "    Line $($result.Line): [$($result.Severity)] $($result.RuleName)" -ForegroundColor $color
            Write-Host "      $($result.Message)" -ForegroundColor Gray
        }
    }
}

if ($hasErrors) {
    Write-Fail "`nCOMMIT BLOCKED: PSScriptAnalyzer found $totalIssues issue(s)"
    Write-Info 'Fix the issues above, then re-stage and commit.'
    exit 1
}

Write-Success 'All PowerShell files passed quality checks'
exit 0
