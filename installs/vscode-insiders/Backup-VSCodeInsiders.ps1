<#
.SYNOPSIS
    Backs up VS Code Insiders settings and extensions list to this folder.
#>
$InformationPreference = 'Continue'

[CmdletBinding()]
param()

$backupDir = $PSScriptRoot
$vscodeDir = "$env:APPDATA\Code - Insiders\User"

Write-Information "[36mBacking up VS Code Insiders...`e[0m"

# Backup settings.json
$settingsPath = Join-Path $vscodeDir "settings.json"
if (Test-Path $settingsPath) {
    Copy-Item $settingsPath -Destination (Join-Path $backupDir "settings.json") -Force
    Write-Information "[32m  ✓ settings.json`e[0m"
}
else {
    Write-Warning "  settings.json not found"
}

# Backup keybindings.json
$keybindingsPath = Join-Path $vscodeDir "keybindings.json"
if (Test-Path $keybindingsPath) {
    Copy-Item $keybindingsPath -Destination (Join-Path $backupDir "keybindings.json") -Force
    Write-Information "[32m  ✓ keybindings.json`e[0m"
}

# Export extensions list
$codePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"
if (Test-Path $codePath) {
    & $codePath --list-extensions 2>$null | Out-File (Join-Path $backupDir "extensions.txt") -Encoding utf8
    $count = (Get-Content (Join-Path $backupDir "extensions.txt")).Count
    Write-Information "[32m  ✓ extensions.txt ($count extensions)`e[0m"
}
else {
    Write-Warning "  VS Code Insiders CLI not found"
}

Write-Information "[32mVS Code Insiders backup complete!`e[0m"
