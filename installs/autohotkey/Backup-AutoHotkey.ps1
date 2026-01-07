<#
.SYNOPSIS
    Backs up AutoHotkey script to this folder.
#>
[CmdletBinding()]
param()

$backupDir = $PSScriptRoot
$ahkSource = "$env:USERPROFILE\Documents\AutoHotkey.ahk"

Write-Host "Backing up AutoHotkey..." -ForegroundColor Cyan

if (Test-Path $ahkSource) {
    Copy-Item $ahkSource -Destination (Join-Path $backupDir "AutoHotkey.ahk") -Force
    Write-Host "  ✓ AutoHotkey.ahk" -ForegroundColor Green
}
else {
    Write-Warning "  AutoHotkey.ahk not found at: $ahkSource"
}

Write-Host "AutoHotkey backup complete!" -ForegroundColor Green
