#!/usr/bin/env pwsh
<#
.SYNOPSIS
Updates the daily-code configuration by scanning GitHub repository directories.

.DESCRIPTION
Scans specified GitHub repository folders and generates a configuration JSON file
listing all discovered repositories. This configuration is used by data collection
scripts to know which repositories to analyze for productivity metrics.

.PARAMETER RepositoryPaths
Array of root directories containing GitHub repositories to scan.

.PARAMETER ConfigPath
Output path for the generated configuration JSON file.

.EXAMPLE
.\update-configuration.ps1

.EXAMPLE
.\update-configuration.ps1 -RepositoryPaths @("D:\github\hemsoft", "D:\github\relias") -ConfigPath "./daily-code-config.json"
#>

param(
    [string[]]$RepositoryPaths = @("D:\github\hemsoft", "D:\github\relias"),
    [string[]]$AdditionalRepositories = @("c:\Users\User\.claude\skills"),
    [string]$ConfigPath = "$PSScriptRoot\..\config\daily-code-config.json"
)

# Ensure config directory exists
$ConfigDir = Split-Path -Path $ConfigPath -Parent
if (-not (Test-Path -Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    Write-Information "Created config directory: $ConfigDir" -InformationAction Continue
}

# Discover repositories
$repositories = @()

$workTreeRepos = @()

foreach ($basePath in $RepositoryPaths) {
    if (-not (Test-Path -Path $basePath)) {
        Write-Warning "Repository path not found: $basePath"
        continue
    }

    Write-Information "Scanning: $basePath" -InformationAction Continue
    
    # Only scan top-level directories (not recursive)
    $topLevelDirs = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue
    
    foreach ($dir in $topLevelDirs) {
        $gitPath = Join-Path $dir.FullName ".git"
        
        if (Test-Path -Path $gitPath) {
            # Get the item without throwing errors for hidden files
            $gitItem = Get-Item -Path $gitPath -Force -ErrorAction SilentlyContinue
            
            if ($gitItem -and $gitItem.PSIsContainer -eq $false) {
                # .git is a file, likely a worktree
                $workTreeRepos += @{
                    name = $dir.Name
                    path = $dir.FullName
                    source = if ($basePath -match "hemsoft") { "personal" } else { "work" }
                }
                Write-Warning "Worktree detected: $($dir.Name) at $($dir.FullName)"
            }
            else {
                # Regular repository
                $repoInfo = @{
                    name = $dir.Name
                    path = $dir.FullName
                    source = if ($basePath -match "hemsoft") { "personal" } else { "work" }
                }
                $repositories += $repoInfo
                Write-Information "Found repository: $($dir.Name)" -InformationAction Continue
            }
        }
    }
}

# Add additional repositories (not from scan paths)
foreach ($repoPath in $AdditionalRepositories) {
    if (Test-Path -Path $repoPath) {
        $gitPath = Join-Path $repoPath ".git"
        
        if (Test-Path -Path $gitPath) {
            $repoInfo = @{
                name = Split-Path -Leaf $repoPath
                path = $repoPath
                source = "skills"
            }
            $repositories += $repoInfo
            Write-Information "Added additional repository: $(Split-Path -Leaf $repoPath)" -InformationAction Continue
        }
    }
    else {
        Write-Warning "Additional repository path not found: $repoPath"
    }
}

# Build configuration object
$config = @{
    version = "1.0"
    lastUpdated = (Get-Date -Format "o")
    repositoryCount = $repositories.Count
    repositories = $repositories
    metadata = @{
        description = "Configuration for daily-code productivity metrics"
        fileTypes = @(".js", ".ts", ".py", ".cs", ".ps1", ".go", ".rs", ".java", ".cpp", ".c", ".rb", ".php", ".swift", ".kt")
        excludePatterns = @("node_modules", "dist", "build", ".git", "*.min.js", "*.min.css", "generated", "build", "target")
    }
}

# Write configuration to JSON
$config | ConvertTo-Json -Depth 3 | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force

Write-Information "Configuration updated: $ConfigPath" -InformationAction Continue
Write-Information "Total repositories found: $($repositories.Count)" -InformationAction Continue

if ($workTreeRepos.Count -gt 0) {
    Write-Warning "⚠️  Git worktrees detected: $($workTreeRepos.Count)"
    Write-Warning "Worktrees are NOT included in configuration. Remove or convert these:"
    foreach ($worktree in $workTreeRepos) {
        Write-Warning "  - $($worktree.name) at $($worktree.path)"
    }
}

Write-Output $config | ConvertTo-Json
