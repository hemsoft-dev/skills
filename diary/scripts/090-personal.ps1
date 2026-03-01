#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ensures the Personal section has a clean skeleton for user input.

.DESCRIPTION
    Replaces the Personal section placeholder content with a minimal
    reflections skeleton. This is a user-editable section — the script
    only provides the scaffold, never overwrites user content.

.PARAMETER Date
    The date for the diary entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER EntryPath
    The full path to the diary entry file to update.

.EXAMPLE
    .\090-personal.ps1 -Date 2026-02-28
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Resolve entry path ---
if (-not $EntryPath) {
    $EntryPath = Join-Path $PSScriptRoot '..' 'entries' "$Date.md"
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

$entry = Get-Content $EntryPath -Raw

# --- Check if section still has placeholder content ---
$hasPlaceholder = $entry -match '\{user to provide\}'
if (-not $hasPlaceholder) {
    Write-Information "`e[90mPersonal section already has user content — skipping.`e[0m"
    exit 0
}

# --- Build skeleton ---
$personalContent = @"
### 💭 Reflections

-${' '}
"@

# --- Inject into diary entry ---
$sectionPattern = '(#{2,3}\s+🏠\s+Personal\s*\r?\n)([\s\S]*?)(\r?\n---)'
$regex = [regex]::new($sectionPattern)
$m = $regex.Match($entry)
if ($m.Success) {
    $before = $entry.Substring(0, $m.Index)
    $after = $entry.Substring($m.Index + $m.Length)
    $entry = $before + $m.Groups[1].Value + "`n" + $personalContent + "`n" + $m.Groups[3].Value + $after
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($EntryPath, $entry, $utf8NoBom)
    Write-Information "`e[1;32mPersonal section skeleton set.`e[0m"
}
else {
    Write-Information "`e[1;31mPersonal section (## 🏠 Personal) not found in entry. Cannot inject.`e[0m"
}
