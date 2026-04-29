#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fills the Software Watchlist section of a diary entry.

.DESCRIPTION
    Reads config/software-watchlist.json for a list of tracked software.
    For GitHub-based entries, fetches the latest release via gh CLI.
    For RSS-based entries (GitHub Web), fetches the changelog feed.
    Compares versions with the previous diary entry and injects a
    markdown table into the current entry.

.PARAMETER Date
    The date for the diary entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER EntryPath
    The full path to the diary entry file to update.

.EXAMPLE
    .\080-software-watchlist.ps1 -Date 2026-02-28
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Resolve entry path ---
if (-not $EntryPath) {
    $year = $Date.Substring(0, 4)
    $month = $Date.Substring(5, 2)
    $EntryPath = Join-Path $PSScriptRoot '..' 'entries' $year $month "$Date.md"
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

# --- Load watchlist config ---
$configPath = Join-Path $PSScriptRoot '..' 'config' 'software-watchlist.json'
if (-not (Test-Path $configPath)) {
    Write-Error "Watchlist config not found: $configPath"
    exit 1
}
$watchlist = Get-Content $configPath -Raw | ConvertFrom-Json

Write-Information "`e[1;36mChecking software watchlist ($($watchlist.Count) items)...`e[0m"

# --- Get previous entry for version comparison ---
$entriesDir = Join-Path $PSScriptRoot '..' 'entries'
$prevEntry = Get-ChildItem $entriesDir -Filter '*.md' |
    Where-Object { $_.BaseName -lt $Date } |
    Sort-Object Name -Descending |
    Select-Object -First 1

$prevVersions = @{}
if ($prevEntry) {
    $prevContent = Get-Content $prevEntry.FullName -Raw
    # Extract only the Software Watchlist section from previous entry
    $watchlistSectionPattern = '(?:#{2,3}\s+💻\s+Software Watchlist\s*\r?\n)([\s\S]*?)(?:\r?\n---)'
    if ($prevContent -match $watchlistSectionPattern) {
        $watchlistSection = $Matches[1]
        # Parse table rows: | Name | Version | ...
        $tablePattern = '\|\s*(?:\[([^\]]+)\][^\|]*|([^\|]+?))\s*\|\s*([^\|]+?)\s*\|'
        foreach ($match in [regex]::Matches($watchlistSection, $tablePattern)) {
            $name = if ($match.Groups[1].Value) { $match.Groups[1].Value.Trim() } else { $match.Groups[2].Value.Trim() }
            $version = $match.Groups[3].Value.Trim()
            foreach ($w in $watchlist) {
                if ($name -eq $w.name) {
                    if ($version -match '→\s*(.+)$') { $version = $Matches[1].Trim() }
                    $prevVersions[$name] = $version
                    break
                }
            }
        }
    }
}

# --- Helper: extract highlights from release body ---
function Get-ReleaseHighlights([string]$body, [int]$maxItems = 5) {
    if (-not $body) { return '' }
    # Extract bullet points
    $bullets = ($body -split "`n") | Where-Object { $_ -match '^\s*[-*]\s+\S' } | ForEach-Object {
        ($_ -replace '^\s*[-*]\s+', '').Trim()
    }
    if ($bullets.Count -eq 0) {
        # Fallback: take first non-empty lines
        $bullets = ($body -split "`n") | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First $maxItems
    }
    $selected = $bullets | Select-Object -First $maxItems
    $result = ($selected -join '; ') -replace '\|', '–' -replace '\[([^\]]+)\]\([^\)]+\)', '$1'
    # Truncate if too long
    if ($result.Length -gt 250) { $result = $result.Substring(0, 247) + '...' }
    return $result
}

# --- Helper: format date ---
function Format-ReleaseDate([string]$isoDate) {
    if (-not $isoDate) { return '' }
    try {
        $dt = [datetime]::Parse($isoDate)
        return $dt.ToString('MMM d')
    } catch { return $isoDate }
}

# --- Fetch data for each watchlist item ---
$rows = @()

foreach ($item in $watchlist) {
    try {
        if ($item.type -eq 'github') {
            # Fetch release via gh CLI
            $jqFilter = '{tag_name, published_at, html_url, body}'
            if ($item.includePrerelease) {
                # Get first release (includes pre-releases), optionally filtering by pattern
                if ($item.excludePattern) {
                    $json = gh api "repos/$($item.repo)/releases" --jq "([.[] | select(.tag_name | test(`"$($item.excludePattern)`") | not)] | .[0]) | $jqFilter" 2>$null
                } else {
                    $json = gh api "repos/$($item.repo)/releases" --jq ".[0] | $jqFilter" 2>$null
                }
            } else {
                $json = gh api "repos/$($item.repo)/releases/latest" --jq $jqFilter 2>$null
            }

            if (-not $json) {
                Write-Information "`e[33m  $($item.name): No release found`e[0m"
                continue
            }

            $release = $json | ConvertFrom-Json
            $version = $release.tag_name
            $releasedDate = Format-ReleaseDate $release.published_at
            $highlights = Get-ReleaseHighlights $release.body

            # Version comparison
            $prevVer = $prevVersions[$item.name]
            $versionDisplay = if ($prevVer -and $prevVer -ne $version) {
                "$prevVer → $version"
            } else { $version }

            # Link
            $changelogUrl = if ($item.changelogUrl) { $item.changelogUrl } else { $release.html_url }
            $linkText = if ($item.changelogUrl) { 'Changelog' } else { 'Release' }
            $link = "[$linkText]($changelogUrl)"

            # Software name with repo link
            $nameDisplay = "[$($item.name)](https://github.com/$($item.repo))"

            $rows += [PSCustomObject]@{
                Name       = $nameDisplay
                Version    = $versionDisplay
                Released   = $releasedDate
                Highlights = $highlights
                Link       = $link
            }
            Write-Information "`e[90m  $($item.name): $versionDisplay ($releasedDate)`e[0m"
        }
        elseif ($item.type -eq 'rss') {
            # Fetch RSS feed for changelog entries
            $feed = Invoke-RestMethod -Uri $item.feedUrl -ErrorAction Stop
            $parsedDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)

            # Get entries from today or the most recent day
            $todayEntries = $feed | Where-Object {
                $pubDate = [datetime]::Parse($_.pubDate)
                $pubDate.Date -eq $parsedDate.Date
            }

            if ($todayEntries.Count -eq 0) {
                # Get most recent entries (within last 3 days)
                $cutoff = $parsedDate.AddDays(-3)
                $todayEntries = $feed | Where-Object {
                    $pubDate = [datetime]::Parse($_.pubDate)
                    $pubDate.Date -ge $cutoff.Date -and $pubDate.Date -le $parsedDate.Date
                } | Select-Object -First 5
            }

            if ($todayEntries.Count -gt 0) {
                $latestDate = [datetime]::Parse($todayEntries[0].pubDate)
                $releasedDate = $latestDate.ToString('MMM d')
                $headlines = ($todayEntries | ForEach-Object { $_.title }) -join '; '
                if ($headlines.Length -gt 250) { $headlines = $headlines.Substring(0, 247) + '...' }
                $headlines = $headlines -replace '\|', '–'

                # Version display: use date
                $prevVer = $prevVersions[$item.name]
                $dateVer = $latestDate.ToString('MMM d')
                $versionDisplay = if ($prevVer -and $prevVer -ne $dateVer) { "$prevVer → $dateVer" } else { $dateVer }

                $link = "[Changelog]($($item.changelogUrl))"
                $nameDisplay = "[$($item.name)]($($item.changelogUrl))"

                $rows += [PSCustomObject]@{
                    Name       = $nameDisplay
                    Version    = $versionDisplay
                    Released   = $releasedDate
                    Highlights = $headlines
                    Link       = $link
                }
                Write-Information "`e[90m  $($item.name): $($todayEntries.Count) entries ($releasedDate)`e[0m"
            } else {
                Write-Information "`e[33m  $($item.name): No recent changelog entries`e[0m"
            }
        }
    }
    catch {
        Write-Information "`e[33m  $($item.name): Error — $_`e[0m"
    }
}

if ($rows.Count -eq 0) {
    Write-Information "`e[1;31mNo software updates found. This should not happen — check API access.`e[0m"
    exit 1
}

# --- Build markdown table ---
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("| Software | Version | Released | Highlights | Links |")
[void]$sb.AppendLine("|----------|---------|----------|------------|-------|")
foreach ($r in $rows) {
    [void]$sb.AppendLine("| $($r.Name) | $($r.Version) | $($r.Released) | $($r.Highlights) | $($r.Link) |")
}
$watchlistContent = $sb.ToString().TrimEnd()

# --- Inject into diary entry ---
$entry = Get-Content $EntryPath -Raw

$sectionPattern = '(#{2,3}\s+💻\s+Software Watchlist\s*\r?\n)([\s\S]*?)(\r?\n---)'
$regex = [regex]::new($sectionPattern)
$m = $regex.Match($entry)
if ($m.Success) {
    $before = $entry.Substring(0, $m.Index)
    $after = $entry.Substring($m.Index + $m.Length)
    $entry = $before + $m.Groups[1].Value + "`n" + $watchlistContent + "`n" + $m.Groups[3].Value + $after
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($EntryPath, $entry, $utf8NoBom)
    Write-Information "`e[1;32mSoftware watchlist injected into diary entry ($($rows.Count) items).`e[0m"
}
else {
    Write-Information "`e[1;31mSoftware Watchlist section (## 💻 Software Watchlist) not found in entry. Cannot inject.`e[0m"
}
