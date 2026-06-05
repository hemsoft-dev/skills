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

. (Join-Path $PSScriptRoot 'HtmlDiaryHelpers.ps1')

# --- Resolve entry path ---
if (-not $EntryPath) {
    $EntryPath = Get-DiaryHtmlEntryPath -ScriptRoot $PSScriptRoot -Date $Date
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

# --- Load watchlist config ---
$configPath = Join-Path $PSScriptRoot (Join-Path '..' (Join-Path 'config' 'software-watchlist.json'))
if (-not (Test-Path $configPath)) {
    Write-Error "Watchlist config not found: $configPath"
    exit 1
}
$watchlist = Get-Content $configPath -Raw | ConvertFrom-Json

Write-Information "`e[1;36mChecking software watchlist ($($watchlist.Count) items)...`e[0m"

$prevVersions = @{}
try {
    $prevSnapshot = Get-PreviousDiarySnapshotJson -ScriptRoot $PSScriptRoot -Date $Date -Name 'software-watchlist'
    if ($prevSnapshot -and $prevSnapshot.versions) {
        foreach ($property in $prevSnapshot.versions.PSObject.Properties) {
            $prevVersions[$property.Name] = "$($property.Value)"
        }
    }
}
catch {
    Write-Information "`e[33m  Previous software snapshot unavailable: $_`e[0m"
}

# --- Helper: extract highlights from release body ---
function Get-ReleaseHighlightText([string]$body, [int]$maxItems = 5) {
    if (-not $body) { return '' }
    # Extract bullet points
    $bullets = @(($body -split "`n") | Where-Object { $_ -match '^\s*[-*]\s+\S' } | ForEach-Object {
        ($_ -replace '^\s*[-*]\s+', '').Trim()
    })
    if ($bullets.Count -eq 0) {
        # Fallback: take first non-empty lines
        $bullets = @(($body -split "`n") | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First $maxItems)
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

function Get-OptionalPropertyValue {
    param(
        [object]$InputObject,
        [string]$PropertyName,
        $DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -ne $property) {
        return $property.Value
    }

    return $DefaultValue
}

# --- Fetch data for each watchlist item ---
$rows = @()

foreach ($item in $watchlist) {
    try {
        if ($item.type -eq 'github') {
            # Fetch release via gh CLI
            $jqFilter = '{tag_name, published_at, html_url, body}'
            $includePrerelease = [bool](Get-OptionalPropertyValue -InputObject $item -PropertyName 'includePrerelease' -DefaultValue $false)
            $excludePattern = [string](Get-OptionalPropertyValue -InputObject $item -PropertyName 'excludePattern' -DefaultValue '')

            if ($includePrerelease) {
                # Get first release (includes pre-releases), optionally filtering by pattern
                if ($excludePattern) {
                    $json = gh api "repos/$($item.repo)/releases" --jq "([.[] | select(.tag_name | test(`"$excludePattern`") | not)] | .[0]) | $jqFilter" 2>$null
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
            $highlights = Get-ReleaseHighlightText $release.body

            # Version comparison
            $prevVer = $prevVersions[$item.name]
            $versionDisplay = if ($prevVer -and $prevVer -ne $version) {
                "$prevVer → $version"
            } else { $version }

            # Link
            $configuredChangelogUrl = [string](Get-OptionalPropertyValue -InputObject $item -PropertyName 'changelogUrl' -DefaultValue '')
            $changelogUrl = if ($configuredChangelogUrl) { $configuredChangelogUrl } else { $release.html_url }
            $linkText = if ($configuredChangelogUrl) { 'Changelog' } else { 'Release' }
            $link = "[$linkText]($changelogUrl)"

            # Software name with repo link
            $nameDisplay = "[$($item.name)](https://github.com/$($item.repo))"

            $rows += [PSCustomObject]@{
                Key        = $item.name
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
            $feedRss = Get-OptionalPropertyValue -InputObject $feed -PropertyName 'rss'
            $feedChannel = if ($feedRss) {
                Get-OptionalPropertyValue -InputObject $feedRss -PropertyName 'channel'
            }
            else {
                Get-OptionalPropertyValue -InputObject $feed -PropertyName 'channel'
            }
            $channelItems = if ($feedChannel) {
                Get-OptionalPropertyValue -InputObject $feedChannel -PropertyName 'item' -DefaultValue @()
            }
            else {
                @()
            }
            $feedItems = if (@($channelItems).Count -gt 0) {
                @($channelItems)
            }
            else {
                @($feed | Where-Object { Get-OptionalPropertyValue -InputObject $_ -PropertyName 'pubDate' })
            }

            # Get entries from today or the most recent day
            $todayEntries = @($feedItems | Where-Object {
                $pubDate = [datetime]::Parse($_.pubDate)
                $pubDate.Date -eq $parsedDate.Date
            })

            if ($todayEntries.Count -eq 0) {
                # Get most recent entries (within last 3 days)
                $cutoff = $parsedDate.AddDays(-3)
                $todayEntries = @($feedItems | Where-Object {
                    $pubDate = [datetime]::Parse($_.pubDate)
                    $pubDate.Date -ge $cutoff.Date -and $pubDate.Date -le $parsedDate.Date
                } | Select-Object -First 5)
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
                    Key        = $item.name
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

$snapshotVersions = [ordered]@{}
foreach ($r in $rows) {
    $rawVersion = if ($r.Version -match '→\s*(.+)$') { $Matches[1].Trim() } else { $r.Version }
    $snapshotVersions[$r.Key] = $rawVersion
}
Save-DiarySnapshotJson -ScriptRoot $PSScriptRoot -Date $Date -Name 'software-watchlist' -Payload @{
    date = $Date
    versions = $snapshotVersions
}

# --- Build markdown table ---
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("| Software | Version | Released | Highlights | Links |")
[void]$sb.AppendLine("|----------|---------|----------|------------|-------|")
foreach ($r in $rows) {
    [void]$sb.AppendLine("| $($r.Name) | $($r.Version) | $($r.Released) | $($r.Highlights) | $($r.Link) |")
}
$watchlistContent = $sb.ToString().TrimEnd()

$sectionHtml = ConvertTo-DiaryHtmlCard -Markdown $watchlistContent -Eyebrow "Software watchlist snapshot for $Date"
Set-DiarySectionInnerHtml -EntryPath $EntryPath -SectionTitle '🛠 Software Watchlist' -InnerHtml $sectionHtml
Write-Information "`e[1;32mSoftware watchlist injected into diary entry ($($rows.Count) items).`e[0m"
