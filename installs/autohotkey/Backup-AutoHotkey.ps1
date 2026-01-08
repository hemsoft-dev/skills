<#
.SYNOPSIS
    Backs up AutoHotkey script to this folder.
#>
$InformationPreference = 'Continue'

[CmdletBinding()]
param()

$backupDir = $PSScriptRoot
$ahkSource = "$env:USERPROFILE\Documents\AutoHotkey.ahk"

Write-Information "[36mBacking up AutoHotkey...`e[0m"

if (Test-Path $ahkSource) {
    Copy-Item $ahkSource -Destination (Join-Path $backupDir "AutoHotkey.ahk") -Force
    Write-Information "[32m  ✓ AutoHotkey.ahk`e[0m"
}
else {
    Write-Warning "  AutoHotkey.ahk not found at: $ahkSource"
}

Write-Information "[32mAutoHotkey backup complete!`e[0m"
