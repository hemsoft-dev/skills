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
    .\050-daily-numbers.ps1 -Date 2026-02-28 -EntryPath ..\entries\2026-02-28.html
#>

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$EntryPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

. (Join-Path $PSScriptRoot 'HtmlDiaryHelpers.ps1')

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
    $EntryPath = Get-DiaryHtmlEntryPath -ScriptRoot $PSScriptRoot -Date $Date
}

if (-not (Test-Path $EntryPath)) {
    Write-Error "Diary entry not found: $EntryPath"
    exit 1
}

$parsedDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)
$isWeekend = $parsedDate.DayOfWeek -eq 'Saturday' -or $parsedDate.DayOfWeek -eq 'Sunday'

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

function Get-PreviousDiaryValueSnapshot {
    $previousSnapshot = Get-PreviousDiarySnapshotJson -ScriptRoot $PSScriptRoot -Date $Date -Name 'daily-numbers'
    if (-not $previousSnapshot) {
        Write-Information "`e[90m  No daily numbers snapshot found for yesterday.`e[0m"
        return @{}
    }

    $prev = @{}

    if ($null -ne $previousSnapshot.githubRepos) {
        $prev.GitHubRepos = [int]$previousSnapshot.githubRepos
    }
    if ($null -ne $previousSnapshot.bitbucketRepos) {
        $prev.BitbucketRepos = [int]$previousSnapshot.bitbucketRepos
    }
    if ($previousSnapshot.copilot) {
        if ($null -ne $previousSnapshot.copilot.orgPremium -and $null -ne $previousSnapshot.copilot.orgPct) {
            $prev.OrgCopilotUsed = [decimal]$previousSnapshot.copilot.orgPremium
            $prev.OrgCopilotPct = [decimal]$previousSnapshot.copilot.orgPct
        }
    }

    $prevCloudflare = @{}
    if ($previousSnapshot.cloudflare) {
        foreach ($domain in $CloudflareDomains) {
            $snapshotStats = $previousSnapshot.cloudflare."$($domain.Name)"
            if ($snapshotStats) {
                $prevCloudflare[$domain.Name] = [pscustomobject]@{
                    PageViews = [int]$snapshotStats.pageViews
                    UniqueVisitors = [int]$snapshotStats.uniqueVisitors
                    EmailsForwarded = if ($null -ne $snapshotStats.emailsForwarded) { [int]$snapshotStats.emailsForwarded } else { 0 }
                }
            }
        }
    }
    if ($prevCloudflare.Count -gt 0) {
        $prev.Cloudflare = $prevCloudflare
    }

    if ($prev.Count -gt 0) {
        Write-Information "`e[90m  Previous values from snapshot date: $($previousSnapshot.date)`e[0m"
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
        [decimal]$CurrentUsed,
        [decimal]$CurrentPct,
        [hashtable]$PreviousValues
    )

    if (-not ($PreviousValues.ContainsKey('OrgCopilotUsed') -and $PreviousValues.ContainsKey('OrgCopilotPct'))) {
        return '  - **Delta vs Yesterday**: unavailable (previous diary snapshot missing org-wide GitHub Copilot usage)'
    }

    $requestsDelta = Format-IntDelta -Current ([int][math]::Round($CurrentUsed)) -Previous ([int][math]::Round($PreviousValues.OrgCopilotUsed))
    $pctPointDelta = Format-PctPointDelta -Current $CurrentPct -Previous $PreviousValues.OrgCopilotPct
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

function Get-UsageItemQuantitySum {
    param(
        [object[]]$Items,
        [string[]]$Skus
    )

    $matchingItems = @($Items | Where-Object { $_.sku -in $Skus })
    if ($matchingItems.Count -eq 0) {
        return 0.0
    }

    $sum = ($matchingItems | Measure-Object -Property quantity -Sum).Sum
    if ($null -eq $sum) {
        return 0.0
    }

    return [double]$sum
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
    $previousDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null).AddDays(-1).ToString('yyyy-MM-dd')
    $snapshotPath = Get-RepoSnapshotPath -SnapshotDate $previousDate
    if (-not (Test-Path $snapshotPath)) {
        return $null
    }

    try {
        $snapshot = Get-Content -Path $snapshotPath -Raw | ConvertFrom-Json
        if ($snapshot.repos) {
            return [pscustomobject]@{
                Date = "$($snapshot.date)"
                Repos = @($snapshot.repos | ForEach-Object { "$_" })
            }
        }
    }
    catch {
        Write-Information "`e[1;33mFailed to parse repo snapshot: $([System.IO.Path]::GetFileName($snapshotPath))`e[0m"
    }

    return $null
}

function Get-CloudflareUsageByDomain {
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
try {
    $originalGhUser = gh api /user --jq '.login' 2>$null
}
catch {
    Write-Information "`e[90mUnable to capture the active gh account before fetching daily numbers.`e[0m"
}

$prev = Get-PreviousDiaryValueSnapshot

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
$ghRepoFetchSucceeded = $ghRepoNames.Count -gt 0
$ghRepoCount = if ($ghRepoFetchSucceeded) { $ghRepoNames.Count } else { $null }
if ($ghRepoFetchSucceeded) {
    Save-RepoSnapshot -SnapshotDate $Date -RepoNames $ghRepoNames
}

# --- Fetch Bitbucket repo count ---
Write-Information "`e[1;36mFetching Bitbucket repo count ($BitbucketWorkspace)...`e[0m"
$bbRepoCount = $null
$bbRepoFetchSucceeded = $false
try {
    $bbRepoCount = [int](& (Join-Path $PSScriptRoot 'Get-BitbucketRepoCount.ps1') -OutputDate $Date)
    $bbRepoFetchSucceeded = $true
}
catch {
    Write-Information "`e[1;31mFailed to fetch Bitbucket repo count: $_`e[0m"
}

# --- Compute repo deltas ---
$ghDelta = if ($ghRepoFetchSucceeded -and $prev.ContainsKey('GitHubRepos')) { Format-IntDelta -Current $ghRepoCount -Previous $prev.GitHubRepos } elseif ($ghRepoFetchSucceeded) { '—' } else { 'unavailable' }
$bbDelta = if ($bbRepoFetchSucceeded -and $prev.ContainsKey('BitbucketRepos')) { Format-IntDelta -Current $bbRepoCount -Previous $prev.BitbucketRepos } elseif ($bbRepoFetchSucceeded) { '—' } else { 'unavailable' }
$ghRepoDeltaDetailText = ''

if ($ghRepoFetchSucceeded -and $prev.ContainsKey('GitHubRepos') -and $ghRepoCount -ne $prev.GitHubRepos) {
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
$orgPremiumUsed = $null
$orgQuota = $null
$orgSeats = $null
$orgPct = $null
$cloudAgentRequests = $null
$personalUsed = $null
$personalEntitlement = $null
$personalPct = $null
$orgCopilotFetchSucceeded = $false
$personalCopilotFetchSucceeded = $false

try {
    $billingUsage = gh api "/orgs/Relias-Engineering/settings/billing/usage" | ConvertFrom-Json
    $billing = gh api "/orgs/Relias-Engineering/copilot/billing" | ConvertFrom-Json
    $targetBillingMonth = $Date.Substring(0, 7)
    $monthItems = @(
        $billingUsage.usageItems | Where-Object {
            $_.product -eq 'copilot' -and
            ([datetimeoffset]$_.date).ToString('yyyy-MM') -eq $targetBillingMonth
        }
    )
    $orgPremiumUsed = Get-UsageItemQuantitySum -Items $monthItems -Skus @('Copilot Premium Request')
    $cloudAgentRequests = Get-UsageItemQuantitySum -Items $monthItems -Skus @('Copilot Cloud Agent', 'Coding Agent Premium Request')
    $orgSeats = [int]$billing.seat_breakdown.total
    $orgQuota = $orgSeats * 1000
    $orgPct = if ($orgQuota -gt 0) { [math]::Round(($orgPremiumUsed / $orgQuota) * 100, 1) } else { 0.0 }
    $orgCopilotFetchSucceeded = $true
}
catch {
    Write-Information "`e[1;33mFailed to fetch current org-wide GitHub Copilot usage: $_`e[0m"
}

try {
    $personal = gh api /copilot_internal/user --jq '.quota_snapshots.premium_interactions' | ConvertFrom-Json
    $personalEntitlement = [int]$personal.entitlement
    $personalUsed = $personalEntitlement - [int]$personal.remaining
    $personalPct = if ($personalEntitlement -gt 0) { [math]::Round(($personalUsed / $personalEntitlement) * 100, 1) } else { 0.0 }
    $personalCopilotFetchSucceeded = $true
}
catch {
    Write-Information "`e[1;33mFailed to fetch current personal GitHub Copilot usage: $_`e[0m"
}

$copilotSummaryLine = if ($orgCopilotFetchSucceeded) {
    "- **GitHub Copilot Org-Wide**: $([math]::Round($orgPremiumUsed).ToString('N0')) / $($orgQuota.ToString('N0')) premium requests ($orgPct%)"
}
else {
    '- **GitHub Copilot Org-Wide**: unavailable (billing API request failed)'
}
$copilotCloudAgentLine = if ($orgCopilotFetchSucceeded) {
    "  - **Cloud Agent**: $([math]::Round($cloudAgentRequests).ToString('N0')) requests"
}
else {
    '  - **Cloud Agent**: unavailable'
}
$copilotDeltaLine = if ($orgCopilotFetchSucceeded) {
    Get-CopilotDeltaLine -CurrentUsed $orgPremiumUsed -CurrentPct $orgPct -PreviousValues $prev
}
else {
    '  - **Delta vs Yesterday**: unavailable (current org-wide GitHub Copilot usage unavailable)'
}
$copilotPersonalLine = if ($personalCopilotFetchSucceeded) {
    "  - **Personal (fhemmerrelias)**: $($personalUsed.ToString('N0')) / $($personalEntitlement.ToString('N0')) used ($personalPct%)"
}
else {
    '  - **Personal (fhemmerrelias)**: unavailable (personal Copilot quota request failed)'
}

# --- Fetch Cloudflare usage ---
Write-Information "`e[1;36mFetching Cloudflare usage...`e[0m"
$cloudflareUsage = Get-CloudflareUsageByDomain -TargetDate $Date
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
[void]$sb.AppendLine((
        "- **Relias Repo Count**: GitHub: " +
        $(if ($ghRepoFetchSucceeded) { "$ghRepoCount ($ghDelta$ghRepoDeltaDetailText)" } else { 'unavailable' }) +
        ", Bitbucket: " +
        $(if ($bbRepoFetchSucceeded) { "$bbRepoCount ($bbDelta)" } else { 'unavailable' })
    ))
[void]$sb.AppendLine($copilotSummaryLine)
[void]$sb.AppendLine($copilotCloudAgentLine)
[void]$sb.AppendLine($copilotDeltaLine)
[void]$sb.AppendLine($copilotPersonalLine)
if ($cloudflareLines.Count -gt 0) {
    [void]$sb.AppendLine('- **Cloudflare Usage**:')
    foreach ($line in $cloudflareLines) {
        [void]$sb.AppendLine($line)
    }
}

$numbersContent = $sb.ToString().TrimEnd()

$snapshotCloudflare = [ordered]@{}
foreach ($domain in $CloudflareDomains) {
    if ($cloudflareUsage.ContainsKey($domain.Name)) {
        $stats = $cloudflareUsage[$domain.Name]
        $snapshotCloudflare[$domain.Name] = [ordered]@{
            pageViews = $stats.PageViews
            uniqueVisitors = $stats.UniqueVisitors
            emailsForwarded = if ($domain.HasEmailRouting) { $stats.EmailsForwarded } else { $null }
        }
    }
}
Save-DiarySnapshotJson -ScriptRoot $PSScriptRoot -Date $Date -Name 'daily-numbers' -Payload @{
    date = $Date
    githubRepos = if ($ghRepoFetchSucceeded) { $ghRepoCount } else { $null }
    bitbucketRepos = if ($bbRepoFetchSucceeded) { $bbRepoCount } else { $null }
    copilot = @{
        orgPremium = if ($orgCopilotFetchSucceeded) { $orgPremiumUsed } else { $null }
        orgPct = if ($orgCopilotFetchSucceeded) { $orgPct } else { $null }
        orgQuota = if ($orgCopilotFetchSucceeded) { $orgQuota } else { $null }
        cloudAgent = if ($orgCopilotFetchSucceeded) { $cloudAgentRequests } else { $null }
        personalUsed = if ($personalCopilotFetchSucceeded) { $personalUsed } else { $null }
        personalEntitlement = if ($personalCopilotFetchSucceeded) { $personalEntitlement } else { $null }
        personalPct = if ($personalCopilotFetchSucceeded) { $personalPct } else { $null }
    }
    cloudflare = $snapshotCloudflare
}

# --- Inject into diary entry ---
$sectionHtml = ConvertTo-DiaryHtmlCard -Markdown $numbersContent -Eyebrow "Daily numbers snapshot for $Date"
Set-DiarySectionInnerHtml -EntryPath $EntryPath -SectionTitle '📊 Daily Numbers' -InnerHtml $sectionHtml
Write-Information "`e[1;32mDaily numbers injected into diary entry.`e[0m"
if ($dowLine) { Write-Information "  Dow: $($dowPrice.ToString('N2')) | S&P: $($spPrice.ToString('N2'))" }
Write-Information "  GitHub: $(if ($ghRepoFetchSucceeded) { "$ghRepoCount ($ghDelta$ghRepoDeltaDetailText)" } else { 'unavailable' }) | Bitbucket: $(if ($bbRepoFetchSucceeded) { "$bbRepoCount ($bbDelta)" } else { 'unavailable' })"
Write-Information "  Copilot org-wide: $(if ($orgCopilotFetchSucceeded) { "$([math]::Round($orgPremiumUsed).ToString('N0')) / $($orgQuota.ToString('N0'))" } else { 'unavailable' })"

# --- Restore original gh account ---
if ($originalGhUser) {
    gh auth switch -u $originalGhUser 2>&1 | Out-Null
}
