#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-time bootstrap installer for SkillsHub.
.DESCRIPTION
    Clones the skills repo, copies the module, and adds 'skills-hub' function
    to the user's PowerShell profile.
.PARAMETER RepoUrl
    Git clone URL for the skills repo. Defaults to HemSoft/skills.
.PARAMETER UseExisting
    Path to an already-cloned skills repo instead of cloning a new copy.
.EXAMPLE
    # Remote install (one-liner):
    irm https://raw.githubusercontent.com/HemSoft/skills/main/skills-hub/scripts/Install-SkillsHub.ps1 | iex

    # Point at an existing local clone:
    .\Install-SkillsHub.ps1 -UseExisting "C:\Users\User\.agents\skills"
#>

[CmdletBinding()]
param(
    [string] $RepoUrl = 'https://github.com/HemSoft/skills.git',
    [string] $UseExisting = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$HubRoot    = Join-Path $env:USERPROFILE '.skills-hub'
$ConfigPath = Join-Path $HubRoot 'config.json'
$ModuleDest = Join-Path $HubRoot 'SkillsHub.psm1'
$SkillsPath = Join-Path $env:USERPROFILE '.agents' 'skills'

Write-Information ""
Write-Information "`e[36m┌───────────────────────────────────────────┐`e[0m"
Write-Information "`e[36m│    SkillsHub Installer                    │`e[0m"
Write-Information "`e[36m│    AI Skills Package Manager              │`e[0m"
Write-Information "`e[36m└───────────────────────────────────────────┘`e[0m"
Write-Information ""

# 1. Determine repo path
if ($UseExisting -and (Test-Path (Join-Path $UseExisting '.git'))) {
    $RepoPath = (Resolve-Path $UseExisting).Path
    Write-Information "`e[32m✓`e[0m Using existing repo at $RepoPath"
}
else {
    $RepoPath = Join-Path $HubRoot 'repo'
    if (Test-Path (Join-Path $RepoPath '.git')) {
        Write-Information "`e[33m⚡`e[0m Repo already cloned at $RepoPath"
    }
    else {
        Write-Information "`e[36m⬇`e[0m Cloning $RepoUrl ..."
        if (-not (Test-Path $RepoPath)) {
            New-Item -ItemType Directory -Force -Path $RepoPath | Out-Null
        }
        git clone "$RepoUrl" "$RepoPath" 2>&1 | ForEach-Object { Write-Information "   $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "git clone failed."
            return
        }
        Write-Information "`e[32m✓`e[0m Cloned successfully"
    }
}

# 2. Copy module to hub directory
if (-not (Test-Path $HubRoot)) {
    New-Item -ItemType Directory -Force -Path $HubRoot | Out-Null
}

$moduleSource = Join-Path $RepoPath 'skills-hub' 'scripts' 'SkillsHub.psm1'
if (Test-Path $moduleSource) {
    Copy-Item -Path $moduleSource -Destination $ModuleDest -Force
    Write-Information "`e[32m✓`e[0m Module copied to $ModuleDest"
}
else {
    Write-Error "Cannot find SkillsHub.psm1 at $moduleSource"
    return
}

# 3. Save config
if (-not (Test-Path $SkillsPath)) {
    New-Item -ItemType Directory -Force -Path $SkillsPath | Out-Null
}

$config = @{
    repoUrl     = $RepoUrl
    repoPath    = $RepoPath
    skillsPath  = $SkillsPath
    installedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
} | ConvertTo-Json -Depth 5

Set-Content -Path $ConfigPath -Value $config -Encoding UTF8
Write-Information "`e[32m✓`e[0m Config saved to $ConfigPath"

# 4. Add skills-hub function to PowerShell profile
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir  = Split-Path $profilePath -Parent

if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}

$markerStart = '##--- SkillsHub BEGIN ---##'
$markerEnd   = '##--- SkillsHub END ---##'

$profileBlock = @"

$markerStart
Import-Module "`$env:USERPROFILE\.skills-hub\SkillsHub.psm1" -Force -ErrorAction SilentlyContinue
function skills-hub { Invoke-SkillsHub @args }
$markerEnd
"@

$existingContent = ''
if (Test-Path $profilePath) {
    $existingContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
}

if ($existingContent -and $existingContent.Contains($markerStart)) {
    # Replace existing block
    $pattern = "(?s)$([regex]::Escape($markerStart)).*?$([regex]::Escape($markerEnd))"
    $replacement = "$markerStart`nImport-Module `"`$env:USERPROFILE\.skills-hub\SkillsHub.psm1`" -Force -ErrorAction SilentlyContinue`nfunction skills-hub { Invoke-SkillsHub @args }`n$markerEnd"
    $newContent = [regex]::Replace($existingContent, $pattern, $replacement)
    Set-Content -Path $profilePath -Value $newContent -Encoding UTF8 -NoNewline
    Write-Information "`e[32m✓`e[0m Updated existing profile block"
}
else {
    Add-Content -Path $profilePath -Value $profileBlock -Encoding UTF8
    Write-Information "`e[32m✓`e[0m Added skills-hub to PowerShell profile"
}

Write-Information ""
Write-Information "`e[32m┌───────────────────────────────────────────┐`e[0m"
Write-Information "`e[32m│    Installation Complete!                  │`e[0m"
Write-Information "`e[32m└───────────────────────────────────────────┘`e[0m"
Write-Information ""
Write-Information "  Open a `e[97mnew terminal`e[0m, then:"
Write-Information ""
Write-Information "    `e[97mskills-hub`e[0m                  Show help"
Write-Information "    `e[97mskills-hub list`e[0m             Browse all skills"
Write-Information "    `e[97mskills-hub find testing`e[0m     Search by keyword"
Write-Information "    `e[97mskills-hub install <name>`e[0m   Install a skill"
Write-Information "    `e[97mskills-hub update`e[0m           Pull latest changes"
Write-Information ""
