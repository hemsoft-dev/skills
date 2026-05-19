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

. (Join-Path $PSScriptRoot 'HtmlDiaryHelpers.ps1')

# --- Resolve entry path ---
if (-not $EntryPath) {
    $EntryPath = Get-DiaryHtmlEntryPath -ScriptRoot $PSScriptRoot -Date $Date
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

$sectionHtml = Get-DiarySectionInnerHtml -EntryPath $EntryPath -SectionTitle '💭 Personal Reflections'

# --- Check if section still has placeholder content ---
if (-not $sectionHtml -or $sectionHtml -notmatch '<!-- TODO: fill in -->') {
    Write-Information "`e[90mPersonal section already has user content — skipping.`e[0m"
    exit 0
}

# --- Build skeleton ---
$personalContent = @'
<div class="card todo-callout">
  <!-- TODO: fill in -->
  <strong>TODO:</strong> Add your thoughts, feelings, observations, or anything else worth remembering about today.
</div>
'@

Set-DiarySectionInnerHtml -EntryPath $EntryPath -SectionTitle '💭 Personal Reflections' -InnerHtml $personalContent
Write-Information "`e[1;32mPersonal section skeleton set.`e[0m"
