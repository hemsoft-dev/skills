#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates the diary entry file from the template with the header filled in.

.DESCRIPTION
    Reads config/yyyy-mm-dd.html, replaces date/weekday placeholders in the header,
    and writes the scaffolded entry file. Skips if the entry already exists.

.PARAMETER Date
    The date for the diary entry. Defaults to today.

.PARAMETER EntryPath
    The full path to the output diary entry file.

.EXAMPLE
    .\01-diary-header.ps1 -Date 2026-03-01 -EntryPath ..\entries\2026-03-01.html
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Resolve paths
$configDir = Join-Path $PSScriptRoot (Join-Path '..' 'config')
$templatePath = Join-Path $configDir 'yyyy-mm-dd.html'

if (-not $EntryPath) {
    $year = $Date.Substring(0, 4)
    $month = $Date.Substring(5, 2)
    $entriesDir = Join-Path $PSScriptRoot (Join-Path '..' (Join-Path 'entries' (Join-Path $year $month)))
    if (-not (Test-Path $entriesDir)) {
        New-Item -ItemType Directory -Path $entriesDir -Force | Out-Null
    }
    $EntryPath = Join-Path $entriesDir "$Date.html"
}

if (Test-Path $EntryPath) {
    Write-Information "Entry already exists: $EntryPath - skipping header scaffold."
    return
}

if (-not (Test-Path $templatePath)) {
    Write-Error "Template not found at: $templatePath"
    exit 1
}

# Parse the date
$parsedDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)
$weekday = $parsedDate.ToString('dddd')
# Read template and replace header placeholders
$content = Get-Content $templatePath -Raw
$content = $content -replace '\{Weekday\}', $weekday
$content = $content -replace '\{YYYY-MM-DD\}', $Date

# Write the scaffolded entry
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($EntryPath, $content, $utf8NoBom)

Write-Information "Created diary entry: $EntryPath"
Write-Information "  Date: $weekday, $Date"
