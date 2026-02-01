#!/usr/bin/env pwsh
<#
.SYNOPSIS
Collects commit data from monitored GitHub repositories using GitHub CLI.

.DESCRIPTION
Queries all repositories in the repo-config.json configuration and collects commit
data using the GitHub API via gh CLI. Includes ALL commits regardless of author.

.PARAMETER StartDate
Start date for the query range (defaults to 7 days ago).
Format: "YYYY-MM-DD"

.PARAMETER EndDate
End date for the query range (defaults to today).
Format: "YYYY-MM-DD"

.PARAMETER RepoName
Optional: Query only a specific repository by name.

.PARAMETER ConfigPath
Path to the repo-config.json file.

.PARAMETER OutputDir
Directory where collected data will be stored.

.EXAMPLE
.\collect-repo-commits.ps1

.EXAMPLE
.\collect-repo-commits.ps1 -StartDate "2026-01-25" -EndDate "2026-02-01"

.EXAMPLE
.\collect-repo-commits.ps1 -RepoName "relias-assistant"
#>

param(
    [string]$StartDate,
    [string]$EndDate,
    [string]$RepoName,
    [string]$ConfigPath = "$PSScriptRoot\..\config\repo-config.json",
    [string]$OutputDir = "$PSScriptRoot\..\data"
)

# Set default dates if not specified
$now = Get-Date
$today = $now.Date

if (-not $StartDate) {
    $startDateTime = $today.AddDays(-7)
}
else {
    try {
        $startDateTime = [datetime]::ParseExact($StartDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        Write-Error "Invalid StartDate format: $StartDate (use 'yyyy-MM-dd')"
        exit 1
    }
}

if (-not $EndDate) {
    $endDateTime = $today
}
else {
    try {
        $endDateTime = [datetime]::ParseExact($EndDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        Write-Error "Invalid EndDate format: $EndDate (use 'yyyy-MM-dd')"
        exit 1
    }
}

Write-Information "Collecting commits from $($startDateTime.ToString('yyyy-MM-dd')) to $($endDateTime.ToString('yyyy-MM-dd'))" -InformationAction Continue

# Ensure output directory exists
if (-not (Test-Path -Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Load configuration
if (-not (Test-Path -Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

$config = Get-Content -Path $ConfigPath | ConvertFrom-Json

# Filter to specific repo if requested
$reposToProcess = $config.repositories | Where-Object { $_.enabled -eq $true }
if ($RepoName) {
    $reposToProcess = $reposToProcess | Where-Object { $_.name -eq $RepoName }
    if ($reposToProcess.Count -eq 0) {
        Write-Error "Repository not found in configuration: $RepoName"
        exit 1
    }
}

Write-Information "Processing $($reposToProcess.Count) repository(ies)" -InformationAction Continue

# Check if gh CLI is available
$ghPath = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghPath) {
    Write-Error "GitHub CLI (gh) is not installed or not in PATH"
    exit 1
}

# Check authentication status
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub CLI is not authenticated. Run 'gh auth login' first."
    exit 1
}

# Function to switch GitHub account if needed
# See github skill for account structure: ~/.claude/skills/github/SKILL.md
function Switch-GitHubAccount {
    param([string]$RequiredAccount)
    
    if ([string]::IsNullOrEmpty($RequiredAccount)) {
        return $true
    }
    
    # Get current active account
    $currentStatus = gh auth status 2>&1 | Out-String
    $activeMatch = [regex]::Match($currentStatus, "Logged in to github.com account (\w+).*Active account: true", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    if ($activeMatch.Success) {
        $currentAccount = $activeMatch.Groups[1].Value
        if ($currentAccount -eq $RequiredAccount) {
            return $true
        }
    }
    
    Write-Information "  Switching to GitHub account: $RequiredAccount" -InformationAction Continue
    $switchResult = gh auth switch -u $RequiredAccount 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to switch to account $RequiredAccount : $switchResult"
        return $false
    }
    return $true
}

# Collect commits from each repository
$allResults = @()

foreach ($repo in $reposToProcess) {
    $owner = $repo.owner
    $repoName = $repo.name
    $fullRepo = "$owner/$repoName"
    
    Write-Information "Querying: $fullRepo" -InformationAction Continue
    
    # Switch to required GitHub account if specified
    if ($repo.account) {
        $switched = Switch-GitHubAccount -RequiredAccount $repo.account
        if (-not $switched) {
            Write-Warning "Skipping $fullRepo - could not switch to account $($repo.account)"
            continue
        }
    }
    
    try {
        # Use gh api to get commits with pagination
        # GitHub API format: since/until are ISO 8601 timestamps
        $sinceISO = $startDateTime.ToString("yyyy-MM-ddT00:00:00Z")
        $untilISO = $endDateTime.AddDays(1).ToString("yyyy-MM-ddT00:00:00Z")
        
        # Query commits using gh api - get full JSON and process in PowerShell
        # (jq filters don't work reliably with PowerShell output capture)
        $rawCommits = gh api --paginate "repos/$fullRepo/commits?since=$sinceISO&until=$untilISO&per_page=100" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to query $fullRepo : $rawCommits"
            continue
        }
        
        # Parse JSON output
        $commitObjects = @()
        if ($rawCommits) {
            $commitsArray = $rawCommits | ConvertFrom-Json
            foreach ($commit in $commitsArray) {
                $commitObj = [PSCustomObject]@{
                    sha = $commit.sha
                    author = $commit.commit.author.name
                    authorEmail = $commit.commit.author.email
                    date = $commit.commit.author.date
                    message = $commit.commit.message
                    url = $commit.html_url
                    repository = $repoName
                    owner = $owner
                    source = $repo.source
                }
                
                # Get additional commit stats (additions/deletions)
                $commitDetails = gh api "repos/$fullRepo/commits/$($commit.sha)" 2>&1
                
                if ($LASTEXITCODE -eq 0 -and $commitDetails) {
                    $details = $commitDetails | ConvertFrom-Json
                    $commitObj | Add-Member -NotePropertyName "additions" -NotePropertyValue ($details.stats.additions ?? 0)
                    $commitObj | Add-Member -NotePropertyName "deletions" -NotePropertyValue ($details.stats.deletions ?? 0)
                    $commitObj | Add-Member -NotePropertyName "filesChanged" -NotePropertyValue ($details.files.Count ?? 0)
                    $commitObj | Add-Member -NotePropertyName "netLOC" -NotePropertyValue (($details.stats.additions ?? 0) - ($details.stats.deletions ?? 0))
                }
                else {
                    $commitObj | Add-Member -NotePropertyName "additions" -NotePropertyValue 0
                    $commitObj | Add-Member -NotePropertyName "deletions" -NotePropertyValue 0
                    $commitObj | Add-Member -NotePropertyName "filesChanged" -NotePropertyValue 0
                    $commitObj | Add-Member -NotePropertyName "netLOC" -NotePropertyValue 0
                }
                
                $commitObjects += $commitObj
            }
        }
        
        Write-Information "  Found $($commitObjects.Count) commits in $fullRepo" -InformationAction Continue
        
        # Save per-repo data to repo-specific subfolder
        $repoDataDir = Join-Path $OutputDir $repoName
        if (-not (Test-Path -Path $repoDataDir)) {
            New-Item -ItemType Directory -Path $repoDataDir -Force | Out-Null
        }
        
        $repoOutputData = @{
            collectionTime = (Get-Date).ToString("o")
            queryStartTime = $startDateTime.ToString("o")
            queryEndTime = $endDateTime.AddDays(1).AddSeconds(-1).ToString("o")
            queryStartTimeLocal = $startDateTime.ToString("yyyy-MM-dd HH:mm:ss")
            queryEndTimeLocal = $endDateTime.AddDays(1).AddSeconds(-1).ToString("yyyy-MM-dd HH:mm:ss")
            repository = $repoName
            owner = $owner
            url = $repo.url
            source = $repo.source
            commitsFound = $commitObjects.Count
            summary = @{
                totalAdditions = ($commitObjects | Measure-Object -Property additions -Sum).Sum
                totalDeletions = ($commitObjects | Measure-Object -Property deletions -Sum).Sum
                totalLinesAffected = (($commitObjects | Measure-Object -Property additions -Sum).Sum + ($commitObjects | Measure-Object -Property deletions -Sum).Sum)
                totalNetLOC = ($commitObjects | Measure-Object -Property netLOC -Sum).Sum
            }
            commits = $commitObjects
        }
        
        $repoOutputFile = Join-Path $repoDataDir "commits-$($startDateTime.ToString('yyyy-MM-dd')).json"
        $repoOutputData | ConvertTo-Json -Depth 10 | Out-File -FilePath $repoOutputFile -Encoding UTF8 -Force
        Write-Information "  Saved: $repoOutputFile" -InformationAction Continue
        
        # Add commits to all results for summary
        foreach ($commit in $commitObjects) {
            $allResults += $commit
        }
    }
    catch {
        Write-Warning "Error querying $fullRepo : $_"
        continue
    }
}

# Build combined summary (optional - for cross-repo views)
$commitsByRepo = $allResults | Group-Object -Property repository
$repoSummaries = @()
foreach ($group in $commitsByRepo) {
    $repoSummaries += @{
        repository = $group.Name
        commits = $group.Count
        additions = ($group.Group | Measure-Object -Property additions -Sum).Sum
        deletions = ($group.Group | Measure-Object -Property deletions -Sum).Sum
        linesAffected = (($group.Group | Measure-Object -Property additions -Sum).Sum + ($group.Group | Measure-Object -Property deletions -Sum).Sum)
        netLOC = ($group.Group | Measure-Object -Property netLOC -Sum).Sum
    }
}

$outputData = @{
    collectionTime = (Get-Date).ToString("o")
    queryStartTime = $startDateTime.ToString("o")
    queryEndTime = $endDateTime.AddDays(1).AddSeconds(-1).ToString("o")
    queryStartTimeLocal = $startDateTime.ToString("yyyy-MM-dd HH:mm:ss")
    queryEndTimeLocal = $endDateTime.AddDays(1).AddSeconds(-1).ToString("yyyy-MM-dd HH:mm:ss")
    repositoriesQueried = ($reposToProcess | Measure-Object).Count
    commitsFound = $allResults.Count
    summary = @{
        totalAdditions = ($allResults | Measure-Object -Property additions -Sum).Sum
        totalDeletions = ($allResults | Measure-Object -Property deletions -Sum).Sum
        totalLinesAffected = (($allResults | Measure-Object -Property additions -Sum).Sum + ($allResults | Measure-Object -Property deletions -Sum).Sum)
        totalNetLOC = ($allResults | Measure-Object -Property netLOC -Sum).Sum
        commitsByRepository = $repoSummaries
    }
}

Write-Information "" -InformationAction Continue
Write-Information "=== Collection Summary ===" -InformationAction Continue
Write-Information "Repositories Queried: $($outputData.repositoriesQueried)" -InformationAction Continue
Write-Information "Total Commits: $($outputData.commitsFound)" -InformationAction Continue
Write-Information "Total Additions: $($outputData.summary.totalAdditions)" -InformationAction Continue
Write-Information "Total Deletions: $($outputData.summary.totalDeletions)" -InformationAction Continue
Write-Information "Total Net LOC: $($outputData.summary.totalNetLOC)" -InformationAction Continue
Write-Information "Data saved to: $OutputDir/<repo-name>/commits-YYYY-MM-DD.json" -InformationAction Continue

# Output summary for pipeline
$outputData
