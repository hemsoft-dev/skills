#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a new diary entry for the specified date.

.DESCRIPTION
    Validates that no entry exists for the target date, then calls the
    diary orchestrator to scaffold and populate the entry.
    If an entry already exists, aborts and advises using the update command.

.PARAMETER Date
    The date to create the entry for in yyyy-MM-dd format. Defaults to today.

.EXAMPLE
    .\create.ps1
    Creates a diary entry for today.

.EXAMPLE
    .\create.ps1 -Date 2026-03-01
    Creates a diary entry for March 1, 2026.
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$year = $Date.Substring(0, 4)
$month = $Date.Substring(5, 2)
$entriesDir = Join-Path $PSScriptRoot '..' 'entries' $year $month
$entryPath = Join-Path $entriesDir "$Date.md"

# Validate: entry must not already exist
if (Test-Path $entryPath) {
    Write-Information "`e[1;31mDiary entry already exists: $entryPath`e[0m"
    Write-Information "`e[1;33mUse the 'update' command to modify an existing entry.`e[0m"
    exit 1
}

Write-Information "`e[1;36m=== Creating diary entry: $Date ===`e[0m"

# Hand off to orchestrator
$orchestrator = Join-Path $PSScriptRoot 'diary-orchestrator.ps1'
& $orchestrator -Date $Date
