#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fills the Daily Numbers section of a diary entry.

.DESCRIPTION
    Fetches stock market data (Dow Jones, S&P 500) from Yahoo Finance and
    repo counts from GitHub (relias-engineering) and Bitbucket (relias).
    Computes deltas against the previous diary entry's values.
    Skips stock data on weekends (markets closed).

.PARAMETER Date
    The date for the diary entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER EntryPath
    The full path to the diary entry file to update.

.EXAMPLE
    .\050-daily-numbers.ps1 -Date 2026-02-28 -EntryPath ..\entries\2026-02-28.md
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Configuration ---
$GitHubOrg = 'relias-engineering'
$BitbucketWorkspace = 'relias'

# --- Resolve entry path ---
if (-not $EntryPath) {
    $EntryPath = Join-Path $PSScriptRoot '..' 'entries' "$Date.md"
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

$parsedDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)
$isWeekend = $parsedDate.DayOfWeek -eq 'Saturday' -or $parsedDate.DayOfWeek -eq 'Sunday'

# --- Find previous entry for deltas ---
function Get-PreviousValues {
    $entriesDir = Join-Path $PSScriptRoot '..' 'entries'
    $entries = Get-ChildItem $entriesDir -Filter '*.md' |
        Where-Object { $_.BaseName -lt $Date } |
        Sort-Object Name -Descending

    foreach ($entry in $entries) {
        $content = Get-Content $entry.FullName -Raw
        $prev = @{}

        if ($content -match 'GitHub:\s*(\d+)') {
            $prev.GitHubRepos = [int]$Matches[1]
        }
        if ($content -match 'Bitbucket:\s*(\d+)') {
            $prev.BitbucketRepos = [int]$Matches[1]
        }
        if ($content -match '\*\*Dow Jones\*\*:\s*([\d,]+\.\d+)') {
            $prev.Dow = [decimal]($Matches[1] -replace ',', '')
        }
        if ($content -match '\*\*S&P 500\*\*:\s*([\d,]+\.\d+)') {
            $prev.SP500 = [decimal]($Matches[1] -replace ',', '')
        }

        if ($prev.Count -gt 0) {
            Write-Information "`e[90m  Previous values from: $($entry.Name)`e[0m"
            return $prev
        }
    }
    return @{}
}

function Format-Delta {
    param([decimal]$Current, [decimal]$Previous)
    if ($Previous -eq 0) { return '' }
    $delta = $Current - $Previous
    $pct = ($delta / $Previous) * 100
    $sign = if ($delta -ge 0) { '+' } else { '' }
    return "$sign$($delta.ToString('N2')), $sign$($pct.ToString('0.00'))%"
}

function Format-IntDelta {
    param([int]$Current, [int]$Previous)
    $delta = $Current - $Previous
    $sign = if ($delta -ge 0) { '+' } else { '' }
    return "$sign$delta"
}

Write-Information "`e[1;36mGathering daily numbers...`e[0m"

$prev = Get-PreviousValues

# --- Fetch GitHub repo count ---
Write-Information "`e[1;36mFetching GitHub repo count ($GitHubOrg)...`e[0m"
$ghRepoCount = 0
try {
    $page = 1
    do {
        $count = gh api "orgs/$GitHubOrg/repos?per_page=100&page=$page" --jq 'length' 2>&1
        $count = [int]$count
        $ghRepoCount += $count
        $page++
    } while ($count -eq 100)
}
catch {
    Write-Information "`e[1;31mFailed to fetch GitHub repo count: $_`e[0m"
}

# --- Fetch Bitbucket repo count ---
Write-Information "`e[1;36mFetching Bitbucket repo count ($BitbucketWorkspace)...`e[0m"
$bbRepoCount = 0
try {
    $bbUser = $env:BITBUCKET_USERNAME
    $bbToken = $env:BITBUCKET_API_TOKEN
    if ($bbUser -and $bbToken) {
        $cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${bbUser}:${bbToken}"))
        $response = Invoke-RestMethod -Uri "https://api.bitbucket.org/2.0/repositories/${BitbucketWorkspace}?pagelen=1" `
            -Headers @{ Authorization = "Basic $cred" } -ErrorAction Stop
        $bbRepoCount = $response.size
    }
    else {
        Write-Information "`e[1;33mBitbucket credentials not found. Skipping.`e[0m"
    }
}
catch {
    Write-Information "`e[1;31mFailed to fetch Bitbucket repo count: $_`e[0m"
}

# --- Compute repo deltas ---
$ghDelta = if ($prev.ContainsKey('GitHubRepos')) { Format-IntDelta $ghRepoCount $prev.GitHubRepos } else { '—' }
$bbDelta = if ($prev.ContainsKey('BitbucketRepos')) { Format-IntDelta $bbRepoCount $prev.BitbucketRepos } else { '—' }

# --- Fetch stock market data (weekdays only) ---
$dowLine = ''
$spLine = ''

if (-not $isWeekend) {
    Write-Information "`e[1;36mFetching stock market data...`e[0m"
    try {
        $dowData = Invoke-RestMethod -Uri "https://query1.finance.yahoo.com/v8/finance/chart/%5EDJI?range=2d&interval=1d" -ErrorAction Stop
        $spData = Invoke-RestMethod -Uri "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=2d&interval=1d" -ErrorAction Stop

        $dowPrice = [decimal]$dowData.chart.result[0].meta.regularMarketPrice
        $dowPrev = [decimal]$dowData.chart.result[0].meta.chartPreviousClose
        $spPrice = [decimal]$spData.chart.result[0].meta.regularMarketPrice
        $spPrev = [decimal]$spData.chart.result[0].meta.chartPreviousClose

        $dowDelta = Format-Delta $dowPrice $dowPrev
        $spDelta = Format-Delta $spPrice $spPrev

        $dowLine = "- **Dow Jones**: $($dowPrice.ToString('N2')) ($dowDelta)"
        $spLine = "- **S&P 500**: $($spPrice.ToString('N2')) ($spDelta)"
    }
    catch {
        Write-Information "`e[1;33mFailed to fetch stock data: $_`e[0m"
    }
}
else {
    Write-Information "`e[90mWeekend — skipping stock market data (markets closed).`e[0m"
}

# --- Build markdown ---
$sb = [System.Text.StringBuilder]::new()

if ($dowLine) { [void]$sb.AppendLine($dowLine) }
if ($spLine) { [void]$sb.AppendLine($spLine) }
[void]$sb.AppendLine("- **Relias Repo Count**: GitHub: $ghRepoCount ($ghDelta), Bitbucket: $bbRepoCount ($bbDelta)")

$numbersContent = $sb.ToString().TrimEnd()

# --- Inject into diary entry ---
$entry = Get-Content $EntryPath -Raw

$sectionPattern = '(#{2,3}\s+📊\s+Daily Numbers\s*\r?\n)([\s\S]*?)(\r?\n---)'
$regex = [regex]::new($sectionPattern)
$m = $regex.Match($entry)
if ($m.Success) {
    $before = $entry.Substring(0, $m.Index)
    $after = $entry.Substring($m.Index + $m.Length)
    $entry = $before + $m.Groups[1].Value + "`n" + $numbersContent + "`n" + $m.Groups[3].Value + $after
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($EntryPath, $entry, $utf8NoBom)
    Write-Information "`e[1;32mDaily numbers injected into diary entry.`e[0m"
    if ($dowLine) { Write-Information "  Dow: $($dowPrice.ToString('N2')) | S&P: $($spPrice.ToString('N2'))" }
    Write-Information "  GitHub: $ghRepoCount ($ghDelta) | Bitbucket: $bbRepoCount ($bbDelta)"
}
else {
    Write-Information "`e[1;31mDaily Numbers section (## 📊 Daily Numbers) not found in entry. Cannot inject.`e[0m"
}
