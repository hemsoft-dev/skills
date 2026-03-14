#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 3: Builds an HTML productivity report from the user productivity JSON.
.DESCRIPTION
    Reads relias-engineering-user-productivity.json (produced by Phase 1 and
    optionally enriched by Phase 2) and generates a visually rich, sortable
    HTML report. Makes ZERO GitHub API calls.

    Output: relias-engineering-user-productivity.html
.PARAMETER InputPath
    Path to the JSON file to read. Defaults to
    relias-engineering-user-productivity.json in the current directory.
.PARAMETER OutputPath
    Path to the HTML file to create. Defaults to
    relias-engineering-user-productivity.html in the current directory.
.EXAMPLE
    .\3-Build-AllUserProductivityReport.ps1
.EXAMPLE
    .\3-Build-AllUserProductivityReport.ps1 -InputPath .\relias-engineering-user-productivity.json
#>

[CmdletBinding()]
param(
    [string]$InputPath,

    [string]$OutputPath,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Join-Path (Get-Location) 'relias-engineering-user-productivity.json'
}

if (-not (Test-Path $InputPath)) {
    throw "Input file not found: $InputPath. Run 1-Get-AllUserProductivityMetrics.ps1 (Phase 1) first."
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path (Get-Location) 'relias-engineering-user-productivity.html'
}

# ── Skip if HTML is already up-to-date ───────────────────────────────

if (-not $Force -and (Test-Path $OutputPath)) {
    $jsonTime = (Get-Item $InputPath).LastWriteTime
    $htmlTime = (Get-Item $OutputPath).LastWriteTime
    if ($htmlTime -ge $jsonTime) {
        Write-Information "Phase 3 report is already up-to-date (HTML: $($htmlTime.ToString('yyyy-MM-dd HH:mm')), JSON: $($jsonTime.ToString('yyyy-MM-dd HH:mm'))). Use -Force to regenerate." -InformationAction Continue
        [PSCustomObject]@{
            OutputPath = $OutputPath
            Status     = 'Skipped (HTML newer than JSON)'
        } | Format-Table -AutoSize | Out-String | Write-Output
        return
    }
}

$data = Get-Content $InputPath -Raw | ConvertFrom-Json
$users = @($data.Users)

# ── Compute summary stats ────────────────────────────────────────────

$totalCommits = ($users | Measure-Object -Property Commits -Sum).Sum
$totalLinesAdded = ($users | Measure-Object -Property LinesAdded -Sum).Sum
$totalLinesDeleted = ($users | Measure-Object -Property LinesDeleted -Sum).Sum
$totalNetLOC = ($users | Measure-Object -Property NetLOC -Sum).Sum
$totalPRs = ($users | ForEach-Object { $_.OpenPRs + $_.MergedPRs + $_.ClosedPRs } | Measure-Object -Sum).Sum
$totalMergedPRs = ($users | Measure-Object -Property MergedPRs -Sum).Sum
$totalReviews = ($users | ForEach-Object { $_.ApprovedReviews + $_.CommentReviews } | Measure-Object -Sum).Sum
$totalIssues = ($users | ForEach-Object { $_.OpenIssues + $_.ClosedIssues } | Measure-Object -Sum).Sum
$totalWorkflowRuns = ($users | Measure-Object -Property WorkflowRuns -Sum).Sum
$activeUsers = @($users | Where-Object { $_.Commits -gt 0 -or $_.MergedPRs -gt 0 -or $_.OpenPRs -gt 0 }).Count

$hasPremium = [bool]$data.PremiumRequestsIncluded
$totalPremium = 0.0
if ($hasPremium) {
    $totalPremium = ($users | ForEach-Object {
        if ($null -ne $_.PremiumRequests) { $_.PremiumRequests } else { 0 }
    } | Measure-Object -Sum).Sum
}

# ── Compute universal productivity scores ────────────────────────────

$metricWeights = [ordered]@{
    PremiumRequests   = 0.10
    Commits           = 0.10
    LinesAdded        = 0.08
    LinesDeleted      = 0.08
    NetLOC            = 0.08
    TotalLinesChanged = 0.08
    OpenPRs           = 0.06
    MergedPRs         = 0.08
    ClosedPRs         = 0.06
    ApprovedReviews   = 0.07
    CommentReviews    = 0.05
    OpenIssues        = 0.05
    ClosedIssues      = 0.06
    WorkflowRuns      = 0.05
}

if (-not $hasPremium) {
    # Redistribute premium weight across remaining metrics
    $premiumWeight = $metricWeights['PremiumRequests']
    $metricWeights.Remove('PremiumRequests')
    $remainingCount = $metricWeights.Count
    $extraEach = $premiumWeight / $remainingCount
    $redistributed = [ordered]@{}
    foreach ($key in $metricWeights.Keys) {
        $redistributed[$key] = [math]::Round($metricWeights[$key] + $extraEach, 4)
    }
    $metricWeights = $redistributed
}

function Get-TransformedValue ([double]$Value) {
    if ($Value -lt 0) { return -[math]::Log(1 + [math]::Abs($Value)) }
    return [math]::Log(1 + $Value)
}

function Get-PercentileMap ([object[]]$Users, [string]$Metric) {
    $entries = @(
        foreach ($u in $Users) {
            $raw = if ($null -ne $u.$Metric) { [double]$u.$Metric } else { 0.0 }
            [PSCustomObject]@{ Username = $u.Username; Transformed = (Get-TransformedValue $raw) }
        }
    )
    $map = @{}
    if ($entries.Count -eq 1) { $map[$entries[0].Username] = 100.0; return $map }
    $distinct = @($entries.Transformed | Sort-Object -Unique)
    if ($distinct.Count -eq 1) {
        foreach ($e in $entries) { $map[$e.Username] = 50.0 }
        return $map
    }
    $sorted = @($entries | Sort-Object -Property Transformed, Username)
    $pos = 0
    while ($pos -lt $sorted.Count) {
        $start = $pos
        $val = $sorted[$pos].Transformed
        while (($pos + 1) -lt $sorted.Count -and $sorted[$pos + 1].Transformed -eq $val) { $pos++ }
        $avg = ($start + $pos) / 2.0
        $score = [math]::Round(($avg / ($sorted.Count - 1)) * 100, 2)
        for ($i = $start; $i -le $pos; $i++) { $map[$sorted[$i].Username] = $score }
        $pos++
    }
    return $map
}

$percentileMaps = @{}
foreach ($metric in $metricWeights.Keys) {
    $percentileMaps[$metric] = Get-PercentileMap -Users $users -Metric $metric
}

$scoreMap = @{}
foreach ($u in $users) {
    $total = 0.0
    foreach ($metric in $metricWeights.Keys) {
        $pct = [double]$percentileMaps[$metric][$u.Username]
        $total += $pct * $metricWeights[$metric]
    }
    $scoreMap[$u.Username] = [math]::Round($total, 2)
}

# ── Build users JSON for client-side sorting ─────────────────────────

$usersJsonEntries = @()
foreach ($user in $users) {
    $fullName = if ($user.FullName) { $user.FullName -replace '"', '\"' -replace "`n", ' ' } else { '' }
    $profileUrl = if ($user.ProfileUrl) { $user.ProfileUrl } else { "https://github.com/$($user.Username)" }
    $premium = if ($null -ne $user.PremiumRequests) { $user.PremiumRequests } else { 'null' }
    $uScore = $scoreMap[$user.Username]

    $usersJsonEntries += @"
    {
      "username": "$($user.Username)",
      "fullName": "$fullName",
      "profileUrl": "$profileUrl",
      "score": $uScore,
      "premiumRequests": $premium,
      "commits": $($user.Commits),
      "linesAdded": $($user.LinesAdded),
      "linesDeleted": $($user.LinesDeleted),
      "netLOC": $($user.NetLOC),
      "totalLinesChanged": $($user.TotalLinesChanged),
      "openPRs": $($user.OpenPRs),
      "mergedPRs": $($user.MergedPRs),
      "closedPRs": $($user.ClosedPRs),
      "approvedReviews": $($user.ApprovedReviews),
      "commentReviews": $($user.CommentReviews),
      "openIssues": $($user.OpenIssues),
      "closedIssues": $($user.ClosedIssues),
      "workflowRuns": $($user.WorkflowRuns)
    }
"@
}

$usersJson = $usersJsonEntries -join ",`n"

# ── Premium column header/cells ──────────────────────────────────────

$premiumColHeader = if ($hasPremium) {
    '<th data-sort="premiumRequests" class="has-tip">Premium<br>Requests<div class="tip"><div class="tip-title">Premium Requests</div>GitHub Copilot <em>premium request consumption</em> by this user. Sourced from the Copilot billing API. Reflects AI-assisted code generation and chat usage.</div></th>'
} else { '' }

$premiumSummaryCard = if ($hasPremium) {
    @"
        <div class="stat-card has-tip">
          <div class="stat-value" id="stat-premium">$([math]::Round($totalPremium, 1))</div>
          <div class="stat-label">Premium Requests</div>
          <div class="tip"><div class="tip-title">Premium Requests</div>Total <em>GitHub Copilot premium requests</em> consumed across the organization. Tracks AI-assisted coding usage from the Copilot billing API. Higher values indicate heavier Copilot adoption.</div>
        </div>
"@
} else { '' }

# ── Generate HTML ────────────────────────────────────────────────────

$enrichedNote = ''
if ($null -ne ($data.PSObject.Properties | Where-Object Name -eq 'PremiumRequestsEnrichedAt') -and $data.PremiumRequestsEnrichedAt) {
    $enrichedNote = " &middot; Premium enriched: $($data.PremiumRequestsEnrichedAt)"
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$($data.Organization) — User Productivity Report</title>
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
    --accent-blue: #3b82f6;
    --accent-green: #22c55e;
    --accent-purple: #a78bfa;
    --accent-cyan: #22d3ee;
    --accent-orange: #f97316;
    --accent-gold: #fbbf24;
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
    background: linear-gradient(135deg, #0a0e17 0%, #1a1040 40%, #0f2027 100%);
    padding: 3rem 2rem 2rem;
    text-align: center;
    border-bottom: 1px solid var(--border);
    position: relative;
    overflow: hidden;
  }

  .hero::before {
    content: '';
    position: absolute;
    top: -50%; left: -50%;
    width: 200%; height: 200%;
    background: radial-gradient(ellipse at 30% 50%, rgba(59,130,246,0.08) 0%, transparent 50%),
                radial-gradient(ellipse at 70% 50%, rgba(34,211,238,0.06) 0%, transparent 50%);
    animation: aurora 20s ease-in-out infinite alternate;
  }

  @keyframes aurora {
    0% { transform: translate(0, 0) rotate(0deg); }
    100% { transform: translate(-5%, 3%) rotate(2deg); }
  }

  .hero-content { position: relative; z-index: 1; max-width: 1200px; margin: 0 auto; }

  .hero h1 {
    font-size: 2.4rem;
    font-weight: 900;
    letter-spacing: -0.03em;
    background: linear-gradient(135deg, #e2e8f0, #3b82f6, #22d3ee);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin-bottom: 0.5rem;
  }

  .hero .subtitle {
    color: var(--text-secondary);
    font-size: 1.1rem;
    font-weight: 400;
  }

  .hero .meta {
    margin-top: 0.75rem;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    color: var(--text-muted);
  }

  .container { max-width: 1400px; margin: 0 auto; padding: 2rem; }

  /* ── Summary cards ────────────────────────────────────────────── */
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
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
    border-color: var(--accent-blue);
  }

  .stat-value {
    font-size: 1.8rem;
    font-weight: 800;
    font-family: 'JetBrains Mono', monospace;
    color: var(--accent-cyan);
  }

  .stat-label {
    font-size: 0.8rem;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-top: 0.25rem;
  }

  /* ── Controls ─────────────────────────────────────────────────── */
  .controls {
    display: flex;
    gap: 1rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
    align-items: center;
  }

  .search-box {
    flex: 1;
    min-width: 250px;
    padding: 0.75rem 1rem;
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-primary);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.9rem;
    outline: none;
    transition: border-color 0.2s;
  }

  .search-box:focus { border-color: var(--accent-blue); }
  .search-box::placeholder { color: var(--text-muted); }

  .toggle-btn {
    padding: 0.6rem 1.2rem;
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-secondary);
    font-family: 'Outfit', sans-serif;
    font-size: 0.85rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .toggle-btn:hover { border-color: var(--accent-blue); color: var(--text-primary); }
  .toggle-btn.active { background: var(--accent-blue); color: #fff; border-color: var(--accent-blue); }

  /* ── Table ────────────────────────────────────────────────────── */
  .table-wrapper {
    overflow-x: auto;
    border-radius: 12px;
    border: 1px solid var(--border);
    background: var(--bg-card);
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  th {
    background: var(--bg-secondary);
    padding: 0.75rem 0.6rem;
    text-align: right;
    font-weight: 600;
    color: var(--text-secondary);
    border-bottom: 2px solid var(--border);
    cursor: pointer;
    user-select: none;
    white-space: nowrap;
    position: sticky;
    top: 0;
    z-index: 2;
  }

  th:first-child { text-align: left; }
  th:hover { color: var(--accent-cyan); }
  th.sorted-asc::after { content: ' ▲'; color: var(--accent-cyan); }
  th.sorted-desc::after { content: ' ▼'; color: var(--accent-cyan); }

  td {
    padding: 0.6rem;
    text-align: right;
    border-bottom: 1px solid var(--border);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.8rem;
    color: var(--text-secondary);
  }

  td:first-child { text-align: left; font-family: 'Outfit', sans-serif; font-size: 0.85rem; }

  tr:hover td { background: var(--bg-card-hover); }

  td.positive { color: var(--accent-green); }
  td.negative { color: #ef4444; }
  td.zero { color: var(--text-muted); }

  .username-cell a {
    color: var(--accent-blue);
    text-decoration: none;
    font-weight: 500;
  }

  .username-cell a:hover { text-decoration: underline; }

  .username-cell .full-name {
    display: block;
    font-size: 0.75rem;
    color: var(--text-muted);
    font-weight: 400;
  }

  .rank-cell {
    color: var(--text-muted);
    font-size: 0.75rem;
    width: 2.5rem;
    text-align: center;
  }

  .rank-cell.gold { color: var(--accent-gold); font-weight: 700; }
  .rank-cell.silver { color: #94a3b8; font-weight: 700; }
  .rank-cell.bronze { color: #d97706; font-weight: 700; }

  .score-cell {
    font-weight: 700;
    font-size: 0.85rem;
  }

  .score-high { color: var(--accent-green); }
  .score-mid { color: var(--accent-cyan); }
  .score-low { color: var(--text-muted); }

  /* ── Tooltips ──────────────────────────────────────────────── */
  .has-tip {
    position: relative;
    cursor: help;
  }

  .has-tip .tip {
    visibility: hidden;
    opacity: 0;
    position: absolute;
    top: 100%;
    left: 50%;
    transform: translateX(-50%);
    z-index: 100;
    min-width: 260px;
    max-width: 340px;
    padding: 0.85rem 1rem;
    margin-top: 8px;
    background: linear-gradient(135deg, #1e293b 0%, #1a2234 100%);
    border: 1px solid var(--accent-blue);
    border-radius: 10px;
    box-shadow: 0 8px 32px rgba(0,0,0,0.5), 0 0 12px rgba(59,130,246,0.15);
    font-family: 'Outfit', sans-serif;
    font-size: 0.78rem;
    font-weight: 400;
    color: var(--text-secondary);
    line-height: 1.55;
    text-align: left;
    white-space: normal;
    pointer-events: none;
    transition: opacity 0.2s, visibility 0.2s;
  }

  .has-tip .tip::before {
    content: '';
    position: absolute;
    bottom: 100%;
    left: 50%;
    transform: translateX(-50%);
    border: 6px solid transparent;
    border-bottom-color: var(--accent-blue);
  }

  .has-tip:hover .tip {
    visibility: visible;
    opacity: 1;
  }

  .has-tip .tip .tip-title {
    font-weight: 700;
    font-size: 0.82rem;
    color: var(--accent-cyan);
    margin-bottom: 0.3rem;
    letter-spacing: 0.01em;
  }

  .has-tip .tip em {
    color: var(--accent-blue);
    font-style: normal;
    font-weight: 600;
  }

  /* Keep stat-card tips from overflowing layout */
  .stat-card { position: relative; overflow: visible; }

  /* Table header tips: pin to right edge for right-aligned columns */
  th.has-tip .tip {
    left: auto;
    right: 0;
    transform: none;
  }

  th.has-tip .tip::before {
    left: auto;
    right: 1rem;
    transform: none;
  }

  /* First two th columns: pin tip to left */
  th:first-child.has-tip .tip,
  th:nth-child(2).has-tip .tip {
    left: 0;
    right: auto;
    transform: none;
  }

  th:first-child.has-tip .tip::before,
  th:nth-child(2).has-tip .tip::before {
    left: 1rem;
    right: auto;
    transform: none;
  }

  /* ── Footer ───────────────────────────────────────────────────── */
  .footer {
    text-align: center;
    padding: 2rem;
    color: var(--text-muted);
    font-size: 0.75rem;
    border-top: 1px solid var(--border);
    margin-top: 2rem;
  }

  .footer a { color: var(--accent-blue); text-decoration: none; }

  /* ── Responsive ───────────────────────────────────────────────── */
  @media (max-width: 768px) {
    .hero h1 { font-size: 1.6rem; }
    .container { padding: 1rem; }
    .stats-grid { grid-template-columns: repeat(2, 1fr); }
  }
</style>
</head>
<body>

<div class="hero">
  <div class="hero-content">
    <h1>$($data.Organization)</h1>
    <p class="subtitle">User Productivity Report</p>
    <p class="meta">$($data.StartDate) &mdash; $($data.EndDate) &middot; $($data.UserCount) users &middot; $($data.RepositoryCount) repos$enrichedNote</p>
  </div>
</div>

<div class="container">

  <div class="stats-grid">
    <div class="stat-card has-tip">
      <div class="stat-value">$activeUsers</div>
      <div class="stat-label">Active Users</div>
      <div class="tip"><div class="tip-title">Active Users</div>Users with at least <em>one commit</em>, <em>opened PR</em>, or <em>merged PR</em> in the reporting period. Inactive members (bots, departed, idle) are excluded from this count but still appear in the table.</div>
    </div>
    <div class="stat-card has-tip">
      <div class="stat-value">$($totalCommits.ToString('N0'))</div>
      <div class="stat-label">Commits</div>
      <div class="tip"><div class="tip-title">Commits</div>Total commits pushed to <em>default branches</em> across all repositories. Includes merge commits. Aggregated from the GitHub Events API over the reporting window.</div>
    </div>
    <div class="stat-card has-tip">
      <div class="stat-value">$($totalLinesAdded.ToString('N0'))</div>
      <div class="stat-label">Lines Added</div>
      <div class="tip"><div class="tip-title">Lines Added</div>Sum of all <em>insertions</em> across every commit. Measures raw code output. Large values may indicate new features, migrations, or auto-generated code.</div>
    </div>
    <div class="stat-card has-tip">
      <div class="stat-value">$($totalLinesDeleted.ToString('N0'))</div>
      <div class="stat-label">Lines Deleted</div>
      <div class="tip"><div class="tip-title">Lines Deleted</div>Sum of all <em>deletions</em> across every commit. High deletion counts often signal healthy refactoring, cleanup, or dead-code removal.</div>
    </div>
    <div class="stat-card has-tip">
      <div class="stat-value">$($totalPRs.ToString('N0'))</div>
      <div class="stat-label">Pull Requests</div>
      <div class="tip"><div class="tip-title">Pull Requests</div>Combined count of <em>open</em>, <em>merged</em>, and <em>closed</em> pull requests authored by all users in the period. Reflects code review throughput.</div>
    </div>
    <div class="stat-card has-tip">
      <div class="stat-value">$($totalMergedPRs.ToString('N0'))</div>
      <div class="stat-label">Merged PRs</div>
      <div class="tip"><div class="tip-title">Merged PRs</div>Pull requests that were <em>successfully merged</em> into their target branch. The strongest signal of completed, reviewed work landing in production.</div>
    </div>
    <div class="stat-card has-tip">
      <div class="stat-value">$($totalReviews.ToString('N0'))</div>
      <div class="stat-label">Reviews</div>
      <div class="tip"><div class="tip-title">Reviews</div>Sum of <em>approved</em> and <em>comment-only</em> pull request reviews. Measures engagement in the code review process, which is critical for code quality and knowledge sharing.</div>
    </div>
    <div class="stat-card has-tip">
      <div class="stat-value">$($totalIssues.ToString('N0'))</div>
      <div class="stat-label">Issues</div>
      <div class="tip"><div class="tip-title">Issues</div>Combined count of <em>opened</em> and <em>closed</em> GitHub Issues. Tracks participation in bug reporting, feature requests, and project management.</div>
    </div>
    <div class="stat-card has-tip">
      <div class="stat-value">$($totalWorkflowRuns.ToString('N0'))</div>
      <div class="stat-label">Workflow Runs</div>
      <div class="tip"><div class="tip-title">Workflow Runs</div>GitHub Actions <em>workflow runs triggered</em> by each user (via push, PR, or manual dispatch). Indicates CI/CD activity and testing frequency.</div>
    </div>
$premiumSummaryCard
  </div>

  <div class="controls">
    <input type="text" class="search-box" id="searchBox" placeholder="Search users...">
    <button class="toggle-btn active" id="toggleActive" onclick="toggleActiveOnly()">Active Only</button>
  </div>

  <div class="table-wrapper">
    <table id="userTable">
      <thead>
        <tr>
          <th class="rank-cell">#</th>
          <th data-sort="username" class="has-tip">User<div class="tip"><div class="tip-title">User</div>GitHub username and display name. Click to visit their GitHub profile. Sortable alphabetically.</div></th>
          <th data-sort="score" class="sorted-desc has-tip">Score<div class="tip"><div class="tip-title">Productivity Score (0–100)</div>A <em>universal composite score</em> combining all metrics using weighted percentile ranking.<br><br><em>How it works:</em> Each metric is log-transformed to reduce outlier impact, then ranked as a percentile (0–100) against all other users. Percentiles are combined using these weights:<br><br>• <em>Commits</em> &amp; <em>Premium Requests</em>: 10% each<br>• <em>Merged PRs</em>, <em>Lines+</em>, <em>Lines−</em>, <em>Net LOC</em>, <em>Total Changed</em>: 8% each<br>• <em>Approved Reviews</em>: 7%<br>• <em>Open/Closed PRs</em>, <em>Closed Issues</em>: 6% each<br>• <em>Comment Reviews</em>, <em>Open Issues</em>, <em>Workflows</em>: 5% each<br><br><em>70+</em> = high activity &bull; <em>35–70</em> = moderate &bull; <em>&lt;35</em> = low</div></th>
          $premiumColHeader
          <th data-sort="commits" class="has-tip">Commits<div class="tip"><div class="tip-title">Commits</div>Number of commits pushed to <em>default branches</em> by this user during the reporting period.</div></th>
          <th data-sort="linesAdded" class="has-tip">Lines+<div class="tip"><div class="tip-title">Lines Added</div>Total <em>line insertions</em> across all commits by this user. Measures raw code output volume.</div></th>
          <th data-sort="linesDeleted" class="has-tip">Lines-<div class="tip"><div class="tip-title">Lines Deleted</div>Total <em>line deletions</em> across all commits. Healthy codebases often show strong deletion counts from refactoring.</div></th>
          <th data-sort="netLOC" class="has-tip">Net LOC<div class="tip"><div class="tip-title">Net Lines of Code</div><em>Lines Added minus Lines Deleted.</em> Positive means net growth, negative means net reduction. Neither is inherently good or bad—it depends on context.</div></th>
          <th data-sort="openPRs" class="has-tip">Open PRs<div class="tip"><div class="tip-title">Open Pull Requests</div>PRs authored by this user that are still <em>open and awaiting review</em> or merge.</div></th>
          <th data-sort="mergedPRs" class="has-tip">Merged PRs<div class="tip"><div class="tip-title">Merged Pull Requests</div>PRs authored by this user that were <em>successfully merged</em>. The strongest indicator of completed, reviewed work.</div></th>
          <th data-sort="closedPRs" class="has-tip">Closed PRs<div class="tip"><div class="tip-title">Closed Pull Requests</div>PRs authored by this user that were <em>closed without merging</em>. May indicate abandoned work, duplicates, or superseded PRs.</div></th>
          <th data-sort="approvedReviews" class="has-tip">Approved<div class="tip"><div class="tip-title">Approved Reviews</div>PR reviews where this user submitted an <em>"Approve"</em> verdict. Shows participation as a code reviewer and gatekeeper.</div></th>
          <th data-sort="commentReviews" class="has-tip">Comment<div class="tip"><div class="tip-title">Comment Reviews</div>PR reviews where this user left <em>comments without approving or requesting changes</em>. Indicates collaborative engagement.</div></th>
          <th data-sort="openIssues" class="has-tip">Open Issues<div class="tip"><div class="tip-title">Open Issues</div>GitHub Issues <em>opened</em> by this user. Tracks bug reports, feature requests, and task creation.</div></th>
          <th data-sort="closedIssues" class="has-tip">Closed Issues<div class="tip"><div class="tip-title">Closed Issues</div>GitHub Issues <em>closed</em> by this user. Indicates resolution of bugs, tasks, and feature requests.</div></th>
          <th data-sort="workflowRuns" class="has-tip">Workflows<div class="tip"><div class="tip-title">Workflow Runs</div>GitHub Actions <em>workflow runs triggered</em> by this user’s pushes, PRs, or manual dispatches. Measures CI/CD and testing activity.</div></th>
        </tr>
      </thead>
      <tbody id="userTableBody"></tbody>
    </table>
  </div>
</div>

<div class="footer">
  Generated by <a href="#">1-Get-AllUserProductivityMetrics.ps1</a> pipeline &middot; $($data.GeneratedAt)
</div>

<script>
const users = [
$usersJson
];

const hasPremium = $($hasPremium.ToString().ToLower());

let sortKey = 'score';
let sortDir = 'desc';
let activeOnly = true;
let searchTerm = '';

function formatNum(n) {
  if (n === null || n === undefined) return '—';
  return n.toLocaleString();
}

function renderTable() {
  const filtered = users.filter(u => {
    if (activeOnly) {
      const hasActivity = u.commits > 0 || u.mergedPRs > 0 || u.openPRs > 0 ||
        u.approvedReviews > 0 || u.commentReviews > 0 || u.openIssues > 0 ||
        u.closedIssues > 0 || u.workflowRuns > 0 ||
        (u.premiumRequests !== null && u.premiumRequests > 0);
      if (!hasActivity) return false;
    }
    if (searchTerm) {
      const q = searchTerm.toLowerCase();
      return u.username.toLowerCase().includes(q) ||
             (u.fullName && u.fullName.toLowerCase().includes(q));
    }
    return true;
  });

  filtered.sort((a, b) => {
    let va = a[sortKey], vb = b[sortKey];
    if (sortKey === 'username') {
      va = (va || '').toLowerCase();
      vb = (vb || '').toLowerCase();
      return sortDir === 'asc' ? va.localeCompare(vb) : vb.localeCompare(va);
    }
    va = va ?? -1;
    vb = vb ?? -1;
    return sortDir === 'asc' ? va - vb : vb - va;
  });

  const tbody = document.getElementById('userTableBody');
  tbody.innerHTML = filtered.map((u, i) => {
    const rank = i + 1;
    const rankClass = rank === 1 ? 'gold' : rank === 2 ? 'silver' : rank === 3 ? 'bronze' : '';
    const locClass = u.netLOC > 0 ? 'positive' : u.netLOC < 0 ? 'negative' : 'zero';
    const premiumCell = hasPremium
      ? '<td>' + formatNum(u.premiumRequests) + '</td>'
      : '';

    const scoreClass = u.score >= 70 ? 'score-high' : u.score >= 35 ? 'score-mid' : 'score-low';

    return '<tr>' +
      '<td class="rank-cell ' + rankClass + '">' + rank + '</td>' +
      '<td class="username-cell"><a href="' + u.profileUrl + '" target="_blank">' +
        u.username + '</a>' +
        (u.fullName ? '<span class="full-name">' + u.fullName + '</span>' : '') +
      '</td>' +
      '<td class="score-cell ' + scoreClass + '">' + u.score.toFixed(1) + '</td>' +
      premiumCell +
      '<td>' + formatNum(u.commits) + '</td>' +
      '<td class="positive">' + formatNum(u.linesAdded) + '</td>' +
      '<td class="negative">' + formatNum(u.linesDeleted) + '</td>' +
      '<td class="' + locClass + '">' + formatNum(u.netLOC) + '</td>' +
      '<td>' + formatNum(u.openPRs) + '</td>' +
      '<td>' + formatNum(u.mergedPRs) + '</td>' +
      '<td>' + formatNum(u.closedPRs) + '</td>' +
      '<td>' + formatNum(u.approvedReviews) + '</td>' +
      '<td>' + formatNum(u.commentReviews) + '</td>' +
      '<td>' + formatNum(u.openIssues) + '</td>' +
      '<td>' + formatNum(u.closedIssues) + '</td>' +
      '<td>' + formatNum(u.workflowRuns) + '</td>' +
    '</tr>';
  }).join('');
}

// Column sort
document.querySelectorAll('th[data-sort]').forEach(th => {
  th.addEventListener('click', () => {
    const key = th.dataset.sort;
    if (sortKey === key) {
      sortDir = sortDir === 'asc' ? 'desc' : 'asc';
    } else {
      sortKey = key;
      sortDir = key === 'username' ? 'asc' : 'desc';
    }
    document.querySelectorAll('th').forEach(h => h.classList.remove('sorted-asc', 'sorted-desc'));
    th.classList.add(sortDir === 'asc' ? 'sorted-asc' : 'sorted-desc');
    renderTable();
  });
});

// Search
document.getElementById('searchBox').addEventListener('input', e => {
  searchTerm = e.target.value;
  renderTable();
});

// Active toggle
function toggleActiveOnly() {
  activeOnly = !activeOnly;
  document.getElementById('toggleActive').classList.toggle('active', activeOnly);
  renderTable();
}

renderTable();
</script>
</body>
</html>
"@

$html | Set-Content -Path $OutputPath -Encoding UTF8

[PSCustomObject]@{
    InputPath  = $InputPath
    OutputPath = $OutputPath
    UserCount  = $data.UserCount
    HasPremium = $hasPremium
} | Format-Table -AutoSize | Out-String | Write-Output
