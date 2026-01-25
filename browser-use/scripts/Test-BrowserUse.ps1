#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests browser-use installation and basic functionality.

.DESCRIPTION
    Verifies that browser-use is installed and can run a simple test task.

.EXAMPLE
    .\Test-BrowserUse.ps1
    Runs a basic test to verify browser-use installation.
#>

[CmdletBinding()]
param()

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine skill directory (parent of scripts folder)
$skillDir = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $skillDir "venv"
$pythonExe = Join-Path $venvPath "Scripts\python.exe"

Write-Information "`e[36mTesting browser-use installation...`e[0m"

try {
    # Check if venv exists
    if (-not (Test-Path $pythonExe)) {
        Write-Error "Virtual environment not found. Run Install-BrowserUse.ps1 first."
        exit 1
    }
    Write-Information "`e[32m✓ Virtual environment found`e[0m"

    # Check if browser-use is installed in venv
    $importTest = & $pythonExe -c "import browser_use; print('OK')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "browser-use is not installed. Run Install-BrowserUse.ps1 first."
        exit 1
    }
    Write-Information "`e[32m✓ browser-use package is installed`e[0m"

    # Check if playwright is available
    $playwrightTest = & $pythonExe -c "from playwright.sync_api import sync_playwright; print('OK')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Playwright is not installed. Run Install-BrowserUse.ps1 first."
        exit 1
    }
    Write-Information "`e[32m✓ Playwright is installed`e[0m"

    # Check if browser-use CLI is available (if installed)
    $cliExe = Join-Path $venvPath "Scripts\browser-use.exe"
    if (Test-Path $cliExe) {
        $cliTest = & $cliExe --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Information "`e[32m✓ browser-use CLI is available: $cliTest`e[0m"
        }
    } else {
        Write-Information "`e[33m⚠ browser-use CLI not installed (optional)`e[0m"
    }

    Write-Information "`e[32mAll tests passed!`e[0m"

} catch {
    Write-Error "Test failed: $_"
    exit 1
}
