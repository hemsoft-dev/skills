#!/usr/bin/env pwsh
# Managed by Install-GitHooks.ps1 — source of truth is the hooks/ folder in this repo.
# Git pre-commit hook that enforces Markdown quality standards.
# Runs markdownlint-cli2 on staged Markdown files using the repo root config.

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
    Write-Info "Restore .markdownlint.jsonc at the repo root."
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
