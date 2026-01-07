<#
.SYNOPSIS
    Backs up Windows Terminal settings to this folder.
#>
$InformationPreference = 'Continue'

[CmdletBinding()]
param()

$backupDir = $PSScriptRoot

Write-Information "Backing up Windows Terminal settings..." -ForegroundColor Cyan

$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
)

$found = $false
foreach ($wtPath in $wtPaths) {
    if (Test-Path $wtPath) {
        Copy-Item $wtPath -Destination (Join-Path $backupDir "settings.json") -Force
        Write-Information "  ✓ settings.json" -ForegroundColor Green
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Warning "  Windows Terminal settings not found"
}

Write-Information "Windows Terminal backup complete!" -ForegroundColor Green
