<#
.SYNOPSIS
    Backs up Windows Terminal settings to this folder.
#>

[CmdletBinding()]
param()

$backupDir = $PSScriptRoot

Write-Information "[36mBacking up Windows Terminal settings...`e[0m"

$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
)

$InformationPreference = 'Continue'

$found = $false
foreach ($wtPath in $wtPaths) {
    if (Test-Path $wtPath) {
        Copy-Item $wtPath -Destination (Join-Path $backupDir "settings.json") -Force
        Write-Information "[32m  ✓ settings.json`e[0m"
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Warning "  Windows Terminal settings not found"
}

Write-Information "[32mWindows Terminal backup complete!`e[0m"
