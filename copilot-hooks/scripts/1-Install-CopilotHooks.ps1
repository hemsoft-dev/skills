#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [Parameter()]
    [string]$RepoPath = '.'
)

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
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
New-Item -Path $hooksDir -ItemType Directory -Force | Out-Null

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
        Write-Fail "Issues found in $file:"
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

if (-not (Test-Path $markdownConfigPath)) {
    Set-Content -Path $markdownConfigPath -Value $starterMarkdownlintConfig -Encoding utf8NoBOM
    Write-Ok "Created starter config: $markdownConfigPath"
} else {
    Write-Warn "Existing markdownlint config kept: $markdownConfigPath"
}

Write-Ok "Install complete"
