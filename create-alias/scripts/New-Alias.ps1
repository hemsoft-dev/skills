#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a PowerShell alias in the global profile that works across all terminals.

.DESCRIPTION
    Adds an alias (as a function) to $PROFILE.CurrentUserAllHosts (profile.ps1) so it works
    in Windows Terminal, VS Code, PowerShell console, and PowerShell 7.

.PARAMETER AliasName
    The name of the alias to create (e.g., "play", "gs", "dc").

.PARAMETER Command
    The command to execute when the alias is triggered. Use $args for simple arguments
    or @args for proper argument splatting (recommended).

.EXAMPLE
    .\New-Alias.ps1 -AliasName "play" -Command "ffplay --nodisp -autoexit `$args"

.EXAMPLE
    .\New-Alias.ps1 -AliasName "gs" -Command "git status"

.EXAMPLE
    .\New-Alias.ps1 -AliasName "dc" -Command "docker-compose @args"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$AliasName,
    
    [Parameter(Mandatory=$true)]
    [string]$Command
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get the CurrentUserAllHosts profile (works across all terminals)
$profilePath = $PROFILE.CurrentUserAllHosts

# Ensure profile directory exists
$profileDir = Split-Path -Path $profilePath -Parent
if (-not (Test-Path $profileDir)) {
    Write-Information "`e[33mCreating profile directory: $profileDir`e[0m"
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
}

# Backup existing profile
if (Test-Path $profilePath) {
    $backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Information "`e[36mBacking up profile to: $backupPath`e[0m"
    Copy-Item -Path $profilePath -Destination $backupPath -Force
}

# Read existing profile content
$profileContent = ""
if (Test-Path $profilePath) {
    $profileContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
}

# Check if alias/function already exists
$functionPattern = "(?ms)^function\s+$AliasName\s*\{.*?\n\}"
$aliasPattern = "(?ms)^(?:Set-Alias|New-Alias)\s+.*?-Name\s+['`"]?$AliasName['`"]?"

$existingMatch = $false
if ($profileContent -match $functionPattern -or $profileContent -match $aliasPattern) {
    $existingMatch = $true
    Write-Information "`e[33m⚠️  Alias '$AliasName' already exists in profile`e[0m"
    $response = Read-Host "Replace it? (y/n)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Information "`e[31m❌ Cancelled`e[0m"
        exit 0
    }
    
    # Remove existing function/alias
    $profileContent = $profileContent -replace $functionPattern, ''
    $profileContent = $profileContent -replace $aliasPattern, ''
    $profileContent = $profileContent.Trim()
}

# Create function definition
# Use a template with placeholder to avoid variable expansion issues
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$template = @'
##---------------------------------------
## Alias: {ALIAS_NAME}
## Created: {TIMESTAMP}
##---------------------------------------
function {ALIAS_NAME} {
    {COMMAND}
}
'@

$functionCode = $template -replace '{ALIAS_NAME}', $AliasName -replace '{TIMESTAMP}', $timestamp -replace '{COMMAND}', $Command

# Add function to profile
if ($existingMatch) {
    # Replace existing content
    if ([string]::IsNullOrWhiteSpace($profileContent)) {
        $newContent = $functionCode
    } else {
        $newContent = "$profileContent`n`n$functionCode"
    }
    $newContent | Out-File -FilePath $profilePath -Encoding UTF8 -NoNewline
} else {
    # Append to existing content
    if ([string]::IsNullOrWhiteSpace($profileContent)) {
        $functionCode | Out-File -FilePath $profilePath -Encoding UTF8 -NoNewline
    } else {
        Add-Content -Path $profilePath -Value "`n`n$functionCode" -Encoding UTF8
    }
}

Write-Information "`e[32m✅ Alias '$AliasName' added to PowerShell profile`e[0m"
Write-Information "`e[36mProfile location: $profilePath`e[0m"
Write-Information ""
Write-Information "`e[33m⚠️  IMPORTANT: Restart your terminal or open a new one for the alias to take effect.`e[0m"
Write-Information "`e[90m   DO NOT run '. `$PROFILE' - it will freeze your terminal.`e[0m"
