#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs browser-use Python package and Playwright browser dependencies.

.DESCRIPTION
    Installs browser-use package via pip and installs Chromium browser using Playwright.
    Also installs CLI support if requested.

.PARAMETER IncludeCli
    Install browser-use with CLI support.

.EXAMPLE
    .\Install-BrowserUse.ps1
    Installs browser-use and Chromium browser.

.EXAMPLE
    .\Install-BrowserUse.ps1 -IncludeCli
    Installs browser-use with CLI support.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$IncludeCli
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine skill directory (parent of scripts folder)
$skillDir = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $skillDir "venv"

Write-Information "`e[36mInstalling browser-use in isolated virtual environment...`e[0m"

try {
    # Check if Python launcher is available
    $pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
    if (-not $pythonLauncher) {
        Write-Error "Python launcher (py) is not available. Please install Python 3.11+ first."
        exit 1
    }

    # Check Python version
    $pythonVersion = py --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Python is not installed. Please install Python 3.11+ first."
        exit 1
    }
    Write-Information "`e[32mFound Python: $pythonVersion`e[0m"

    # Create venv if it doesn't exist
    if (-not (Test-Path "$venvPath\Scripts\python.exe")) {
        Write-Information "`e[36mCreating virtual environment in $venvPath...`e[0m"
        py -m venv $venvPath
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create virtual environment"
            exit 1
        }
        Write-Information "`e[32m✓ Virtual environment created`e[0m"
    } else {
        Write-Information "`e[32m✓ Virtual environment already exists`e[0m"
    }

    # Use venv Python directly
    $pythonExe = Join-Path $venvPath "Scripts\python.exe"

    # Upgrade pip in venv
    Write-Information "`e[36mUpgrading pip...`e[0m"
    & $pythonExe -m pip install --upgrade pip --quiet

    # Install browser-use in venv
    if ($IncludeCli) {
        Write-Information "`e[36mInstalling browser-use with CLI support...`e[0m"
        & $pythonExe -m pip install "browser-use[cli]"
    } else {
        Write-Information "`e[36mInstalling browser-use...`e[0m"
        & $pythonExe -m pip install browser-use
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install browser-use"
        exit 1
    }

    Write-Information "`e[32m✓ browser-use installed successfully`e[0m"

    # Install Chromium browser using venv Python
    Write-Information "`e[36mInstalling Chromium browser...`e[0m"
    & $pythonExe -m playwright install chromium --with-deps --no-shell

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install Chromium browser"
        exit 1
    }

    Write-Information "`e[32m✓ Chromium browser installed successfully`e[0m"
    Write-Information "`e[32mInstallation complete!`e[0m"
    Write-Information "`e[33mVirtual environment location: $venvPath`e[0m"

} catch {
    Write-Error "Installation failed: $_"
    exit 1
}
