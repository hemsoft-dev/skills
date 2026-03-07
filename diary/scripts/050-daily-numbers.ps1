#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fills the Daily Numbers section of a diary entry.

.DESCRIPTION
    Fetches stock market data (Dow Jones, S&P 500) from Yahoo Finance,
    repo counts from GitHub (relias-engineering) and Bitbucket (relias),
    GitHub Copilot premium request usage for all accounts, and Cloudflare
    web/email metrics for managed domains.
    Computes deltas against yesterday's diary entry values.
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
$RepoSnapshotsDir = Join-Path $PSScriptRoot '..' 'output'
$CloudflareScriptPath = Join-Path $PSScriptRoot '..' '..' 'cloudflare' 'scripts' 'Get-CloudflareUsage.ps1'
$CloudflareDomains = @(
    [pscustomobject]@{ Name = 'nowleadershipgroup.com'; HasEmailRouting = $true },
    [pscustomobject]@{ Name = 'setitfreeloop.org'; HasEmailRouting = $false }
)

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
function Get-DiaryEntryPathByDate {
    param([datetime]$TargetDate)

    $entriesDir = Join-Path $PSScriptRoot '..' 'entries'
    $targetFileName = "$($TargetDate.ToString('yyyy-MM-dd')).md"

    return Get-ChildItem -Path $entriesDir -Filter $targetFileName -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        Select-Object -First 1 -ExpandProperty FullName
}

function Get-CloudflareStatsFromText {
    param(
        [string[]]$Lines,
        [string]$DomainName,
        [bool]$HasEmailRouting
    )

    $domainPattern = [regex]::Escape($DomainName)
    $pattern = if ($HasEmailRouting) {
        "- \*\*$domainPattern\*\*: (\d+) page views, (\d+) unique visitors, (\d+) emails forwarded(?:, (\d+) dropped)?"
    }
    else {
        "- \*\*$domainPattern\*\*: (\d+) page views, (\d+) unique visitors"
    }

    foreach ($line in $Lines) {
        if ($line -match $pattern) {
            $stats = [ordered]@{
                PageViews = [int]$Matches[1]
                UniqueVisitors = [int]$Matches[2]
            }

            if ($HasEmailRouting) {
                $stats.EmailsForwarded = [int]$Matches[3]
            }

            return [pscustomobject]$stats
        }
    }

    return $null
}

function Get-PreviousValues {
    $previousDate = $parsedDate.AddDays(-1)
    $previousEntryPath = Get-DiaryEntryPathByDate -TargetDate $previousDate
    if (-not $previousEntryPath) {
        Write-Information "`e[90m  No diary entry found for yesterday ($($previousDate.ToString('yyyy-MM-dd'))).`e[0m"
        return @{}
    }

    $content = Get-Content $previousEntryPath -Raw
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
    if ($content -match '- \*\*GitHub Copilot Usage\*\*: (\d+) / (\d+) premium requests \(([\d.]+)%\)') {
        $prev.CopilotUsed = [int]$Matches[1]
        $prev.CopilotEntitlement = [int]$Matches[2]
        $prev.CopilotPct = [decimal]$Matches[3]
    }

    $prevCloudflare = @{}
    foreach ($domain in $CloudflareDomains) {
        $domainStats = Get-CloudflareStatsFromText -Lines ($content -split "`r?`n") -DomainName $domain.Name -HasEmailRouting $domain.HasEmailRouting
        if ($null -ne $domainStats) {
            $prevCloudflare[$domain.Name] = $domainStats
        }
    }
    if ($prevCloudflare.Count -gt 0) {
        $prev.Cloudflare = $prevCloudflare
    }

    if ($prev.Count -gt 0) {
        Write-Information "`e[90m  Previous values from: $([System.IO.Path]::GetFileName($previousEntryPath))`e[0m"
    }

    return $prev
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

function Format-PctPointDelta {
    param([decimal]$Current, [decimal]$Previous)

    $delta = [math]::Round($Current - $Previous, 1)
    $sign = if ($delta -ge 0) { '+' } else { '' }
    return "$sign$($delta.ToString('0.0'))"
}

function Get-CopilotDeltaLine {
    param(
        [int]$CurrentUsed,
        [decimal]$CurrentPct,
        [hashtable]$PreviousValues
    )

    if (-not ($PreviousValues.ContainsKey('CopilotUsed') -and $PreviousValues.ContainsKey('CopilotPct'))) {
        return '  - **Delta vs Yesterday**: unavailable (previous diary entry missing GitHub Copilot usage)'
    }

    $requestsDelta = Format-IntDelta -Current $CurrentUsed -Previous $PreviousValues.CopilotUsed
    $pctPointDelta = Format-PctPointDelta -Current $CurrentPct -Previous $PreviousValues.CopilotPct
    return "  - **Delta vs Yesterday**: $requestsDelta requests, $pctPointDelta pct points"
}

function Get-MarketDriverText {
    param([string]$EntryContent)

    $content = if ($EntryContent) { $EntryContent.ToLowerInvariant() } else { '' }

    if ($content -match 'jobs|labor market|unemployment|economy') {
        return 'after weak U.S. labor data intensified economic worries'
    }

    if ($content -match 'tariff|trade war|trade tensions') {
        return 'as trade tensions kept investors on edge'
    }

    if ($content -match 'inflation|fed|interest rate|rates') {
        return 'as rate and inflation concerns weighed on sentiment'
    }

    if ($content -match 'iran|israel|lebanon|ukraine|russia|geopolitical') {
        return 'as geopolitical risk pushed traders toward a risk-off posture'
    }

    return 'as investors digested the day''s macro headlines'
}

function Get-MarketCommentary {
    param(
        [decimal]$DowCurrent,
        [decimal]$DowPrevious,
        [decimal]$SPCurrent,
        [decimal]$SPPrevious,
        [string]$EntryContent
    )

    if ($DowPrevious -eq 0 -or $SPPrevious -eq 0) {
        return ''
    }

    $dowDelta = $DowCurrent - $DowPrevious
    $spDelta = $SPCurrent - $SPPrevious
    $dowPct = [math]::Round(($dowDelta / $DowPrevious) * 100, 2)
    $spPct = [math]::Round(($spDelta / $SPPrevious) * 100, 2)
    $driver = Get-MarketDriverText -EntryContent $EntryContent

    if ($dowPct -le -1 -and $spPct -le -1) {
        $lead = "Markets sold off sharply $driver."
    }
    elseif ($dowPct -gt 0.5 -and $spPct -gt 0.5) {
        $lead = "Markets pushed higher $driver."
    }
    elseif ($dowPct -ge 0 -and $spPct -ge 0) {
        $lead = "Markets finished modestly higher $driver."
    }
    elseif ($dowPct -le 0 -and $spPct -le 0) {
        $lead = "Markets finished lower $driver."
    }
    else {
        $lead = "Markets ended mixed $driver."
    }

    $relative = if ([math]::Abs($dowPct - $spPct) -ge 0.4) {
        if ([math]::Abs($dowPct) -gt [math]::Abs($spPct)) {
            "The Dow's $([math]::Abs($dowPct).ToString('0.00'))% move was steeper than the S&P's $([math]::Abs($spPct).ToString('0.00'))%, suggesting heavier pressure in blue-chip names."
        }
        else {
            "The S&P's $([math]::Abs($spPct).ToString('0.00'))% move outpaced the Dow's $([math]::Abs($dowPct).ToString('0.00'))%, pointing to sharper weakness in the broader large-cap mix."
        }
    }
    else {
        'The Dow and S&P moved broadly in tandem, indicating a market-wide tone rather than an isolated sector move.'
    }

    return "*$lead $relative*"
}

function Get-RepoSnapshotPath {
    param([string]$SnapshotDate)
    return (Join-Path $RepoSnapshotsDir "$SnapshotDate-$GitHubOrg-repos.json")
}

function Save-RepoSnapshot {
    param(
        [string]$SnapshotDate,
        [string[]]$RepoNames
    )

    [System.IO.Directory]::CreateDirectory($RepoSnapshotsDir) | Out-Null
    $snapshotPath = Get-RepoSnapshotPath -SnapshotDate $SnapshotDate
    $payload = [pscustomobject]@{
        date = $SnapshotDate
        org = $GitHubOrg
        repos = @($RepoNames | Sort-Object -Unique)
    }
    $payload | ConvertTo-Json -Depth 4 | Set-Content -Path $snapshotPath -Encoding utf8NoBOM
}

function Get-PreviousRepoSnapshot {
    $snapshotFiles = Get-ChildItem -Path $RepoSnapshotsDir -Filter "*-$GitHubOrg-repos.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -lt "$Date-$GitHubOrg-repos" } |
        Sort-Object Name -Descending

    foreach ($snapshotFile in $snapshotFiles) {
        try {
            $snapshot = Get-Content -Path $snapshotFile.FullName -Raw | ConvertFrom-Json
            if ($snapshot.repos) {
                return [pscustomobject]@{
                    Date = "$($snapshot.date)"
                    Repos = @($snapshot.repos | ForEach-Object { "$_" })
                }
            }
        }
        catch {
            Write-Information "`e[1;33mFailed to parse repo snapshot: $($snapshotFile.Name)`e[0m"
        }
    }

    return $null
}

function Get-CloudflareUsageStats {
    param([string]$TargetDate)

    if (-not (Test-Path $CloudflareScriptPath)) {
        Write-Information "`e[1;33mCloudflare usage script not found: $CloudflareScriptPath`e[0m"
        return @{}
    }

    try {
        $outputLines = & $CloudflareScriptPath -Date $TargetDate 6>&1 | ForEach-Object { "$_" }
    }
    catch {
        Write-Information "`e[1;33mFailed to fetch Cloudflare usage: $_`e[0m"
        return @{}
    }

    $statsByDomain = @{}
    foreach ($domain in $CloudflareDomains) {
        $stats = Get-CloudflareStatsFromText -Lines $outputLines -DomainName $domain.Name -HasEmailRouting $domain.HasEmailRouting
        if ($null -ne $stats) {
            $statsByDomain[$domain.Name] = $stats
        }
    }

    return $statsByDomain
}

function Get-CloudflareDeltaLine {
    param(
        [string]$DomainName,
        [pscustomobject]$CurrentStats,
        [hashtable]$PreviousValues,
        [bool]$HasEmailRouting
    )

    if (-not ($PreviousValues.ContainsKey('Cloudflare') -and $PreviousValues.Cloudflare.ContainsKey($DomainName))) {
        return '    - **Delta vs Yesterday**: unavailable (previous diary entry missing Cloudflare metrics)'
    }

    $previousStats = $PreviousValues.Cloudflare[$DomainName]
    $parts = @(
        "$(Format-IntDelta -Current $CurrentStats.PageViews -Previous $previousStats.PageViews) page views",
        "$(Format-IntDelta -Current $CurrentStats.UniqueVisitors -Previous $previousStats.UniqueVisitors) unique visitors"
    )

    if ($HasEmailRouting) {
        $parts += "$(Format-IntDelta -Current $CurrentStats.EmailsForwarded -Previous $previousStats.EmailsForwarded) emails forwarded"
    }

    return '    - **Delta vs Yesterday**: ' + ($parts -join ', ')
}

Write-Information "`e[1;36mGathering daily numbers...`e[0m"

$entry = Get-Content $EntryPath -Raw

# --- Save original gh account (restore at end) ---
$originalGhUser = $null
try { $originalGhUser = gh api /user --jq '.login' 2>$null } catch {}

$prev = Get-PreviousValues

# --- Fetch GitHub repo count (use fhemmerrelias which has admin:org scope) ---
Write-Information "`e[1;36mFetching GitHub repo count ($GitHubOrg)...`e[0m"
gh auth switch -u fhemmerrelias 2>&1 | Out-Null
$ghRepoNames = New-Object System.Collections.Generic.List[string]
try {
    $page = 1
    do {
        $response = gh api "orgs/$GitHubOrg/repos?per_page=100&page=$page" 2>&1
        $pageRepos = @($response | ConvertFrom-Json)
        $count = $pageRepos.Count
        foreach ($repo in $pageRepos) {
            if ($repo.name) {
                [void]$ghRepoNames.Add("$($repo.name)")
            }
        }
        $page++
    } while ($count -eq 100)
}
catch {
    Write-Information "`e[1;31mFailed to fetch GitHub repo count: $_`e[0m"
}

$ghRepoNames = @($ghRepoNames | Sort-Object -Unique)
$ghRepoCount = $ghRepoNames.Count
if ($ghRepoCount -gt 0) {
    Save-RepoSnapshot -SnapshotDate $Date -RepoNames $ghRepoNames
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
$ghDelta = if ($prev.ContainsKey('GitHubRepos')) { Format-IntDelta -Current $ghRepoCount -Previous $prev.GitHubRepos } else { '—' }
$bbDelta = if ($prev.ContainsKey('BitbucketRepos')) { Format-IntDelta -Current $bbRepoCount -Previous $prev.BitbucketRepos } else { '—' }
$ghRepoDeltaDetailText = ''

if ($prev.ContainsKey('GitHubRepos') -and $ghRepoCount -ne $prev.GitHubRepos) {
    $previousSnapshot = Get-PreviousRepoSnapshot
    if ($null -ne $previousSnapshot) {
        if ($ghRepoCount -gt $prev.GitHubRepos) {
            $ghAddedRepos = @($ghRepoNames | Where-Object { $_ -notin $previousSnapshot.Repos })
            if ($ghAddedRepos.Count -gt 0) {
                $ghRepoDeltaDetailText = '; added: ' + ($ghAddedRepos -join ', ')
            }
            else {
                $ghRepoDeltaDetailText = "; added repos unavailable (snapshot $($previousSnapshot.Date) did not reveal a name diff)"
            }
        }
        else {
            $ghRemovedRepos = @($previousSnapshot.Repos | Where-Object { $_ -notin $ghRepoNames })
            if ($ghRemovedRepos.Count -gt 0) {
                $ghRepoDeltaDetailText = '; removed: ' + ($ghRemovedRepos -join ', ')
            }
            else {
                $ghRepoDeltaDetailText = "; removed repos unavailable (snapshot $($previousSnapshot.Date) did not reveal a name diff)"
            }
        }
    }
    else {
        if ($ghRepoCount -gt $prev.GitHubRepos) {
            $ghRepoDeltaDetailText = '; added repos unavailable (no previous snapshot found)'
        }
        else {
            $ghRepoDeltaDetailText = '; removed repos unavailable (no previous snapshot found)'
        }
    }
}

# --- Fetch stock market data (weekdays only) ---
$dowLine = ''
$spLine = ''
$marketCommentaryLine = ''

if (-not $isWeekend) {
    Write-Information "`e[1;36mFetching stock market data...`e[0m"
    try {
        $dowData = Invoke-RestMethod -Uri 'https://query1.finance.yahoo.com/v8/finance/chart/%5EDJI?range=2d&interval=1d' -ErrorAction Stop
        $spData = Invoke-RestMethod -Uri 'https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=2d&interval=1d' -ErrorAction Stop

        $dowPrice = [decimal]$dowData.chart.result[0].meta.regularMarketPrice
        $dowPrev = [decimal]$dowData.chart.result[0].meta.chartPreviousClose
        $spPrice = [decimal]$spData.chart.result[0].meta.regularMarketPrice
        $spPrev = [decimal]$spData.chart.result[0].meta.chartPreviousClose

        $dowDelta = Format-Delta -Current $dowPrice -Previous $dowPrev
        $spDelta = Format-Delta -Current $spPrice -Previous $spPrev

        $dowLine = "- **Dow Jones**: $($dowPrice.ToString('N2')) ($dowDelta)"
        $spLine = "- **S&P 500**: $($spPrice.ToString('N2')) ($spDelta)"
        $marketCommentaryLine = Get-MarketCommentary -DowCurrent $dowPrice -DowPrevious $dowPrev -SPCurrent $spPrice -SPPrevious $spPrev -EntryContent $entry
    }
    catch {
        Write-Information "`e[1;33mFailed to fetch stock data: $_`e[0m"
    }
}
else {
    Write-Information "`e[90mWeekend - skipping stock market data (markets closed).`e[0m"
}

# --- Fetch GitHub Copilot Usage ---
Write-Information "`e[1;36mFetching GitHub Copilot usage...`e[0m"

$copilotAccounts = @('HemSoft', 'franzhemmer', 'fhemmerrelias', 'fhemmer2-relias')

$copilotLines = @()
$grandTotalUsed = 0
$grandTotalEntitlement = 0
$grandTotalOverageCost = 0.0

foreach ($username in $copilotAccounts) {
    try {
        gh auth switch -u $username 2>&1 | Out-Null
        $response = gh api /copilot_internal/user --jq '.quota_snapshots.premium_interactions' 2>&1
        if ($LASTEXITCODE -eq 0) {
            $premium = $response | ConvertFrom-Json
            $entitlement = [int]$premium.entitlement
            $remaining = [int]$premium.remaining
            $used = $entitlement - $remaining
            $pctUsed = if ($entitlement -gt 0) { [math]::Round(100 - $premium.percent_remaining, 1) } else { 0 }
            $overageCount = [math]::Max(0, [int]$premium.overage_count)
            $overageCost = $overageCount * 0.04
            $grandTotalUsed += $used
            $grandTotalEntitlement += $entitlement
            $grandTotalOverageCost += $overageCost

            $line = "  - **$username**: $used / $entitlement used ($pctUsed%)"
            if ($overageCost -gt 0) {
                $line += " - overage: $overageCount reqs (`$$($overageCost.ToString('N2')))"
            }
            $copilotLines += $line
        }
        else {
            $copilotLines += "  - **$username**: *(unavailable)*"
        }
    }
    catch {
        $copilotLines += "  - **$username**: *(error)*"
    }
}

$grandPct = if ($grandTotalEntitlement -gt 0) { [math]::Round(($grandTotalUsed / $grandTotalEntitlement) * 100, 1) } else { 0 }
$copilotSummaryLine = "- **GitHub Copilot Usage**: $grandTotalUsed / $grandTotalEntitlement premium requests ($grandPct%)"
if ($grandTotalOverageCost -gt 0) {
    $copilotSummaryLine += " - overage: `$$($grandTotalOverageCost.ToString('N2'))"
}
$copilotDeltaLine = Get-CopilotDeltaLine -CurrentUsed $grandTotalUsed -CurrentPct $grandPct -PreviousValues $prev

# --- Fetch Cloudflare usage ---
Write-Information "`e[1;36mFetching Cloudflare usage...`e[0m"
$cloudflareUsage = Get-CloudflareUsageStats -TargetDate $Date
$cloudflareLines = @()
foreach ($domain in $CloudflareDomains) {
    if ($cloudflareUsage.ContainsKey($domain.Name)) {
        $currentStats = $cloudflareUsage[$domain.Name]
        $domainLine = "  - **$($domain.Name)**: $($currentStats.PageViews) page views, $($currentStats.UniqueVisitors) unique visitors"
        if ($domain.HasEmailRouting) {
            $domainLine += ", $($currentStats.EmailsForwarded) emails forwarded"
        }

        $cloudflareLines += $domainLine
        $cloudflareLines += Get-CloudflareDeltaLine -DomainName $domain.Name -CurrentStats $currentStats -PreviousValues $prev -HasEmailRouting $domain.HasEmailRouting
    }
    else {
        $cloudflareLines += "  - **$($domain.Name)**: *(unavailable)*"
        $cloudflareLines += '    - **Delta vs Yesterday**: unavailable (current Cloudflare metrics unavailable)'
    }
}

# --- Build markdown ---
$sb = [System.Text.StringBuilder]::new()

if ($dowLine) { [void]$sb.AppendLine($dowLine) }
if ($spLine) { [void]$sb.AppendLine($spLine) }
if ($marketCommentaryLine) {
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine($marketCommentaryLine)
    [void]$sb.AppendLine('')
}
[void]$sb.AppendLine("- **Relias Repo Count**: GitHub: $ghRepoCount ($ghDelta$ghRepoDeltaDetailText), Bitbucket: $bbRepoCount ($bbDelta)")
[void]$sb.AppendLine($copilotSummaryLine)
[void]$sb.AppendLine($copilotDeltaLine)
foreach ($line in $copilotLines) {
    [void]$sb.AppendLine($line)
}
if ($cloudflareLines.Count -gt 0) {
    [void]$sb.AppendLine('- **Cloudflare Usage**:')
    foreach ($line in $cloudflareLines) {
        [void]$sb.AppendLine($line)
    }
}

$numbersContent = $sb.ToString().TrimEnd()

# --- Inject into diary entry ---
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
    Write-Information "  GitHub: $ghRepoCount ($ghDelta$ghRepoDeltaDetailText) | Bitbucket: $bbRepoCount ($bbDelta)"
    Write-Information "  Copilot: $grandTotalUsed / $grandTotalEntitlement premium requests"
}
else {
    Write-Information "`e[1;31mDaily Numbers section (## 📊 Daily Numbers) not found in entry. Cannot inject.`e[0m"
}

# --- Restore original gh account ---
if ($originalGhUser) {
    gh auth switch -u $originalGhUser 2>&1 | Out-Null
}
