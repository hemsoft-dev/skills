#!/usr/bin/env pwsh
<#
.SYNOPSIS
Collects issues and pull requests from monitored GitHub repositories using GitHub CLI.

.DESCRIPTION
Queries all repositories in the repo-config.json configuration and collects issue
and pull request data using the GitHub API via gh CLI.

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
.\collect-repo-issues-prs.ps1

.EXAMPLE
.\collect-repo-issues-prs.ps1 -StartDate "2026-01-01" -EndDate "2026-01-31"

.EXAMPLE
.\collect-repo-issues-prs.ps1 -RepoName "relias-assistant"
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

Write-Information "Collecting issues and PRs from $($startDateTime.ToString('yyyy-MM-dd')) to $($endDateTime.ToString('yyyy-MM-dd'))" -InformationAction Continue

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

# Function to switch GitHub account if needed
function Switch-GitHubAccount {
    param([string]$RequiredAccount)
    
    if ([string]::IsNullOrEmpty($RequiredAccount)) {
        return $true
    }
    
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

# Collect data from each repository
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
        # Collect Pull Requests - opened, merged, or closed in date range
        Write-Information "  Collecting pull requests..." -InformationAction Continue
        
        $pullRequests = @()
        
        # Get PRs created in date range
        $prsCreated = gh api --paginate "repos/$fullRepo/pulls?state=all&sort=created&direction=desc&per_page=100" 2>&1
        if ($LASTEXITCODE -eq 0 -and $prsCreated) {
            $prsArray = $prsCreated | ConvertFrom-Json
            foreach ($pr in $prsArray) {
                $createdAt = [datetime]::Parse($pr.created_at)
                $mergedAt = if ($pr.merged_at) { [datetime]::Parse($pr.merged_at) } else { $null }
                $closedAt = if ($pr.closed_at) { [datetime]::Parse($pr.closed_at) } else { $null }
                
                # Check if PR activity falls within date range
                $inRange = $false
                $action = $null
                $actionDate = $null
                
                if ($createdAt -ge $startDateTime -and $createdAt -lt $endDateTime.AddDays(1)) {
                    $inRange = $true
                    $action = "opened"
                    $actionDate = $createdAt
                }
                elseif ($mergedAt -and $mergedAt -ge $startDateTime -and $mergedAt -lt $endDateTime.AddDays(1)) {
                    $inRange = $true
                    $action = "merged"
                    $actionDate = $mergedAt
                }
                elseif ($closedAt -and -not $mergedAt -and $closedAt -ge $startDateTime -and $closedAt -lt $endDateTime.AddDays(1)) {
                    $inRange = $true
                    $action = "closed"
                    $actionDate = $closedAt
                }
                
                if ($inRange) {
                    $pullRequests += [PSCustomObject]@{
                        number = $pr.number
                        title = $pr.title
                        author = $pr.user.login
                        state = $pr.state
                        action = $action
                        actionDate = $actionDate.ToString("yyyy-MM-dd")
                        actionDateTime = $actionDate.ToString("o")
                        createdAt = $pr.created_at
                        mergedAt = $pr.merged_at
                        closedAt = $pr.closed_at
                        url = $pr.html_url
                        additions = $pr.additions
                        deletions = $pr.deletions
                        changedFiles = $pr.changed_files
                        repository = $repoName
                        owner = $owner
                    }
                }
                
                # Stop if we've gone past the date range
                if ($createdAt -lt $startDateTime.AddMonths(-1)) {
                    break
                }
            }
        }
        
        Write-Information "    Found $($pullRequests.Count) PR activities" -InformationAction Continue
        
        # Collect Issues - opened or closed in date range
        Write-Information "  Collecting issues..." -InformationAction Continue
        
        $issues = @()
        
        $issuesCreated = gh api --paginate "repos/$fullRepo/issues?state=all&sort=created&direction=desc&per_page=100&filter=all" 2>&1
        if ($LASTEXITCODE -eq 0 -and $issuesCreated) {
            $issuesArray = $issuesCreated | ConvertFrom-Json
            foreach ($issue in $issuesArray) {
                # Skip pull requests (they appear in issues API too)
                if ($issue.pull_request) {
                    continue
                }
                
                $createdAt = [datetime]::Parse($issue.created_at)
                $closedAt = if ($issue.closed_at) { [datetime]::Parse($issue.closed_at) } else { $null }
                
                # Check if issue activity falls within date range
                $inRange = $false
                $action = $null
                $actionDate = $null
                
                if ($createdAt -ge $startDateTime -and $createdAt -lt $endDateTime.AddDays(1)) {
                    $inRange = $true
                    $action = "opened"
                    $actionDate = $createdAt
                }
                elseif ($closedAt -and $closedAt -ge $startDateTime -and $closedAt -lt $endDateTime.AddDays(1)) {
                    $inRange = $true
                    $action = "closed"
                    $actionDate = $closedAt
                }
                
                if ($inRange) {
                    $issues += [PSCustomObject]@{
                        number = $issue.number
                        title = $issue.title
                        author = $issue.user.login
                        state = $issue.state
                        action = $action
                        actionDate = $actionDate.ToString("yyyy-MM-dd")
                        actionDateTime = $actionDate.ToString("o")
                        createdAt = $issue.created_at
                        closedAt = $issue.closed_at
                        url = $issue.html_url
                        labels = ($issue.labels | ForEach-Object { $_.name }) -join ", "
                        repository = $repoName
                        owner = $owner
                    }
                }
                
                # Stop if we've gone past the date range
                if ($createdAt -lt $startDateTime.AddMonths(-1)) {
                    break
                }
            }
        }
        
        Write-Information "    Found $($issues.Count) issue activities" -InformationAction Continue
        
        # Save per-repo data to repo-specific subfolder
        $repoDataDir = Join-Path $OutputDir $repoName
        if (-not (Test-Path -Path $repoDataDir)) {
            New-Item -ItemType Directory -Path $repoDataDir -Force | Out-Null
        }
        
        # Group by actionDate and save separate files per day
        $prsByDate = $pullRequests | Group-Object -Property actionDate
        $issuesByDate = $issues | Group-Object -Property actionDate
        
        # Get all unique dates from both PRs and issues
        $allDates = @()
        $allDates += $prsByDate | ForEach-Object { $_.Name }
        $allDates += $issuesByDate | ForEach-Object { $_.Name }
        $allDates = $allDates | Sort-Object -Unique
        
        # Save a file for each date that has activity
        foreach ($date in $allDates) {
            $dayPRs = ($prsByDate | Where-Object { $_.Name -eq $date }).Group
            $dayIssues = ($issuesByDate | Where-Object { $_.Name -eq $date }).Group
            
            if (-not $dayPRs) { $dayPRs = @() }
            if (-not $dayIssues) { $dayIssues = @() }
            
            $outputData = @{
                collectionTime = (Get-Date).ToString("o")
                date = $date
                repository = $repoName
                owner = $owner
                url = $repo.url
                source = $repo.source
                summary = @{
                    totalPRs = $dayPRs.Count
                    prsOpened = ($dayPRs | Where-Object { $_.action -eq "opened" }).Count
                    prsMerged = ($dayPRs | Where-Object { $_.action -eq "merged" }).Count
                    prsClosed = ($dayPRs | Where-Object { $_.action -eq "closed" }).Count
                    totalIssues = $dayIssues.Count
                    issuesOpened = ($dayIssues | Where-Object { $_.action -eq "opened" }).Count
                    issuesClosed = ($dayIssues | Where-Object { $_.action -eq "closed" }).Count
                }
                pullRequests = $dayPRs
                issues = $dayIssues
            }
            
            $outputFile = Join-Path $repoDataDir "issues-prs-$date.json"
            $outputData | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8 -Force
            Write-Information "  Saved: $outputFile" -InformationAction Continue
        }
        
        if ($allDates.Count -eq 0) {
            Write-Information "  No PR or issue activity found in date range" -InformationAction Continue
        }
    }
    catch {
        Write-Warning "Error querying $fullRepo : $_"
        continue
    }
}

Write-Information "" -InformationAction Continue
Write-Information "=== Collection Complete ===" -InformationAction Continue
Write-Information "Data saved to: $OutputDir/<repo-name>/issues-prs-YYYY-MM-DD.json (one file per day with activity)" -InformationAction Continue
