#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs the repo's canonical git hooks from hooks/ into .git/hooks/.
.DESCRIPTION
    The hooks/ folder is the version-controlled source of truth for this
    repo's git hooks. Running this script copies them into .git/hooks/,
    overwriting any existing hooks (a clean reset).
.EXAMPLE
    .\Install-GitHooks.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Error 'Not inside a git repository.'
    exit 1
}
if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    $repoRoot = $repoRoot -replace '/', '\\'
}

$sourceDir = Join-Path $repoRoot 'hooks'
$targetDir = Join-Path $repoRoot '.git' 'hooks'

if (-not (Test-Path $sourceDir)) {
    Write-Error "Canonical hooks folder not found at $sourceDir"
    exit 1
}

$hookFiles = Get-ChildItem -LiteralPath $sourceDir -File
if (-not $hookFiles) {
    Write-Error "No hook files found in $sourceDir"
    exit 1
}

New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

foreach ($file in $hookFiles) {
    $destination = Join-Path $targetDir $file.Name
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    Write-Host "Installed $($file.Name) -> .git/hooks/$($file.Name)" -ForegroundColor Green
}

Write-Host "`nGit hooks installed. Re-run this script any time to reset .git/hooks to the canonical copies." -ForegroundColor Cyan
