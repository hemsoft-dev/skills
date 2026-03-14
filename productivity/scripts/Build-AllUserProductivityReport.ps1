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
    .\Build-AllUserProductivityReport.ps1
.EXAMPLE
    .\Build-AllUserProductivityReport.ps1 -InputPath .\relias-engineering-user-productivity.json
#>

[CmdletBinding()]
param(
    [string]$InputPath,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Join-Path (Get-Location) 'relias-engineering-user-productivity.json'
}

if (-not (Test-Path $InputPath)) {
    throw "Input file not found: $InputPath. Run Get-AllUserProductivityMetrics.ps1 (Phase 1) first."
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path (Get-Location) 'relias-engineering-user-productivity.html'
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

# ── Build users JSON for client-side sorting ─────────────────────────

$usersJsonEntries = @()
foreach ($user in $users) {
    $fullName = if ($user.FullName) { $user.FullName -replace '"', '\"' -replace "`n", ' ' } else { '' }
    $profileUrl = if ($user.ProfileUrl) { $user.ProfileUrl } else { "https://github.com/$($user.Username)" }
    $premium = if ($null -ne $user.PremiumRequests) { $user.PremiumRequests } else { 'null' }

    $usersJsonEntries += @"
    {
      "username": "$($user.Username)",
      "fullName": "$fullName",
      "profileUrl": "$profileUrl",
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
    '<th data-sort="premiumRequests">Premium<br>Requests</th>'
} else { '' }

$premiumSummaryCard = if ($hasPremium) {
    @"
        <div class="stat-card">
          <div class="stat-value" id="stat-premium">$([math]::Round($totalPremium, 1))</div>
          <div class="stat-label">Premium Requests</div>
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
    <div class="stat-card">
      <div class="stat-value">$activeUsers</div>
      <div class="stat-label">Active Users</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">$($totalCommits.ToString('N0'))</div>
      <div class="stat-label">Commits</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">$($totalLinesAdded.ToString('N0'))</div>
      <div class="stat-label">Lines Added</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">$($totalLinesDeleted.ToString('N0'))</div>
      <div class="stat-label">Lines Deleted</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">$($totalPRs.ToString('N0'))</div>
      <div class="stat-label">Pull Requests</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">$($totalMergedPRs.ToString('N0'))</div>
      <div class="stat-label">Merged PRs</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">$($totalReviews.ToString('N0'))</div>
      <div class="stat-label">Reviews</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">$($totalIssues.ToString('N0'))</div>
      <div class="stat-label">Issues</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">$($totalWorkflowRuns.ToString('N0'))</div>
      <div class="stat-label">Workflow Runs</div>
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
          <th data-sort="username">User</th>
          $premiumColHeader
          <th data-sort="commits" class="sorted-desc">Commits</th>
          <th data-sort="linesAdded">Lines+</th>
          <th data-sort="linesDeleted">Lines-</th>
          <th data-sort="netLOC">Net LOC</th>
          <th data-sort="openPRs">Open PRs</th>
          <th data-sort="mergedPRs">Merged PRs</th>
          <th data-sort="closedPRs">Closed PRs</th>
          <th data-sort="approvedReviews">Approved</th>
          <th data-sort="commentReviews">Comment</th>
          <th data-sort="openIssues">Open Issues</th>
          <th data-sort="closedIssues">Closed Issues</th>
          <th data-sort="workflowRuns">Workflows</th>
        </tr>
      </thead>
      <tbody id="userTableBody"></tbody>
    </table>
  </div>
</div>

<div class="footer">
  Generated by <a href="#">Get-AllUserProductivityMetrics.ps1</a> pipeline &middot; $($data.GeneratedAt)
</div>

<script>
const users = [
$usersJson
];

const hasPremium = $($hasPremium.ToString().ToLower());

let sortKey = 'commits';
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

    return '<tr>' +
      '<td class="rank-cell ' + rankClass + '">' + rank + '</td>' +
      '<td class="username-cell"><a href="' + u.profileUrl + '" target="_blank">' +
        u.username + '</a>' +
        (u.fullName ? '<span class="full-name">' + u.fullName + '</span>' : '') +
      '</td>' +
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
