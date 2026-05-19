#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Orchestrator script that runs all diary section scripts in order.

.DESCRIPTION
    Calls each numbered diary script sequentially to build and populate
    the script-backed sections of a diary entry for the specified date.
    The higher-level scaffold workflow can still add live-only sections
    outside this script chain.

.PARAMETER Date
    The date to generate the diary entry for. Defaults to today.

.EXAMPLE
    .\diary-orchestrator.ps1
    Runs all section scripts for today's entry.

.EXAMPLE
    .\diary-orchestrator.ps1 -Date 2026-03-01
    Runs all section scripts for March 1, 2026.
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$scriptDir = $PSScriptRoot
$year = $Date.Substring(0, 4)
$month = $Date.Substring(5, 2)
$entriesDir = Join-Path $scriptDir '..' 'entries' $year $month

if (-not (Test-Path $entriesDir)) {
    New-Item -ItemType Directory -Path $entriesDir -Force | Out-Null
}

$entryPath = Join-Path $entriesDir "$Date.html"

Write-Information "`e[1;36m=== Diary Entry: $Date ===`e[0m"
Write-Information ""

# Collect all numbered scripts (010-*, 020-*, etc.) and run in order
$scripts = Get-ChildItem -Path $scriptDir -Filter '*.ps1' |
    Where-Object { $_.Name -match '^\d{3}-' } |
    Sort-Object Name

foreach ($script in $scripts) {
    Write-Information "`e[1;33m--- Running: $($script.Name) ---`e[0m"
    & $script.FullName -Date $Date -EntryPath $entryPath
    Write-Information ""
}

Write-Information "`e[1;32m=== Diary entry complete: $entryPath ===`e[0m"
