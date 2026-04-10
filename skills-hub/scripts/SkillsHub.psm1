#!/usr/bin/env pwsh
<#
.SYNOPSIS
    SkillsHub - A package manager for AI agent skills.
.DESCRIPTION
    Browse, install, and manage AI agent skills from a central repository
    using Windows junction links. Skills stay current with a simple update command.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Configuration ---

$script:HubRoot = Join-Path $env:USERPROFILE '.skills-hub'
$script:ConfigPath = Join-Path $script:HubRoot 'config.json'
$script:DefaultRepoUrl = 'https://github.com/HemSoft/skills.git'
$script:DefaultInstallPath = Join-Path $env:USERPROFILE '.agents' 'skills'

function Get-HubConfig {
    [CmdletBinding()]
    param()

    if (-not (Test-Path $script:ConfigPath)) {
        return $null
    }
    Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
}

function Save-HubConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [PSCustomObject] $Config)

    if (-not (Test-Path $script:HubRoot)) {
        New-Item -ItemType Directory -Force -Path $script:HubRoot | Out-Null
    }
    $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $script:ConfigPath -Encoding UTF8
}

function Get-RepoPath {
    [CmdletBinding()]
    param()

    $cfg = Get-HubConfig
    if ($null -eq $cfg -or [string]::IsNullOrWhiteSpace($cfg.repoPath)) {
        Write-Error "SkillsHub is not initialised. Run Install-SkillsHub first."
        return $null
    }
    $cfg.repoPath
}

# --- Skill metadata helpers ---

function Read-SkillFrontmatter {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $SkillPath)

    $skillFile = Join-Path $SkillPath 'SKILL.md'
    if (-not (Test-Path $skillFile)) { return $null }

    $lines = Get-Content $skillFile -TotalCount 50
    $inFrontmatter = $false
    $name = ''
    $description = ''

    foreach ($line in $lines) {
        if ($line -match '^---\s*$') {
            if ($inFrontmatter) { break }
            $inFrontmatter = $true
            continue
        }
        if ($inFrontmatter) {
            if ($line -match '^\s*name:\s*(.+)$') { $name = $Matches[1].Trim().Trim('"', "'") }
            if ($line -match '^\s*description:\s*["\u0027]?(.+?)["\u0027]?\s*$') { $description = $Matches[1].Trim().Trim('"', "'") }
        }
    }

    [PSCustomObject]@{
        Name        = if ($name) { $name } else { Split-Path $SkillPath -Leaf }
        Description = $description
        Path        = $SkillPath
    }
}

function Get-AllRepoSkills {
    [CmdletBinding()]
    param()

    $repoPath = Get-RepoPath
    if (-not $repoPath) { return @() }

    $skills = @()
    foreach ($dir in (Get-ChildItem -Path $repoPath -Directory)) {
        # Skip hidden, underscore-prefixed, and meta directories
        if ($dir.Name.StartsWith('.') -or $dir.Name.StartsWith('_') -or $dir.Name -eq 'skills-hub') { continue }
        $skillFile = Join-Path $dir.FullName 'SKILL.md'
        if (Test-Path $skillFile) {
            $meta = Read-SkillFrontmatter -SkillPath $dir.FullName
            if ($meta) { $skills += $meta }
        }
    }
    $skills | Sort-Object Name
}

# --- Public commands ---

function Install-SkillsHub {
    <#
    .SYNOPSIS
        One-time setup: clones the skills repo and configures SkillsHub.
    .PARAMETER RepoUrl
        Git clone URL. Defaults to HemSoft/skills.
    .PARAMETER RepoPath
        Local path to clone into. Defaults to ~/.skills-hub/repo.
    .PARAMETER SkillsPath
        Where skills get linked. Defaults to ~/.agents/skills.
    #>
    [CmdletBinding()]
    param(
        [string] $RepoUrl = $script:DefaultRepoUrl,
        [string] $RepoPath = (Join-Path $script:HubRoot 'repo'),
        [string] $SkillsPath = $script:DefaultInstallPath
    )

    Write-Information "`e[36m┌──────────────────────────────────────┐`e[0m"
    Write-Information "`e[36m│       SkillsHub - First-Time Setup   │`e[0m"
    Write-Information "`e[36m└──────────────────────────────────────┘`e[0m"

    # Clone or detect existing repo
    if (Test-Path (Join-Path $RepoPath '.git')) {
        Write-Information "`e[33m⚡ Repo already cloned at $RepoPath`e[0m"
    }
    else {
        Write-Information "`e[36mCloning $RepoUrl ...`e[0m"
        if (-not (Test-Path $RepoPath)) {
            New-Item -ItemType Directory -Force -Path $RepoPath | Out-Null
        }
        git clone $RepoUrl $RepoPath 2>&1 | ForEach-Object { Write-Information "  $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "git clone failed (exit code $LASTEXITCODE)."
            return
        }
    }

    # Ensure skills target directory exists
    if (-not (Test-Path $SkillsPath)) {
        New-Item -ItemType Directory -Force -Path $SkillsPath | Out-Null
    }

    # Save config
    $config = [PSCustomObject]@{
        repoUrl    = $RepoUrl
        repoPath   = $RepoPath
        skillsPath = $SkillsPath
        installedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    }
    Save-HubConfig -Config $config

    Write-Information "`e[32m✅ SkillsHub configured`e[0m"
    Write-Information "   Repo:   $RepoPath"
    Write-Information "   Target: $SkillsPath"
    Write-Information ""
    Write-Information "`e[36mNext steps:`e[0m"
    Write-Information "   skills-hub list            # Browse available skills"
    Write-Information "   skills-hub install <name>   # Install a skill"
}

function Get-AvailableSkill {
    <#
    .SYNOPSIS
        Lists all available skills from the repo with descriptions.
    #>
    [CmdletBinding()]
    param()

    $skills = Get-AllRepoSkills
    if ($skills.Count -eq 0) {
        Write-Information "`e[33mNo skills found. Run Install-SkillsHub first.`e[0m"
        return
    }

    $cfg = Get-HubConfig
    $installed = @{}
    if ($cfg -and $cfg.skillsPath -and (Test-Path $cfg.skillsPath)) {
        foreach ($item in (Get-ChildItem -Path $cfg.skillsPath -Directory -ErrorAction SilentlyContinue)) {
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                $installed[$item.Name] = $true
            }
        }
    }

    Write-Information ""
    Write-Information "`e[36m Available Skills ($($skills.Count) total)`e[0m"
    Write-Information "`e[90m─────────────────────────────────────────────────────────`e[0m"

    foreach ($s in $skills) {
        $marker = if ($installed.ContainsKey($s.Name)) { "`e[32m●`e[0m" } else { "`e[90m○`e[0m" }
        $nameDisplay = "`e[97m$($s.Name)`e[0m"
        $descDisplay = if ($s.Description) { "`e[90m- $($s.Description)`e[0m" } else { '' }
        Write-Information "  $marker $nameDisplay $descDisplay"
    }
    Write-Information ""
    Write-Information "`e[90m● installed  ○ available`e[0m"
}

function Find-Skill {
    <#
    .SYNOPSIS
        Searches skills by keyword in name or description.
    .PARAMETER Query
        Search term.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Query)

    $skills = Get-AllRepoSkills
    $lowerQuery = $Query.ToLower()
    $found = $skills | Where-Object {
        $_.Name.ToLower().Contains($lowerQuery) -or $_.Description.ToLower().Contains($lowerQuery)
    }

    if ($found.Count -eq 0) {
        Write-Information "`e[33mNo skills match '$Query'.`e[0m"
        return
    }

    $cfg = Get-HubConfig
    $installed = @{}
    if ($cfg -and $cfg.skillsPath -and (Test-Path $cfg.skillsPath)) {
        foreach ($item in (Get-ChildItem -Path $cfg.skillsPath -Directory -ErrorAction SilentlyContinue)) {
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                $installed[$item.Name] = $true
            }
        }
    }

    Write-Information ""
    Write-Information "`e[36m Search results for '$Query' ($($found.Count) found)`e[0m"
    Write-Information "`e[90m────────────────────────────────────────────`e[0m"
    foreach ($s in $found) {
        $marker = if ($installed.ContainsKey($s.Name)) { "`e[32m●`e[0m" } else { "`e[90m○`e[0m" }
        $nameDisplay = "`e[97m$($s.Name)`e[0m"
        $descDisplay = if ($s.Description) { "`e[90m- $($s.Description)`e[0m" } else { '' }
        Write-Information "  $marker $nameDisplay $descDisplay"
    }
    Write-Information ""
}

function Install-Skill {
    <#
    .SYNOPSIS
        Installs one or more skills by creating junction links.
    .PARAMETER Name
        Skill name(s) to install.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromRemainingArguments)] [string[]] $Name)

    $cfg = Get-HubConfig
    if (-not $cfg) { Write-Error "Run Install-SkillsHub first."; return }

    $repoPath = $cfg.repoPath
    $targetPath = $cfg.skillsPath

    foreach ($skill in $Name) {
        if ($skill -match '[\\/ ]|\.\.' ) {
            Write-Information "`e[31m✗ Invalid skill name '$skill'. Names cannot contain path separators or '..'`e[0m"
            continue
        }

        $sourcePath = Join-Path $repoPath $skill
        $linkPath = Join-Path $targetPath $skill

        if (-not (Test-Path $sourcePath -PathType Container) -or -not (Test-Path (Join-Path $sourcePath 'SKILL.md'))) {
            Write-Information "`e[31m✗ '$skill' not found in repo. Use 'skills-hub list' to see available skills.`e[0m"
            continue
        }

        if (Test-Path $linkPath) {
            $item = Get-Item $linkPath -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-Information "`e[33m⚡ '$skill' is already installed (junction exists).`e[0m"
            }
            else {
                Write-Information "`e[31m✗ '$skill' exists as a regular directory at $linkPath. Remove it first to install as a link.`e[0m"
            }
            continue
        }

        New-Item -ItemType Junction -Path $linkPath -Target $sourcePath | Out-Null
        Write-Information "`e[32m✓ Installed '$skill'`e[0m"
    }
}

function Uninstall-Skill {
    <#
    .SYNOPSIS
        Removes junction links for one or more skills.
    .PARAMETER Name
        Skill name(s) to remove.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromRemainingArguments)] [string[]] $Name)

    $cfg = Get-HubConfig
    if (-not $cfg) { Write-Error "Run Install-SkillsHub first."; return }

    foreach ($skill in $Name) {
        if ($skill -match '[\\/ ]|\.\.' ) {
            Write-Information "`e[31m✗ Invalid skill name '$skill'.`e[0m"
            continue
        }

        $linkPath = Join-Path $cfg.skillsPath $skill

        if (-not (Test-Path $linkPath)) {
            Write-Information "`e[33m'$skill' is not installed.`e[0m"
            continue
        }

        try {
            $item = Get-Item $linkPath -Force
            if (-not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                Write-Information "`e[31m✗ '$skill' is a regular directory, not a junction. Skipping to avoid data loss.`e[0m"
                continue
            }

            $item.Delete()
            Write-Information "`e[32m✓ Uninstalled '$skill'`e[0m"
        }
        catch {
            Write-Warning "Failed to uninstall '$skill': $_"
        }
    }
}

function Update-SkillsHub {
    <#
    .SYNOPSIS
        Pulls latest changes from the skills repo. All linked skills update instantly.
    #>
    [CmdletBinding()]
    param()

    $repoPath = Get-RepoPath
    if (-not $repoPath) { return }

    Write-Information "`e[36mUpdating skills repo...`e[0m"
    Push-Location $repoPath
    try {
        $gitOutput = git pull 2>&1
        $gitExitCode = $LASTEXITCODE
        $gitOutput | ForEach-Object { Write-Information "  $_" }
        if ($gitExitCode -ne 0) {
            Write-Error "git pull failed (exit code $gitExitCode)."
        }
        else {
            Write-Information "`e[32m✅ Skills repo updated. All linked skills are now current.`e[0m"
        }
    }
    finally {
        Pop-Location
    }
}

function Get-InstalledSkill {
    <#
    .SYNOPSIS
        Shows currently installed (junction-linked) skills.
    #>
    [CmdletBinding()]
    param()

    $cfg = Get-HubConfig
    if (-not $cfg) { Write-Error "Run Install-SkillsHub first."; return }

    $junctions = @()
    foreach ($item in (Get-ChildItem -Path $cfg.skillsPath -Directory -ErrorAction SilentlyContinue)) {
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $target = $item.Target
            if (-not $target) {
                # Fallback for older PS versions
                $target = (Get-Item $item.FullName).Target
            }
            $meta = Read-SkillFrontmatter -SkillPath $item.FullName
            $junctions += [PSCustomObject]@{
                Name        = $item.Name
                Description = if ($meta) { $meta.Description } else { '' }
                Target      = $target
            }
        }
    }

    if ($junctions.Count -eq 0) {
        Write-Information "`e[33mNo skills installed via junction links.`e[0m"
        return
    }

    Write-Information ""
    Write-Information "`e[36m Installed Skills ($($junctions.Count))`e[0m"
    Write-Information "`e[90m────────────────────────────────────────────`e[0m"
    foreach ($j in ($junctions | Sort-Object Name)) {
        $descDisplay = if ($j.Description) { "`e[90m- $($j.Description)`e[0m" } else { '' }
        Write-Information "  `e[32m●`e[0m `e[97m$($j.Name)`e[0m $descDisplay"
    }
    Write-Information ""
}

function Get-SkillsHubStatus {
    <#
    .SYNOPSIS
        Shows an overview: installed count, available count, repo freshness.
    #>
    [CmdletBinding()]
    param()

    $cfg = Get-HubConfig
    if (-not $cfg) {
        Write-Information "`e[33mSkillsHub is not configured. Run Install-SkillsHub first.`e[0m"
        return
    }

    $allSkills = Get-AllRepoSkills
    $installedCount = 0
    if (Test-Path $cfg.skillsPath) {
        foreach ($item in (Get-ChildItem -Path $cfg.skillsPath -Directory -ErrorAction SilentlyContinue)) {
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                $installedCount++
            }
        }
    }

    # Get last commit date from repo
    $lastUpdate = ''
    if (Test-Path $cfg.repoPath) {
        Push-Location $cfg.repoPath
        try {
            $lastUpdate = git log -1 --format="%ci" 2>$null
        }
        finally {
            Pop-Location
        }
    }

    Write-Information ""
    Write-Information "`e[36m SkillsHub Status`e[0m"
    Write-Information "`e[90m────────────────────────────────────────────`e[0m"
    Write-Information "  Repo:        $($cfg.repoPath)"
    Write-Information "  Target:      $($cfg.skillsPath)"
    Write-Information "  Available:   $($allSkills.Count) skills"
    Write-Information "  Installed:   $installedCount (junction-linked)"
    if ($lastUpdate) {
        Write-Information "  Last commit: $lastUpdate"
    }
    Write-Information ""
}

# --- Convenience dispatcher ---

function Invoke-SkillsHub {
    <#
    .SYNOPSIS
        Main entry point: skills-hub <command> [args]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $Command,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]] $Arguments
    )

    switch ($Command) {
        'list'      { Get-AvailableSkill }
        'find'      {
            if (-not $Arguments -or $Arguments.Count -eq 0) {
                Write-Information "Usage: skills-hub find <query>"
                return
            }
            Find-Skill -Query ($Arguments -join ' ')
        }
        'install'   {
            if (-not $Arguments -or $Arguments.Count -eq 0) {
                Write-Information "Usage: skills-hub install <skill-name> [<skill-name> ...]"
                return
            }
            Install-Skill -Name $Arguments
        }
        'uninstall' {
            if (-not $Arguments -or $Arguments.Count -eq 0) {
                Write-Information "Usage: skills-hub uninstall <skill-name> [<skill-name> ...]"
                return
            }
            Uninstall-Skill -Name $Arguments
        }
        'installed' { Get-InstalledSkill }
        'update'    { Update-SkillsHub }
        'status'    { Get-SkillsHubStatus }
        'setup'     {
            if ($Arguments -and $Arguments.Count -ge 1) {
                Install-SkillsHub -RepoUrl $Arguments[0]
            }
            else {
                Install-SkillsHub
            }
        }
        default {
            Write-Information ""
            Write-Information "`e[36m SkillsHub`e[0m - AI Skills Package Manager"
            Write-Information ""
            Write-Information "`e[97m Commands:`e[0m"
            Write-Information "   skills-hub setup              First-time setup (clone repo)"
            Write-Information "   skills-hub list               Browse all available skills"
            Write-Information "   skills-hub find <query>       Search skills by keyword"
            Write-Information "   skills-hub install <name>     Install skill(s) via junction link"
            Write-Information "   skills-hub uninstall <name>   Remove skill junction(s)"
            Write-Information "   skills-hub installed          Show installed skills"
            Write-Information "   skills-hub update             Pull latest from repo"
            Write-Information "   skills-hub status             Overview and repo freshness"
            Write-Information ""
        }
    }
}

# --- Exports ---

Export-ModuleMember -Function @(
    'Install-SkillsHub',
    'Get-AvailableSkill',
    'Find-Skill',
    'Install-Skill',
    'Uninstall-Skill',
    'Update-SkillsHub',
    'Get-InstalledSkill',
    'Get-SkillsHubStatus',
    'Invoke-SkillsHub'
)
