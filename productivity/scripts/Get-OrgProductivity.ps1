#Requires -Version 7.0
<#
.SYNOPSIS
    Measures and ranks the most productive repositories in a GitHub organization.
.DESCRIPTION
    Uses GitHub GraphQL API for bulk data collection (2-3 calls for 200+ repos)
    and REST API for detailed stats on top repos only. Generates a visually rich
    HTML report with rankings, charts, and badges.

    Rate-limit safe: typically under 30 API calls total for 200+ repos.
.PARAMETER Org
    The GitHub organization name to analyze.
.PARAMETER Days
    Number of days to look back for activity metrics. Default: 30.
.PARAMETER TopN
    Number of top repos to show detailed stats for. Default: 25.
.PARAMETER OutputPath
    Path for the HTML report. Default: org-productivity-{org}-{date}.html in current directory.
.PARAMETER ThrottleMs
    Milliseconds to wait between REST API calls. Default: 100.
.PARAMETER IncludeArchived
    Include archived repositories in the analysis.
.PARAMETER IncludeForks
    Include forked repositories in the analysis.
.EXAMPLE
    .\Get-OrgProductivity.ps1 -Org "relias-engineering"
.EXAMPLE
    .\Get-OrgProductivity.ps1 -Org "microsoft" -Days 90 -TopN 50
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Org,

    [ValidateRange(1, 365)]
    [int]$Days = 30,

    [ValidateRange(5, 100)]
    [int]$TopN = 25,

    [string]$OutputPath,

    [ValidateRange(0, 5000)]
    [int]$ThrottleMs = 100,

    [switch]$IncludeArchived,

    [switch]$IncludeForks
)

$ErrorActionPreference = 'Stop'

# ── Verify gh CLI ────────────────────────────────────────────────────
try {
    $null = gh auth status 2>&1
}
catch {
    Write-Error "GitHub CLI not authenticated. Run 'gh auth login' first."
    return
}

$ReportDate = Get-Date -Format "yyyy-MM-dd"

if (-not $OutputPath) {
    $OutputPath = Join-Path $PWD "org-productivity-$Org-$ReportDate.html"
}

Write-Information "Analyzing $Org for the past $Days days..." -InformationAction Continue

# ── Phase 1: GraphQL bulk fetch ──────────────────────────────────────
# Fetches repos with: stars, forks, issues, PRs, recent commits, languages, updated date
# 100 repos per query = 2-3 calls for 200+ repos

$AllRepos = [System.Collections.Generic.List[object]]::new()
$cursor = $null
$page = 0

do {
    $page++
    $afterClause = if ($cursor) { ", after: `"$cursor`"" } else { "" }

    # Lightweight query: no commit history, no release nodes (avoids RESOURCE_LIMITS_EXCEEDED)
    $query = @"
query {
  organization(login: "$Org") {
    repositories(first: 50, orderBy: {field: PUSHED_AT, direction: DESC}$afterClause) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        name
        url
        description
        isArchived
        isFork
        isPrivate
        primaryLanguage { name color }
        stargazerCount
        forkCount
        diskUsage
        pushedAt
        updatedAt
        createdAt
        licenseInfo { spdxId }
        issues(states: OPEN) { totalCount }
        closedIssues: issues(states: CLOSED) { totalCount }
        pullRequests(states: OPEN) { totalCount }
        mergedPRs: pullRequests(states: MERGED, first: 0) { totalCount }
        releases { totalCount }
      }
    }
  }
}
"@

    Write-Information "  GraphQL page $page..." -InformationAction Continue

    # Write query to temp file to avoid PowerShell stdin/encoding issues on Windows
    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmpFile, $query)
        $result = gh api graphql -f "query=$(Get-Content $tmpFile -Raw)" 2>&1
    }
    finally {
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "GraphQL query failed: $result"
        return
    }

    $data = $result | ConvertFrom-Json

    # Check for partial errors but continue if we got data
    if ($data.errors) {
        Write-Information "  Warning: GraphQL returned partial errors on page $page (continuing with available data)" -InformationAction Continue
    }

    $repos = $data.data.organization.repositories

    foreach ($node in $repos.nodes) {
        if ($null -eq $node) { continue }
        if (-not $IncludeArchived -and $node.isArchived) { continue }
        if (-not $IncludeForks -and $node.isFork) { continue }

        $AllRepos.Add([PSCustomObject]@{
            Name           = $node.name
            Url            = $node.url
            Description    = $node.description
            IsPrivate      = $node.isPrivate
            Language       = if ($node.primaryLanguage) { $node.primaryLanguage.name } else { "None" }
            LanguageColor  = if ($node.primaryLanguage) { $node.primaryLanguage.color } else { "#888" }
            Stars          = $node.stargazerCount
            Forks          = $node.forkCount
            OpenIssues     = $node.issues.totalCount
            ClosedIssues   = $node.closedIssues.totalCount
            OpenPRs        = $node.pullRequests.totalCount
            MergedPRs      = $node.mergedPRs.totalCount
            RecentCommits  = 0
            PushedAt       = $node.pushedAt
            CreatedAt      = $node.createdAt
            DiskUsageMB    = [math]::Round($node.diskUsage / 1024, 1)
            Releases       = $node.releases.totalCount
            LatestRelease  = $null
            License        = if ($node.licenseInfo) { $node.licenseInfo.spdxId } else { $null }
            # These will be populated for top repos only
            Contributors   = 0
            WeeklyCommits  = @()
        })
    }

    $cursor = $repos.pageInfo.endCursor
    $hasNext = $repos.pageInfo.hasNextPage
    $totalCount = $repos.totalCount

} while ($hasNext)

Write-Information "  Found $($AllRepos.Count) repos (of $totalCount total, filtered)." -InformationAction Continue

# ── Phase 1.5: Get recent commit counts via REST for active repos ────
# Uses /stats/participation (cached, lightweight) for repos pushed within our window
$weeksNeeded = [math]::Ceiling($Days / 7)
$activeRepos = $AllRepos | Where-Object {
    $_.PushedAt -and ([datetime]$_.PushedAt) -gt (Get-Date).AddDays(-$Days)
}

Write-Information "  Fetching commit stats for $($activeRepos.Count) recently-active repos..." -InformationAction Continue
$commitFetchCount = 0
foreach ($repo in $activeRepos) {
    $commitFetchCount++
    if ($commitFetchCount % 20 -eq 0) {
        Write-Information "    ... $commitFetchCount / $($activeRepos.Count)" -InformationAction Continue
    }
    try {
        $partData = gh api "repos/$Org/$($repo.Name)/stats/participation" 2>&1
        if ($LASTEXITCODE -eq 0 -and $partData -notmatch '^202$') {
            $participation = $partData | ConvertFrom-Json
            if ($participation.all) {
                $recentWeeks = $participation.all | Select-Object -Last $weeksNeeded
                $repo.RecentCommits = ($recentWeeks | Measure-Object -Sum).Sum
            }
        }
    }
    catch {
        Write-Verbose "Skipping participation stats for $($repo.Name): $_"
    }
    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
}

# ── Phase 2: Calculate productivity scores ───────────────────────────
# Composite score: commits 40%, merged PRs 25%, closed issues 15%, stars 10%, freshness 10%

$maxCommits = ($AllRepos | Measure-Object -Property RecentCommits -Maximum).Maximum
$maxMergedPRs = ($AllRepos | Measure-Object -Property MergedPRs -Maximum).Maximum
$maxClosedIssues = ($AllRepos | Measure-Object -Property ClosedIssues -Maximum).Maximum
$maxStars = ($AllRepos | Measure-Object -Property Stars -Maximum).Maximum

# Avoid divide by zero
if ($maxCommits -eq 0) { $maxCommits = 1 }
if ($maxMergedPRs -eq 0) { $maxMergedPRs = 1 }
if ($maxClosedIssues -eq 0) { $maxClosedIssues = 1 }
if ($maxStars -eq 0) { $maxStars = 1 }

$now = Get-Date
foreach ($repo in $AllRepos) {
    $commitScore = ($repo.RecentCommits / $maxCommits) * 40
    $prScore = ($repo.MergedPRs / $maxMergedPRs) * 25
    $issueScore = ($repo.ClosedIssues / $maxClosedIssues) * 15
    $starScore = ($repo.Stars / $maxStars) * 10

    # Freshness: how recently was it pushed? Scale 0-10
    $daysSincePush = if ($repo.PushedAt) {
        ($now - [datetime]$repo.PushedAt).TotalDays
    } else { $Days }

    $freshnessScore = [math]::Max(0, (1 - ($daysSincePush / $Days))) * 10

    $repo | Add-Member -NotePropertyName ProductivityScore -NotePropertyValue (
        [math]::Round($commitScore + $prScore + $issueScore + $starScore + $freshnessScore, 1)
    ) -Force

    # Activity level badge
    $level = if ($repo.ProductivityScore -ge 70) { "on-fire" }
             elseif ($repo.ProductivityScore -ge 40) { "active" }
             elseif ($repo.ProductivityScore -ge 15) { "steady" }
             elseif ($repo.RecentCommits -gt 0) { "idle" }
             else { "dormant" }

    $repo | Add-Member -NotePropertyName ActivityLevel -NotePropertyValue $level -Force
}

# Sort by productivity score
$AllRepos = $AllRepos | Sort-Object -Property ProductivityScore -Descending
$TopRepos = $AllRepos | Select-Object -First $TopN

Write-Information "  Top repo: $($TopRepos[0].Name) (score: $($TopRepos[0].ProductivityScore))" -InformationAction Continue

# ── Phase 3: Detailed stats for top N repos (REST API) ──────────────
# Only for the top repos — keeps API calls minimal

$detailIndex = 0
foreach ($repo in $TopRepos) {
    $detailIndex++
    Write-Information "  Fetching details ${detailIndex}/${TopN}: $($repo.Name)..." -InformationAction Continue

    # Get contributor count
    try {
        $contribData = gh api "repos/$Org/$($repo.Name)/contributors?per_page=100&anon=true" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $contribs = $contribData | ConvertFrom-Json
            $repo.Contributors = $contribs.Count
        }
    }
    catch {
        Write-Verbose "Skipping contributor stats for $($repo.Name): $_"
    }

    # Get weekly commit activity (last 52 weeks)
    try {
        $weeklyData = gh api "repos/$Org/$($repo.Name)/stats/commit_activity" 2>&1
        if ($LASTEXITCODE -eq 0 -and $weeklyData -ne "202") {
            $weeklyRaw = $weeklyData | ConvertFrom-Json
            # Take last N weeks matching our Days window
            $weeksToShow = [math]::Ceiling($Days / 7)
            $repo.WeeklyCommits = @(($weeklyRaw | Select-Object -Last $weeksToShow).total)
        }
    }
    catch {
        Write-Verbose "Skipping weekly commit stats for $($repo.Name): $_"
    }

    if ($ThrottleMs -gt 0) {
        Start-Sleep -Milliseconds $ThrottleMs
    }
}

# ── Phase 4: Aggregate org-level stats ───────────────────────────────
$OrgStats = [PSCustomObject]@{
    TotalRepos       = $AllRepos.Count
    ActiveRepos      = ($AllRepos | Where-Object { $_.RecentCommits -gt 0 }).Count
    TotalCommits     = ($AllRepos | Measure-Object -Property RecentCommits -Sum).Sum
    TotalMergedPRs   = ($AllRepos | Measure-Object -Property MergedPRs -Sum).Sum
    TotalOpenPRs     = ($AllRepos | Measure-Object -Property OpenPRs -Sum).Sum
    TotalOpenIssues  = ($AllRepos | Measure-Object -Property OpenIssues -Sum).Sum
    TotalClosedIssues= ($AllRepos | Measure-Object -Property ClosedIssues -Sum).Sum
    TotalStars       = ($AllRepos | Measure-Object -Property Stars -Sum).Sum
    TotalForks       = ($AllRepos | Measure-Object -Property Forks -Sum).Sum
    TopLanguages     = ($AllRepos | Where-Object { $_.Language -ne "None" } |
                        Group-Object Language | Sort-Object Count -Descending |
                        Select-Object -First 10 @{N='Language';E={$_.Name}}, Count,
                        @{N='Color';E={($_.Group | Select-Object -First 1).LanguageColor}})
    OnFire           = ($AllRepos | Where-Object { $_.ActivityLevel -eq "on-fire" }).Count
    Active           = ($AllRepos | Where-Object { $_.ActivityLevel -eq "active" }).Count
    Steady           = ($AllRepos | Where-Object { $_.ActivityLevel -eq "steady" }).Count
    Idle             = ($AllRepos | Where-Object { $_.ActivityLevel -eq "idle" }).Count
    Dormant          = ($AllRepos | Where-Object { $_.ActivityLevel -eq "dormant" }).Count
}

# ── Phase 5: Generate HTML Report ────────────────────────────────────
Write-Information "  Generating HTML report..." -InformationAction Continue

# Build top repos JSON for charts
$topReposJson = ($TopRepos | ForEach-Object {
    $weeklyJson = if ($_.WeeklyCommits.Count -gt 0) {
        "[$(($_.WeeklyCommits -join ','))]"
    } else { "[]" }

    @"
    {
      "name": "$($_.Name)",
      "url": "$($_.Url)",
      "score": $($_.ProductivityScore),
      "commits": $($_.RecentCommits),
      "mergedPRs": $($_.MergedPRs),
      "openPRs": $($_.OpenPRs),
      "openIssues": $($_.OpenIssues),
      "closedIssues": $($_.ClosedIssues),
      "stars": $($_.Stars),
      "forks": $($_.Forks),
      "contributors": $($_.Contributors),
      "language": "$($_.Language)",
      "languageColor": "$($_.LanguageColor)",
      "description": $(if ($_.Description) { """$($_.Description -replace '"','\"' -replace "`n",' ')""" } else { "null" }),
      "diskUsageMB": $($_.DiskUsageMB),
      "releases": $($_.Releases),
      "latestRelease": $(if ($_.LatestRelease) { """$($_.LatestRelease)""" } else { "null" }),
      "level": "$($_.ActivityLevel)",
      "pushedAt": "$($_.PushedAt)",
      "weeklyCommits": $weeklyJson
    }
"@
}) -join ",`n"

# Language stats JSON
$langJson = ($OrgStats.TopLanguages | ForEach-Object {
    "{`"lang`":`"$($_.Language)`",`"count`":$($_.Count),`"color`":`"$($_.Color)`"}"
}) -join ","

# All repos for the full table
$allReposJson = ($AllRepos | ForEach-Object {
    @"
    {
      "name": "$($_.Name)",
      "url": "$($_.Url)",
      "score": $($_.ProductivityScore),
      "commits": $($_.RecentCommits),
      "mergedPRs": $($_.MergedPRs),
      "stars": $($_.Stars),
      "language": "$($_.Language)",
      "languageColor": "$($_.LanguageColor)",
      "level": "$($_.ActivityLevel)",
      "pushedAt": "$($_.PushedAt)"
    }
"@
}) -join ",`n"

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$Org — Repository Productivity Report</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&family=Outfit:wght@300;400;500;600;700;800;900&display=swap');

  :root {
    --bg-primary: #0a0e17;
    --bg-secondary: #111827;
    --bg-card: #1a2234;
    --bg-card-hover: #1f2a40;
    --border: #2a3650;
    --text-primary: #e2e8f0;
    --text-secondary: #94a3b8;
    --text-muted: #64748b;
    --accent-fire: #f97316;
    --accent-fire-glow: rgba(249, 115, 22, 0.3);
    --accent-active: #22d3ee;
    --accent-active-glow: rgba(34, 211, 238, 0.2);
    --accent-steady: #a78bfa;
    --accent-idle: #64748b;
    --accent-dormant: #334155;
    --accent-gold: #fbbf24;
    --accent-silver: #94a3b8;
    --accent-bronze: #d97706;
    --gradient-fire: linear-gradient(135deg, #f97316, #ef4444, #f97316);
    --gradient-hero: linear-gradient(135deg, #0a0e17 0%, #1a1040 40%, #0f2027 100%);
  }

  * { margin: 0; padding: 0; box-sizing: border-box; }

  body {
    font-family: 'Outfit', system-ui, sans-serif;
    background: var(--bg-primary);
    color: var(--text-primary);
    line-height: 1.6;
    min-height: 100vh;
  }

  .hero {
    background: var(--gradient-hero);
    padding: 3rem 2rem 2rem;
    text-align: center;
    position: relative;
    overflow: hidden;
    border-bottom: 1px solid var(--border);
  }

  .hero::before {
    content: '';
    position: absolute;
    top: -50%;
    left: -50%;
    width: 200%;
    height: 200%;
    background: radial-gradient(ellipse at 30% 50%, rgba(139, 92, 246, 0.08) 0%, transparent 50%),
                radial-gradient(ellipse at 70% 50%, rgba(34, 211, 238, 0.06) 0%, transparent 50%);
    animation: aurora 20s ease-in-out infinite alternate;
  }

  @keyframes aurora {
    0% { transform: translate(0, 0) rotate(0deg); }
    100% { transform: translate(-5%, 3%) rotate(2deg); }
  }

  .hero-content { position: relative; z-index: 1; max-width: 1200px; margin: 0 auto; }

  .hero h1 {
    font-size: 2.8rem;
    font-weight: 900;
    letter-spacing: -0.03em;
    background: linear-gradient(135deg, #e2e8f0, #a78bfa, #22d3ee);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin-bottom: 0.25rem;
  }

  .hero .org-name {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1.1rem;
    color: var(--text-muted);
    margin-bottom: 0.5rem;
  }

  .hero .meta {
    font-size: 0.85rem;
    color: var(--text-muted);
  }

  /* ── Stat Cards ─────────────────────────────────── */
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 1rem;
    max-width: 1200px;
    margin: -1.5rem auto 2rem;
    padding: 0 2rem;
    position: relative;
    z-index: 2;
  }

  .stat-card {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 1.25rem;
    text-align: center;
    transition: transform 0.2s, border-color 0.2s;
  }

  .stat-card:hover {
    transform: translateY(-2px);
    border-color: var(--accent-active);
  }

  .stat-card .value {
    font-size: 2rem;
    font-weight: 800;
    font-family: 'JetBrains Mono', monospace;
    background: linear-gradient(135deg, var(--accent-active), var(--accent-steady));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }

  .stat-card .label {
    font-size: 0.8rem;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    font-weight: 600;
    margin-top: 0.25rem;
  }

  /* ── Section layout ─────────────────────────────── */
  .container { max-width: 1200px; margin: 0 auto; padding: 0 2rem 3rem; }

  .section-title {
    font-size: 1.5rem;
    font-weight: 700;
    margin: 2.5rem 0 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .section-title .icon { font-size: 1.3rem; }

  /* ── Podium (Top 3) ─────────────────────────────── */
  .podium {
    display: flex;
    justify-content: center;
    align-items: flex-end;
    gap: 1rem;
    margin: 2rem 0;
    min-height: 320px;
  }

  .podium-item {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 1.5rem;
    text-align: center;
    width: 260px;
    transition: transform 0.2s, box-shadow 0.2s;
    position: relative;
  }

  .podium-item:hover { transform: translateY(-4px); }

  .podium-item.gold {
    border-color: var(--accent-gold);
    box-shadow: 0 0 30px rgba(251, 191, 36, 0.15);
    min-height: 280px;
  }

  .podium-item.silver {
    border-color: var(--accent-silver);
    box-shadow: 0 0 20px rgba(148, 163, 184, 0.1);
    min-height: 240px;
  }

  .podium-item.bronze {
    border-color: var(--accent-bronze);
    box-shadow: 0 0 20px rgba(217, 119, 6, 0.1);
    min-height: 220px;
  }

  .podium-medal {
    font-size: 2.5rem;
    margin-bottom: 0.5rem;
  }

  .podium-name {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.95rem;
    font-weight: 700;
    margin-bottom: 0.25rem;
    word-break: break-all;
  }

  .podium-name a {
    color: inherit;
    text-decoration: none;
  }

  .podium-name a:hover { text-decoration: underline; }

  .podium-score {
    font-size: 2rem;
    font-weight: 900;
    font-family: 'JetBrains Mono', monospace;
  }

  .gold .podium-score { color: var(--accent-gold); }
  .silver .podium-score { color: var(--accent-silver); }
  .bronze .podium-score { color: var(--accent-bronze); }

  .podium-stats {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.35rem;
    margin-top: 0.75rem;
    font-size: 0.75rem;
    color: var(--text-secondary);
  }

  .podium-stats span { font-family: 'JetBrains Mono', monospace; }

  /* ── Activity breakdown ─────────────────────────── */
  .activity-bar {
    display: flex;
    height: 28px;
    border-radius: 8px;
    overflow: hidden;
    margin: 1rem 0;
    border: 1px solid var(--border);
  }

  .activity-bar div { transition: width 0.6s ease; min-width: 0; }
  .ab-fire { background: var(--accent-fire); }
  .ab-active { background: var(--accent-active); }
  .ab-steady { background: var(--accent-steady); }
  .ab-idle { background: var(--accent-idle); }
  .ab-dormant { background: var(--accent-dormant); }

  .activity-legend {
    display: flex;
    gap: 1.5rem;
    flex-wrap: wrap;
    font-size: 0.8rem;
    color: var(--text-secondary);
  }

  .activity-legend span {
    display: flex;
    align-items: center;
    gap: 0.35rem;
  }

  .legend-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    display: inline-block;
  }

  /* ── Language chart ─────────────────────────────── */
  .lang-bars { display: flex; flex-direction: column; gap: 0.5rem; margin: 1rem 0; }

  .lang-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .lang-label {
    width: 110px;
    font-size: 0.8rem;
    font-weight: 600;
    text-align: right;
    flex-shrink: 0;
  }

  .lang-bar-container {
    flex: 1;
    height: 22px;
    background: var(--bg-secondary);
    border-radius: 6px;
    overflow: hidden;
  }

  .lang-bar-fill {
    height: 100%;
    border-radius: 6px;
    transition: width 0.8s ease;
    display: flex;
    align-items: center;
    padding-left: 8px;
    font-size: 0.7rem;
    font-family: 'JetBrains Mono', monospace;
    font-weight: 600;
    color: rgba(0,0,0,0.7);
  }

  /* ── Repo cards grid ────────────────────────────── */
  .repo-cards {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
    gap: 1rem;
    margin: 1rem 0;
  }

  .repo-card {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 1.25rem;
    transition: transform 0.15s, border-color 0.15s;
    position: relative;
  }

  .repo-card:hover {
    transform: translateY(-2px);
    border-color: var(--accent-active);
  }

  .repo-card .rank {
    position: absolute;
    top: -8px;
    right: 12px;
    background: var(--bg-secondary);
    border: 1px solid var(--border);
    border-radius: 20px;
    padding: 2px 10px;
    font-size: 0.7rem;
    font-weight: 700;
    font-family: 'JetBrains Mono', monospace;
    color: var(--text-muted);
  }

  .repo-card .card-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.5rem;
  }

  .repo-card .card-name {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.9rem;
    font-weight: 700;
  }

  .repo-card .card-name a { color: var(--text-primary); text-decoration: none; }
  .repo-card .card-name a:hover { text-decoration: underline; }

  .repo-card .card-desc {
    font-size: 0.78rem;
    color: var(--text-muted);
    margin-bottom: 0.75rem;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .repo-card .card-metrics {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.35rem;
  }

  .repo-card .metric {
    text-align: center;
    padding: 0.35rem;
    background: var(--bg-secondary);
    border-radius: 6px;
    font-size: 0.72rem;
  }

  .repo-card .metric .metric-val {
    font-family: 'JetBrains Mono', monospace;
    font-weight: 700;
    font-size: 0.9rem;
    display: block;
    color: var(--accent-active);
  }

  .repo-card .metric .metric-label {
    color: var(--text-muted);
    font-size: 0.65rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .level-badge {
    font-size: 0.65rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    padding: 2px 8px;
    border-radius: 20px;
    white-space: nowrap;
  }

  .level-on-fire { background: rgba(249,115,22,0.15); color: var(--accent-fire); }
  .level-active { background: rgba(34,211,238,0.15); color: var(--accent-active); }
  .level-steady { background: rgba(167,139,250,0.15); color: var(--accent-steady); }
  .level-idle { background: rgba(100,116,139,0.15); color: var(--accent-idle); }
  .level-dormant { background: rgba(51,65,85,0.3); color: var(--text-muted); }

  /* ── Sparkline (SVG) ────────────────────────────── */
  .sparkline {
    margin-top: 0.5rem;
    width: 100%;
    height: 30px;
  }

  .sparkline polyline {
    fill: none;
    stroke: var(--accent-active);
    stroke-width: 1.5;
    stroke-linecap: round;
    stroke-linejoin: round;
  }

  .sparkline .fill {
    fill: rgba(34, 211, 238, 0.1);
    stroke: none;
  }

  /* ── Full table ─────────────────────────────────── */
  .table-controls {
    display: flex;
    gap: 1rem;
    margin-bottom: 1rem;
    flex-wrap: wrap;
    align-items: center;
  }

  .search-input {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 0.5rem 1rem;
    color: var(--text-primary);
    font-family: 'Outfit', sans-serif;
    font-size: 0.85rem;
    width: 260px;
    outline: none;
    transition: border-color 0.2s;
  }

  .search-input:focus { border-color: var(--accent-active); }
  .search-input::placeholder { color: var(--text-muted); }

  .filter-btn {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 0.5rem 1rem;
    color: var(--text-secondary);
    cursor: pointer;
    font-family: 'Outfit', sans-serif;
    font-size: 0.8rem;
    font-weight: 600;
    transition: all 0.15s;
  }

  .filter-btn:hover, .filter-btn.active {
    border-color: var(--accent-active);
    color: var(--accent-active);
    background: rgba(34, 211, 238, 0.05);
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.8rem;
  }

  thead th {
    background: var(--bg-secondary);
    padding: 0.6rem 0.75rem;
    text-align: left;
    font-weight: 700;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--text-muted);
    border-bottom: 1px solid var(--border);
    cursor: pointer;
    user-select: none;
    white-space: nowrap;
  }

  thead th:hover { color: var(--accent-active); }
  thead th.sorted-asc::after { content: ' ▲'; color: var(--accent-active); }
  thead th.sorted-desc::after { content: ' ▼'; color: var(--accent-active); }

  tbody tr {
    border-bottom: 1px solid var(--border);
    transition: background 0.1s;
  }

  tbody tr:hover { background: var(--bg-card-hover); }

  td {
    padding: 0.5rem 0.75rem;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.78rem;
    white-space: nowrap;
  }

  td a { color: var(--accent-active); text-decoration: none; }
  td a:hover { text-decoration: underline; }

  td .lang-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    margin-right: 4px;
    vertical-align: middle;
  }

  /* ── Footer ─────────────────────────────────────── */
  .footer {
    text-align: center;
    padding: 2rem;
    font-size: 0.75rem;
    color: var(--text-muted);
    border-top: 1px solid var(--border);
  }

  .footer a { color: var(--accent-active); text-decoration: none; }

  /* ── Animations ─────────────────────────────────── */
  @keyframes fadeInUp {
    from { opacity: 0; transform: translateY(20px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .animate-in {
    animation: fadeInUp 0.5s ease forwards;
    opacity: 0;
  }

  .delay-1 { animation-delay: 0.1s; }
  .delay-2 { animation-delay: 0.2s; }
  .delay-3 { animation-delay: 0.3s; }
  .delay-4 { animation-delay: 0.4s; }

  /* ── Responsive ─────────────────────────────────── */
  @media (max-width: 768px) {
    .hero h1 { font-size: 1.8rem; }
    .podium { flex-direction: column; align-items: center; }
    .podium-item { width: 100%; min-height: auto !important; }
    .stats-grid { grid-template-columns: repeat(2, 1fr); }
    .repo-cards { grid-template-columns: 1fr; }
    .search-input { width: 100%; }
  }
</style>
</head>
<body>

<div class="hero">
  <div class="hero-content">
    <h1>Repository Productivity</h1>
    <div class="org-name">$Org</div>
    <div class="meta">$Days-day window ending $ReportDate &bull; $($AllRepos.Count) repositories analyzed</div>
  </div>
</div>

<!-- Org-level stats -->
<div class="stats-grid">
  <div class="stat-card animate-in delay-1">
    <div class="value">$($OrgStats.TotalRepos)</div>
    <div class="label">Repositories</div>
  </div>
  <div class="stat-card animate-in delay-1">
    <div class="value">$($OrgStats.ActiveRepos)</div>
    <div class="label">Active ($Days d)</div>
  </div>
  <div class="stat-card animate-in delay-2">
    <div class="value">$($OrgStats.TotalCommits.ToString('N0'))</div>
    <div class="label">Commits</div>
  </div>
  <div class="stat-card animate-in delay-2">
    <div class="value">$($OrgStats.TotalMergedPRs.ToString('N0'))</div>
    <div class="label">Merged PRs</div>
  </div>
  <div class="stat-card animate-in delay-3">
    <div class="value">$($OrgStats.TotalOpenPRs.ToString('N0'))</div>
    <div class="label">Open PRs</div>
  </div>
  <div class="stat-card animate-in delay-3">
    <div class="value">$($OrgStats.TotalStars.ToString('N0'))</div>
    <div class="label">Total Stars</div>
  </div>
</div>

<div class="container">

  <!-- Activity Distribution -->
  <h2 class="section-title"><span class="icon">📊</span> Activity Distribution</h2>
  <div class="activity-bar">
    <div class="ab-fire" style="width: $([math]::Round($OrgStats.OnFire / [math]::Max($AllRepos.Count,1) * 100, 1))%"></div>
    <div class="ab-active" style="width: $([math]::Round($OrgStats.Active / [math]::Max($AllRepos.Count,1) * 100, 1))%"></div>
    <div class="ab-steady" style="width: $([math]::Round($OrgStats.Steady / [math]::Max($AllRepos.Count,1) * 100, 1))%"></div>
    <div class="ab-idle" style="width: $([math]::Round($OrgStats.Idle / [math]::Max($AllRepos.Count,1) * 100, 1))%"></div>
    <div class="ab-dormant" style="width: $([math]::Round($OrgStats.Dormant / [math]::Max($AllRepos.Count,1) * 100, 1))%"></div>
  </div>
  <div class="activity-legend">
    <span><span class="legend-dot" style="background:var(--accent-fire)"></span> On Fire ($($OrgStats.OnFire))</span>
    <span><span class="legend-dot" style="background:var(--accent-active)"></span> Active ($($OrgStats.Active))</span>
    <span><span class="legend-dot" style="background:var(--accent-steady)"></span> Steady ($($OrgStats.Steady))</span>
    <span><span class="legend-dot" style="background:var(--accent-idle)"></span> Idle ($($OrgStats.Idle))</span>
    <span><span class="legend-dot" style="background:var(--accent-dormant)"></span> Dormant ($($OrgStats.Dormant))</span>
  </div>

  <!-- Top 3 Podium -->
  <h2 class="section-title"><span class="icon">🏆</span> Top 3 Most Productive</h2>
  <div class="podium">
    $(if ($TopRepos.Count -ge 2) {
      $r = $TopRepos[1]
      @"
    <div class="podium-item silver animate-in delay-2">
      <div class="podium-medal">🥈</div>
      <div class="podium-name"><a href="$($r.Url)" target="_blank">$($r.Name)</a></div>
      <div class="podium-score">$($r.ProductivityScore)</div>
      <div class="podium-stats">
        <span>$($r.RecentCommits) commits</span>
        <span>$($r.MergedPRs) merged</span>
        <span>⭐ $($r.Stars)</span>
        <span>$($r.Contributors) devs</span>
      </div>
    </div>
"@
    })
    $(if ($TopRepos.Count -ge 1) {
      $r = $TopRepos[0]
      @"
    <div class="podium-item gold animate-in delay-1">
      <div class="podium-medal">🥇</div>
      <div class="podium-name"><a href="$($r.Url)" target="_blank">$($r.Name)</a></div>
      <div class="podium-score">$($r.ProductivityScore)</div>
      <div class="podium-stats">
        <span>$($r.RecentCommits) commits</span>
        <span>$($r.MergedPRs) merged</span>
        <span>⭐ $($r.Stars)</span>
        <span>$($r.Contributors) devs</span>
      </div>
    </div>
"@
    })
    $(if ($TopRepos.Count -ge 3) {
      $r = $TopRepos[2]
      @"
    <div class="podium-item bronze animate-in delay-3">
      <div class="podium-medal">🥉</div>
      <div class="podium-name"><a href="$($r.Url)" target="_blank">$($r.Name)</a></div>
      <div class="podium-score">$($r.ProductivityScore)</div>
      <div class="podium-stats">
        <span>$($r.RecentCommits) commits</span>
        <span>$($r.MergedPRs) merged</span>
        <span>⭐ $($r.Stars)</span>
        <span>$($r.Contributors) devs</span>
      </div>
    </div>
"@
    })
  </div>

  <!-- Language Distribution -->
  <h2 class="section-title"><span class="icon">🔤</span> Top Languages</h2>
  <div class="lang-bars" id="langBars"></div>

  <!-- Top Repo Cards -->
  <h2 class="section-title"><span class="icon">🚀</span> Top $TopN Repositories</h2>
  <div class="repo-cards" id="repoCards"></div>

  <!-- Full Table -->
  <h2 class="section-title"><span class="icon">📋</span> All Repositories</h2>
  <div class="table-controls">
    <input type="text" class="search-input" id="searchInput" placeholder="Search repos...">
    <button class="filter-btn active" data-filter="all">All</button>
    <button class="filter-btn" data-filter="on-fire">🔥 On Fire</button>
    <button class="filter-btn" data-filter="active">⚡ Active</button>
    <button class="filter-btn" data-filter="steady">📈 Steady</button>
    <button class="filter-btn" data-filter="idle">💤 Idle</button>
    <button class="filter-btn" data-filter="dormant">🪦 Dormant</button>
  </div>
  <div style="overflow-x:auto;">
    <table id="repoTable">
      <thead>
        <tr>
          <th data-sort="rank">#</th>
          <th data-sort="name">Repository</th>
          <th data-sort="score">Score</th>
          <th data-sort="commits">Commits</th>
          <th data-sort="mergedPRs">Merged PRs</th>
          <th data-sort="stars">Stars</th>
          <th data-sort="language">Language</th>
          <th data-sort="level">Status</th>
          <th data-sort="pushedAt">Last Push</th>
        </tr>
      </thead>
      <tbody id="repoTableBody"></tbody>
    </table>
  </div>
</div>

<div class="footer">
  Generated on $ReportDate by <a href="https://github.com">Get-OrgProductivity.ps1</a> &bull;
  $($AllRepos.Count) repos &bull; ${Days}-day window &bull;
  Data sourced from GitHub API (GraphQL + REST)
</div>

<script>
// ── Data ─────────────────────────────────────────────────
const topRepos = [$topReposJson];
const allRepos = [$allReposJson];
const languages = [$langJson];

// ── Language bars ────────────────────────────────────────
(function renderLangs() {
  const container = document.getElementById('langBars');
  const maxCount = languages.length ? languages[0].count : 1;
  languages.forEach(l => {
    const pct = Math.round(l.count / maxCount * 100);
    container.innerHTML += '<div class="lang-row">' +
      '<div class="lang-label">' + l.lang + '</div>' +
      '<div class="lang-bar-container">' +
        '<div class="lang-bar-fill" style="width:' + pct + '%;background:' + l.color + '">' + l.count + '</div>' +
      '</div></div>';
  });
})();

// ── Repo cards ──────────────────────────────────────────
(function renderCards() {
  const container = document.getElementById('repoCards');
  topRepos.forEach((r, i) => {
    const levelClass = 'level-' + r.level;
    const levelLabel = r.level.replace('-', ' ');
    const sparkSvg = r.weeklyCommits.length > 1 ? buildSparkline(r.weeklyCommits) : '';
    container.innerHTML += '<div class="repo-card animate-in" style="animation-delay:' + (i * 0.05) + 's">' +
      '<div class="rank">#' + (i + 1) + '</div>' +
      '<div class="card-header">' +
        '<span class="level-badge ' + levelClass + '">' + levelLabel + '</span>' +
        '<span style="margin-left:auto;font-size:0.75rem;color:var(--text-muted)">' +
          '<span class="lang-dot" style="background:' + r.languageColor + '"></span>' + r.language + '</span>' +
      '</div>' +
      '<div class="card-name"><a href="' + r.url + '" target="_blank">' + r.name + '</a></div>' +
      (r.description ? '<div class="card-desc">' + r.description + '</div>' : '') +
      '<div class="card-metrics">' +
        metric(r.score, 'Score') + metric(r.commits, 'Commits') + metric(r.mergedPRs, 'Merged') +
        metric(r.openPRs, 'Open PRs') + metric(r.closedIssues, 'Closed') + metric(r.contributors, 'Devs') +
      '</div>' +
      sparkSvg +
    '</div>';
  });
})();

function metric(val, label) {
  return '<div class="metric"><span class="metric-val">' + val + '</span><span class="metric-label">' + label + '</span></div>';
}

function buildSparkline(data) {
  const w = 300, h = 30, max = Math.max(...data, 1);
  const step = w / Math.max(data.length - 1, 1);
  const pts = data.map((v, i) => (i * step).toFixed(1) + ',' + (h - (v / max) * (h - 2)).toFixed(1));
  const fillPts = '0,' + h + ' ' + pts.join(' ') + ' ' + ((data.length - 1) * step).toFixed(1) + ',' + h;
  return '<svg class="sparkline" viewBox="0 0 ' + w + ' ' + h + '" preserveAspectRatio="none">' +
    '<polygon class="fill" points="' + fillPts + '"/>' +
    '<polyline points="' + pts.join(' ') + '"/></svg>';
}

// ── Full table ──────────────────────────────────────────
let currentFilter = 'all';
let sortCol = 'score';
let sortAsc = false;

function renderTable() {
  const search = document.getElementById('searchInput').value.toLowerCase();
  let data = allRepos.filter(r => {
    if (currentFilter !== 'all' && r.level !== currentFilter) return false;
    if (search && !r.name.toLowerCase().includes(search)) return false;
    return true;
  });

  // Sort
  data.sort((a, b) => {
    let va = a[sortCol], vb = b[sortCol];
    if (sortCol === 'name' || sortCol === 'language' || sortCol === 'level' || sortCol === 'pushedAt') {
      va = (va || '').toString().toLowerCase();
      vb = (vb || '').toString().toLowerCase();
      return sortAsc ? va.localeCompare(vb) : vb.localeCompare(va);
    }
    return sortAsc ? va - vb : vb - va;
  });

  const tbody = document.getElementById('repoTableBody');
  tbody.innerHTML = data.map((r, i) => {
    const levelClass = 'level-' + r.level;
    const pushed = r.pushedAt ? new Date(r.pushedAt).toLocaleDateString() : '—';
    const idx = allRepos.indexOf(r) + 1;
    return '<tr>' +
      '<td>' + idx + '</td>' +
      '<td><a href="' + r.url + '" target="_blank">' + r.name + '</a></td>' +
      '<td>' + r.score + '</td>' +
      '<td>' + r.commits + '</td>' +
      '<td>' + r.mergedPRs + '</td>' +
      '<td>' + r.stars + '</td>' +
      '<td><span class="lang-dot" style="background:' + r.languageColor + '"></span>' + r.language + '</td>' +
      '<td><span class="level-badge ' + levelClass + '">' + r.level.replace('-', ' ') + '</span></td>' +
      '<td>' + pushed + '</td>' +
    '</tr>';
  }).join('');
}

// Sort headers
document.querySelectorAll('thead th[data-sort]').forEach(th => {
  th.addEventListener('click', () => {
    const col = th.dataset.sort;
    if (col === 'rank') return;
    if (sortCol === col) { sortAsc = !sortAsc; }
    else { sortCol = col; sortAsc = false; }
    document.querySelectorAll('thead th').forEach(h => h.classList.remove('sorted-asc', 'sorted-desc'));
    th.classList.add(sortAsc ? 'sorted-asc' : 'sorted-desc');
    renderTable();
  });
});

// Filter buttons
document.querySelectorAll('.filter-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentFilter = btn.dataset.filter;
    renderTable();
  });
});

// Search
document.getElementById('searchInput').addEventListener('input', renderTable);

// Initial render
renderTable();
// Mark score column as sorted
document.querySelector('th[data-sort="score"]').classList.add('sorted-desc');
</script>

</body>
</html>
"@

# Write HTML file
$html | Out-File -FilePath $OutputPath -Encoding utf8

Write-Information "" -InformationAction Continue
Write-Information "✅ Report saved to: $OutputPath" -InformationAction Continue
Write-Information "   Repos analyzed: $($AllRepos.Count)" -InformationAction Continue
Write-Information "   Top repo: $($TopRepos[0].Name) (score: $($TopRepos[0].ProductivityScore))" -InformationAction Continue
Write-Information "   Active repos ($Days d): $($OrgStats.ActiveRepos) / $($OrgStats.TotalRepos)" -InformationAction Continue
