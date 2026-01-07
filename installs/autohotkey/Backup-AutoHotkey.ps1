<#
.SYNOPSIS
    Backs up AutoHotkey script to this folder.
#>
$InformationPreference = 'Continue'

[CmdletBinding()]
param()

$backupDir = $PSScriptRoot
$ahkSource = "$env:USERPROFILE\Documents\AutoHotkey.ahk"

Write-Information "Backing up AutoHotkey..." -ForegroundColor Cyan

if (Test-Path $ahkSource) {
    Copy-Item $ahkSource -Destination (Join-Path $backupDir "AutoHotkey.ahk") -Force
    Write-Information "  ✓ AutoHotkey.ahk" -ForegroundColor Green
}
else {
    Write-Warning "  AutoHotkey.ahk not found at: $ahkSource"
}

Write-Information "AutoHotkey backup complete!" -ForegroundColor Green
