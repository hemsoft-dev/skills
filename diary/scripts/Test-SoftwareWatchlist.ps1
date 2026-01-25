#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the software watchlist checking process and reports diagnostics.

.DESCRIPTION
    Analyzes the config/software-watchlist.json to identify potential issues with the checking process.
    Reports on last check dates, identifies stale entries, and optionally runs actual checks.

.PARAMETER RunActualChecks
    If specified, runs actual version checks for items using github_releases method.

.PARAMETER DaysThreshold
    Number of days since last check to flag as potentially stale (default: 7).

.EXAMPLE
    .\Test-SoftwareWatchlist.ps1
    Shows diagnostic information without running actual checks.

.EXAMPLE
    .\Test-SoftwareWatchlist.ps1 -RunActualChecks
    Runs actual version checks for GitHub releases to verify checking process.
#>

[CmdletBinding()]
param(
    [switch]$RunActualChecks,
    [int]$DaysThreshold = 7
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$watchlistPath = Join-Path $PSScriptRoot '..' 'config' 'software-watchlist.json'

if (-not (Test-Path $watchlistPath)) {
    Write-Error "Software watchlist not found at: $watchlistPath"
    exit 1
}

Write-Information "`e[1;36m=== Software Watchlist Diagnostic Report ===`e[0m"
Write-Information ""

# Load watchlist
$watchlist = Get-Content $watchlistPath -Raw | ConvertFrom-Json
$software = $watchlist.monitored_software
$totalCount = $software.Count
$today = Get-Date

Write-Information "`e[1mTotal monitored software:`e[0m $totalCount"
Write-Information ""

# Analyze last check dates
$stats = @{
    CheckedToday = 0
    CheckedWithinWeek = 0
    CheckedOverWeek = 0
    NeverChecked = 0
    StaleItems = @()
}

foreach ($item in $software) {
    if ($null -eq $item.last_displayed_date) {
        $stats.NeverChecked++
        continue
    }

    $lastCheck = [datetime]::Parse($item.last_displayed_date)
    $daysSince = ($today - $lastCheck).Days

    if ($daysSince -eq 0) {
        $stats.CheckedToday++
    } elseif ($daysSince -le 7) {
        $stats.CheckedWithinWeek++
    } else {
        $stats.CheckedOverWeek++
        $stats.StaleItems += [PSCustomObject]@{
            Name = $item.name
            LastCheck = $item.last_displayed_date
            DaysSince = $daysSince
            Version = $item.last_displayed_version
            Method = $item.check_method
        }
    }
}

# Display statistics
Write-Information "`e[1;32m✓ Checked today:`e[0m $($stats.CheckedToday)"
Write-Information "`e[1;33m⚠ Checked within 7 days:`e[0m $($stats.CheckedWithinWeek)"
Write-Information "`e[1;31m✗ Not checked in over 7 days:`e[0m $($stats.CheckedOverWeek)"
Write-Information "`e[1;35m? Never checked:`e[0m $($stats.NeverChecked)"
Write-Information ""

# Show stale items
if ($stats.StaleItems.Count -gt 0) {
    Write-Information "`e[1;31m=== Stale Items (>7 days since last check) ===`e[0m"
    Write-Information ""
    foreach ($item in $stats.StaleItems | Sort-Object DaysSince -Descending) {
        Write-Information "  `e[1m$($item.Name)`e[0m"
        Write-Information "    Last checked: $($item.LastCheck) ($($item.DaysSince) days ago)"
        Write-Information "    Last version: $($item.Version)"
        Write-Information "    Check method: $($item.Method)"
        Write-Information ""
    }
}

# Check method distribution
Write-Information "`e[1;36m=== Check Methods Distribution ===`e[0m"
$methodGroups = $software | Group-Object check_method
foreach ($group in $methodGroups | Sort-Object Name) {
    Write-Information "  $($group.Name): $($group.Count) items"
}
Write-Information ""

# Run actual checks if requested
if ($RunActualChecks) {
    Write-Information "`e[1;36m=== Running Actual Version Checks (GitHub Releases) ===`e[0m"
    Write-Information ""
    
    $githubItems = $software | Where-Object { $_.check_method -eq 'github_releases' }
    $checkResults = @{
        Success = 0
        Failed = 0
        Errors = @()
    }

    foreach ($item in $githubItems) {
        # Extract owner/repo from changelog_url
        if ($item.changelog_url -match 'github\.com/([^/]+)/([^/]+)') {
            $owner = $Matches[1]
            $repoName = $Matches[2]
            $repo = "$owner/$repoName"
            
            # Clean up repo name (remove /releases, /blob/main/CHANGELOG.md, etc)
            $repo = $repo -replace '/releases.*$', ''
            $repo = $repo -replace '/blob/.*$', ''
            
            Write-Information "  Checking `e[1m$($item.name)`e[0m ($repo)..."
            
            try {
                $releases = gh release list --repo $repo --limit 3 2>&1
                if ($LASTEXITCODE -eq 0 -and $releases) {
                    # Parse first line: "TITLE\tTYPE\tTAG\tPUBLISHED"
                    $lines = $releases -split "`n" | Where-Object { $_.Trim() }
                    
                    if ($lines.Count -gt 0) {
                        $latestRelease = ($lines[0] -split '\t')
                        $latestVersion = $latestRelease[2] # TAG column
                        $publishedDate = $latestRelease[3]  # PUBLISHED column
                        $tracked = $item.last_displayed_version
                        
                        if ($latestVersion -ne $tracked) {
                            Write-Information "    `e[1;33m⚠ Version mismatch:`e[0m Latest=$latestVersion, Tracked=$tracked"
                            if ($publishedDate) {
                                $releaseDate = [DateTime]::Parse($publishedDate)
                                $daysAgo = ([DateTime]::Now - $releaseDate).Days
                                Write-Information "    Released $daysAgo days ago ($publishedDate)"
                            }
                        } else {
                            Write-Information "    `e[1;32m✓ Up to date:`e[0m $latestVersion"
                        }
                        $checkResults.Success++
                    }
                } else {
                    Write-Information "    `e[1;31m✗ Failed:`e[0m $releases"
                    $checkResults.Failed++
                    $checkResults.Errors += [PSCustomObject]@{
                        Software = $item.name
                        Error = $releases
                    }
                }
            } catch {
                Write-Information "    `e[1;31m✗ Error:`e[0m $($_.Exception.Message)"
                $checkResults.Failed++
                $checkResults.Errors += [PSCustomObject]@{
                    Software = $item.name
                    Error = $_.Exception.Message
                }
            }
        }
    }
    
    Write-Information ""
    Write-Information "`e[1;36m=== Check Results ===`e[0m"
    Write-Information "`e[1;32m✓ Successful:`e[0m $($checkResults.Success)"
    Write-Information "`e[1;31m✗ Failed:`e[0m $($checkResults.Failed)"
    
    if ($checkResults.Errors.Count -gt 0) {
        Write-Information ""
        Write-Information "`e[1;31m=== Errors ===`e[0m"
        foreach ($error in $checkResults.Errors) {
            Write-Information "  `e[1m$($error.Software)`e[0m: $($error.Error)"
        }
    }
}

Write-Information ""
Write-Information "`e[1;36m=== Recommendations ===`e[0m"

if ($stats.CheckedOverWeek -gt 10) {
    Write-Information "`e[1;31m⚠ WARNING:`e[0m Over 10 items haven't been checked in >7 days. The checking process may be broken."
    Write-Information "  Action: Manually verify a few items to ensure the checking logic works."
} elseif ($stats.CheckedOverWeek -gt 5) {
    Write-Information "`e[1;33m⚠ CAUTION:`e[0m Several items are becoming stale. Consider running checks more frequently."
} elseif ($stats.CheckedToday -lt 3 -and $stats.CheckedWithinWeek -lt 3) {
    Write-Information "`e[1;33m⚠ CAUTION:`e[0m Very few recent updates detected. This is unusual for 22+ software items."
    Write-Information "  Action: Run with -RunActualChecks to verify the checking process."
} else {
    Write-Information "`e[1;32m✓ Watchlist appears healthy.`e[0m Recent checks detected for multiple items."
}

Write-Information ""
