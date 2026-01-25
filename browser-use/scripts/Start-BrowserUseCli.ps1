#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Starts the browser-use interactive CLI.

.DESCRIPTION
    Launches the browser-use interactive CLI (similar to 'claude code').
    Requires browser-use[cli] to be installed.

.PARAMETER EnvFile
    Path to .env file containing API keys (default: .env in current directory)

.EXAMPLE
    .\Start-BrowserUseCli.ps1
    Starts the interactive browser-use CLI.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$EnvFile = '.env'
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine skill directory (parent of scripts folder)
$skillDir = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $skillDir "venv"
$pythonExe = Join-Path $venvPath "Scripts\python.exe"
$cliExe = Join-Path $venvPath "Scripts\browser-use.exe"

# Check if venv exists
if (-not (Test-Path $pythonExe)) {
    Write-Error "Virtual environment not found. Run Install-BrowserUse.ps1 first."
    exit 1
}

# Check if CLI is installed
if (-not (Test-Path $cliExe)) {
    Write-Error "browser-use CLI is not installed. Install with: Install-BrowserUse.ps1 -IncludeCli"
    exit 1
}

# Load environment variables if .env file exists
if (Test-Path $EnvFile) {
    Write-Information "`e[36mLoading environment variables from $EnvFile...`e[0m"
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}

Write-Information "`e[36mStarting browser-use interactive CLI...`e[0m"
Write-Information "`e[33mPress Ctrl+C to exit`e[0m"

& $cliExe
