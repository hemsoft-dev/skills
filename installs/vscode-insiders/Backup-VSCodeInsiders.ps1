<#
.SYNOPSIS
    Backs up VS Code Insiders settings and extensions list to this folder.
#>
[CmdletBinding()]
param()

$backupDir = $PSScriptRoot
$vscodeDir = "$env:APPDATA\Code - Insiders\User"

Write-Host "Backing up VS Code Insiders..." -ForegroundColor Cyan

# Backup settings.json
$settingsPath = Join-Path $vscodeDir "settings.json"
if (Test-Path $settingsPath) {
    Copy-Item $settingsPath -Destination (Join-Path $backupDir "settings.json") -Force
    Write-Host "  ✓ settings.json" -ForegroundColor Green
}
else {
    Write-Warning "  settings.json not found"
}

# Backup keybindings.json
$keybindingsPath = Join-Path $vscodeDir "keybindings.json"
if (Test-Path $keybindingsPath) {
    Copy-Item $keybindingsPath -Destination (Join-Path $backupDir "keybindings.json") -Force
    Write-Host "  ✓ keybindings.json" -ForegroundColor Green
}

# Export extensions list
$codePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"
if (Test-Path $codePath) {
    & $codePath --list-extensions 2>$null | Out-File (Join-Path $backupDir "extensions.txt") -Encoding utf8
    $count = (Get-Content (Join-Path $backupDir "extensions.txt")).Count
    Write-Host "  ✓ extensions.txt ($count extensions)" -ForegroundColor Green
}
else {
    Write-Warning "  VS Code Insiders CLI not found"
}

Write-Host "VS Code Insiders backup complete!" -ForegroundColor Green
