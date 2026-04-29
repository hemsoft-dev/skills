#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates the diary entry file from the template with the header filled in.

.DESCRIPTION
    Reads config/yyyy-mm-dd.md, replaces date/weekday placeholders in the header,
    and writes the scaffolded entry file. Skips if the entry already exists.

.PARAMETER Date
    The date for the diary entry. Defaults to today.

.PARAMETER EntryPath
    The full path to the output diary entry file.

.EXAMPLE
    .\01-diary-header.ps1 -Date 2026-03-01 -EntryPath ..\entries\2026-03-01.md
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Resolve paths
$configDir = Join-Path $PSScriptRoot '..' 'config'
$templatePath = Join-Path $configDir 'yyyy-mm-dd.md'

if (-not $EntryPath) {
    $year = $Date.Substring(0, 4)
    $month = $Date.Substring(5, 2)
    $entriesDir = Join-Path $PSScriptRoot '..' 'entries' $year $month
    if (-not (Test-Path $entriesDir)) {
        New-Item -ItemType Directory -Path $entriesDir -Force | Out-Null
    }
    $EntryPath = Join-Path $entriesDir "$Date.md"
}

if (Test-Path $EntryPath) {
    Write-Information "`e[1;33mEntry already exists: $EntryPath — skipping header scaffold.`e[0m"
    return
}

if (-not (Test-Path $templatePath)) {
    Write-Error "Template not found at: $templatePath"
    exit 1
}

# Parse the date
$parsedDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)
$weekday = $parsedDate.ToString('dddd')
$monthDayYear = $parsedDate.ToString('MMMM d, yyyy')

# Read template and replace header placeholders
$content = Get-Content $templatePath -Raw
$content = $content -replace '\{Weekday\}', $weekday
$content = $content -replace '\{YYYY-MM-DD\}', $Date
$content = $content -replace '\{Month Day, Year\}', $monthDayYear

# Write the scaffolded entry
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($EntryPath, $content, $utf8NoBom)

Write-Information "`e[1;32mCreated diary entry: $EntryPath`e[0m"
Write-Information "  Date: $weekday, $Date"
