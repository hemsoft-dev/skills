#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks for software updates from the watchlist and reports changes.

.DESCRIPTION
    Reads config/software-watchlist.json, checks each item for updates using the appropriate method,
    and reports which software has new versions available. This helps verify the checking
    process is working correctly.

.PARAMETER UpdateTracking
    If specified, updates the config/software-watchlist.json with new version information.

.PARAMETER Method
    Filter to only check software using a specific method (github_releases, web, cli).

.EXAMPLE
    .\Get-SoftwareUpdates.ps1
    Checks all software without updating tracking.

.EXAMPLE
    .\Get-SoftwareUpdates.ps1 -Method github_releases -UpdateTracking
    Checks only GitHub releases and updates the tracking file.
#>

[CmdletBinding()]
param(
    [switch]$UpdateTracking,
    [ValidateSet('github_releases', 'github_releases_prerelease', 'rss', 'web', 'web_scrape', 'cli', 'all')]
    [string]$Method = 'all'
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$watchlistPath = Join-Path $PSScriptRoot '..' 'config' 'software-watchlist.json'

if (-not (Test-Path $watchlistPath)) {
    Write-Error "Software watchlist not found at: $watchlistPath"
    exit 1
}

Write-Information "`e[1;36m=== Checking Software Updates ===`e[0m"
Write-Information ""

# Load watchlist
$watchlist = Get-Content $watchlistPath -Raw | ConvertFrom-Json
$software = $watchlist.monitored_software

# Filter by method if specified
if ($Method -ne 'all') {
    $software = $software | Where-Object { $_.check_method -eq $Method }
    Write-Information "Filtering to $Method method only ($($software.Count) items)"
    Write-Information ""
}

$results = @{
    UpdatesFound = @()
    NoUpdates = @()
    Errors = @()
}

foreach ($item in $software) {
    Write-Information "Checking `e[1m$($item.name)`e[0m ($($item.check_method))..."
    
    try {
        $currentVersion = $null
        $releaseDate = $null
        $success = $false
        
        switch ($item.check_method) {
            'github_releases' {
                if ($item.changelog_url -match 'github\.com/([^/]+)/([^/]+)') {
                    $owner = $Matches[1]
                    $repoName = $Matches[2]
                    $repo = "$owner/$repoName"
                    
                    # Clean up repo name (remove /releases, /blob/main/CHANGELOG.md, etc)
                    $repo = $repo -replace '/releases.*$', ''
                    $repo = $repo -replace '/blob/.*$', ''
                    
                    Write-Verbose "  Fetching releases for $repo"
                    $releases = gh release list --repo $repo --limit 5 2>&1
                    
                    if ($LASTEXITCODE -eq 0 -and $releases) {
                        # Parse first line: "TITLE\tTYPE\tTAG\tPUBLISHED"
                        $lines = $releases -split "`n" | Where-Object { $_.Trim() }
                        
                        if ($lines.Count -gt 0) {
                            $latestRelease = ($lines[0] -split '\t')
                            $currentVersion = $latestRelease[2] # TAG column
                            $publishedDate = $latestRelease[3]  # PUBLISHED column
                            
                            if ($publishedDate) {
                                try {
                                    $parsedDate = [DateTime]::Parse($publishedDate)
                                    $releaseDate = $parsedDate.ToString('MMM dd') + " '" + $parsedDate.ToString('yy')
                                } catch {
                                    Write-Verbose "Could not parse date: $publishedDate"
                                }
                            }
                            
                            $success = $true
                        }
                    } else {
                        $results.Errors += [PSCustomObject]@{
                            Software = $item.name
                            Error = "gh command failed: $releases"
                        }
                    }
                }
            }
            
            'github_releases_prerelease' {
                if ($item.changelog_url -match 'github\.com/([^/]+)/([^/]+)') {
                    $owner = $Matches[1]
                    $repoName = $Matches[2]
                    $repo = "$owner/$repoName"
                    
                    # Clean up repo name
                    $repo = $repo -replace '/releases.*$', ''
                    $repo = $repo -replace '/blob/.*$', ''
                    
                    Write-Verbose "  Fetching pre-releases for $repo"
                    $releases = gh release list --repo $repo --limit 10 2>&1
                    
                    if ($LASTEXITCODE -eq 0 -and $releases) {
                        $lines = $releases -split "`n" | Where-Object { $_.Trim() }
                        
                        # Find first line with preview/prerelease/pre-release (case insensitive)
                        # For Gemini CLI, prefer "preview" over "nightly"
                        if ($item.name -eq 'Gemini CLI') {
                            $prereleaseLine = $lines | Where-Object { $_ -match '(?i)preview' -and $_ -notmatch 'nightly' } | Select-Object -First 1
                        } else {
                            $prereleaseLine = $lines | Where-Object { $_ -match '(?i)(pre-release|preview)' } | Select-Object -First 1
                        }
                        
                        if ($prereleaseLine) {
                            $latestRelease = ($prereleaseLine -split '\t')
                            $currentVersion = $latestRelease[2] # TAG column
                            $publishedDate = $latestRelease[3]  # PUBLISHED column
                            
                            if ($publishedDate) {
                                try {
                                    $parsedDate = [DateTime]::Parse($publishedDate)
                                    $releaseDate = $parsedDate.ToString('MMM dd') + " '" + $parsedDate.ToString('yy')
                                } catch {
                                    Write-Verbose "Could not parse date: $publishedDate"
                                }
                            }
                            
                            $success = $true
                        }
                    } else {
                        $results.Errors += [PSCustomObject]@{
                            Software = $item.name
                            Error = "gh command failed: $releases"
                        }
                    }
                }
            }
            
            'rss' {
                try {
                    Write-Verbose "  Fetching RSS feed from $($item.changelog_url)"
                    $rssText = curl -s $item.changelog_url
                    
                    if ($rssText) {
                        # Parse as XML
                        [xml]$rss = $rssText
                        
                        if ($rss.rss.channel.item) {
                            $latestItem = $rss.rss.channel.item[0]
                            $title = $latestItem.title
                            
                            # Special handling for Slack: "Slack 4.47.69 (12/8/25)"
                            if ($item.name -eq 'Slack' -and $title -match 'Slack ([\d.]+)') {
                                $currentVersion = "v$($Matches[1])"
                                $success = $true
                                
                                # Extract date from title
                                if ($title -match '\((\d+)/(\d+)/(\d+)\)') {
                                    try {
                                        $month = $Matches[1]
                                        $day = $Matches[2]
                                        $year = "20$($Matches[3])"
                                        $parsedDate = [DateTime]::Parse("$month/$day/$year")
                                        $releaseDate = $parsedDate.ToString('MMM dd') + " '" + $parsedDate.ToString('yy')
                                    } catch {
                                        Write-Verbose "Could not parse Slack date: $title"
                                    }
                                }
                            }
                            # Default: Extract date from pubDate
                            elseif ($latestItem.pubDate) {
                                try {
                                    $parsedDate = [DateTime]::Parse($latestItem.pubDate)
                                    $currentVersion = $parsedDate.ToString('MMM dd')
                                    $releaseDate = $parsedDate.ToString('MMM dd') + " '" + $parsedDate.ToString('yy')
                                    $success = $true
                                } catch {
                                    Write-Verbose "Could not parse RSS date: $($latestItem.pubDate)"
                                }
                            }
                        }
                    }
                } catch {
                    $results.Errors += [PSCustomObject]@{
                        Software = $item.name
                        Error = "RSS fetch failed: $($_.Exception.Message)"
                    }
                }
            }
            
            'web_scrape' {
                try {
                    Write-Verbose "  Fetching web page from $($item.changelog_url)"
                    $webText = curl -s $item.changelog_url
                    
                    if ($webText) {
                        # Cursor-specific: Extract "[CLIJan 8, 2026]" pattern
                        if ($item.name -eq 'Cursor' -and $webText -match '\[CLI([A-Za-z]+)\s+(\d+),\s+(\d{4})\]') {
                            $month = $Matches[1]
                            $day = $Matches[2]
                            $year = $Matches[3]
                            $currentVersion = "CLI ($month $day, $year)"
                            
                            try {
                                $parsedDate = [DateTime]::Parse("$month $day, $year")
                                $releaseDate = $parsedDate.ToString('MMM dd') + " '" + $parsedDate.ToString('yy')
                                $success = $true
                            } catch {
                                Write-Verbose "Could not parse Cursor date: $month $day, $year"
                            }
                        }
                    }
                } catch {
                    $results.Errors += [PSCustomObject]@{
                        Software = $item.name
                        Error = "Web scrape failed: $($_.Exception.Message)"
                    }
                }
            }
            
            'cli' {
                # Implement specific CLI checks
                switch ($item.name) {
                    'Node.js' {
                        $nodeVersion = node --version 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $currentVersion = $nodeVersion.Trim()
                            $success = $true
                        }
                    }
                    'Bun' {
                        $bunVersion = bun --version 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $currentVersion = "v$($bunVersion.Trim())"
                            $success = $true
                        }
                    }
                    'Docker Desktop' {
                        $dockerVersion = docker --version 2>&1
                        if ($LASTEXITCODE -eq 0 -and $dockerVersion -match 'Docker version\s+([\d.]+)') {
                            $currentVersion = "v$($Matches[1])"
                            $success = $true
                        }
                    }
                    default {
                        Write-Information "  `e[1;33m⚠ CLI check not implemented for $($item.name)`e[0m"
                    }
                }
            }
            
            'web' {
                # Note: Web checks require WebSearch/WebFetch which this script can't do
                Write-Information "  `e[1;33m⚠ Web checks require manual verification via Claude`e[0m"
            }
        }
        
        if ($success -and $currentVersion) {
            # Normalize version strings for comparison
            $trackedVersion = $item.last_displayed_version
            $versionChanged = $currentVersion -ne $trackedVersion
            
            if ($versionChanged) {
                Write-Information "  `e[1;32m✓ UPDATE FOUND:`e[0m $trackedVersion → $currentVersion"
                $results.UpdatesFound += [PSCustomObject]@{
                    Software = $item.name
                    OldVersion = $trackedVersion
                    NewVersion = $currentVersion
                    ReleaseDate = $releaseDate
                    ChangelogUrl = $item.changelog_url
                    CheckMethod = $item.check_method
                }
            } else {
                Write-Information "  No change ($currentVersion)"
                $results.NoUpdates += $item.name
            }
        }
    } catch {
        Write-Information "  `e[1;31m✗ ERROR:`e[0m $($_.Exception.Message)"
        $results.Errors += [PSCustomObject]@{
            Software = $item.name
            Error = $_.Exception.Message
        }
    }
}

Write-Information ""
Write-Information "`e[1;36m=== Summary ===`e[0m"
Write-Information "`e[1;32m✓ Updates found:`e[0m $($results.UpdatesFound.Count)"
Write-Information "  No updates: $($results.NoUpdates.Count)"
Write-Information "`e[1;31m✗ Errors:`e[0m $($results.Errors.Count)"
Write-Information ""

if ($results.UpdatesFound.Count -gt 0) {
    Write-Information "`e[1;36m=== Available Updates ===`e[0m"
    foreach ($update in $results.UpdatesFound) {
        Write-Information ""
        Write-Information "  `e[1m$($update.Software)`e[0m"
        Write-Information "    $($update.OldVersion) → `e[1;32m$($update.NewVersion)`e[0m"
        if ($update.ReleaseDate) {
            Write-Information "    Released: $($update.ReleaseDate)"
        }
        Write-Information "    Changelog: $($update.ChangelogUrl)"
    }
    Write-Information ""
    
    # Output JSON for easy parsing by other tools
    $jsonPath = Join-Path $PSScriptRoot '..' 'config' 'latest-updates.json'
    $results.UpdatesFound | ConvertTo-Json -Depth 3 | Set-Content $jsonPath
    Write-Information "Update details written to: $jsonPath"
    Write-Information ""
}

if ($results.Errors.Count -gt 0) {
    Write-Information "`e[1;31m=== Errors ===`e[0m"
    foreach ($error in $results.Errors) {
        Write-Information "  `e[1m$($error.Software)`e[0m: $($error.Error)"
    }
    Write-Information ""
}

if ($UpdateTracking -and $results.UpdatesFound.Count -gt 0) {
    Write-Information "`e[1;33m⚠ UpdateTracking flag specified but automatic updates not implemented.`e[0m"
    Write-Information "  Use the diary skill to properly update config/software-watchlist.json"
    Write-Information ""
}

# Exit with status code
if ($results.UpdatesFound.Count -eq 0 -and $Method -eq 'all') {
    Write-Information "`e[1;31m⚠ WARNING: Zero updates found for all software. This is unusual.`e[0m"
    exit 1
}

exit 0
