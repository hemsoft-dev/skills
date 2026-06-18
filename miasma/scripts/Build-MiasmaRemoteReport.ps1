[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)]
    [string]$JsonPath,

    [Parameter()]
    [string]$HtmlOutputPath,

    [Parameter()]
    [string]$Title = 'Miasma remote branch audit',

    [Parameter()]
    [string[]]$OperationalBranchPatterns = @(
        'main',
        'master',
        'develop',
        'qa',
        'staging',
        'production',
        'prod',
        'release/*'
    )
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:OperationalBranchPatternsForReport = $OperationalBranchPatterns

function ConvertTo-HtmlText {
    param([AllowNull()][object]$Value)
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Join-Limited {
    param(
        [Parameter()][object[]]$Values,
        [Parameter()][int]$Limit = 8
    )

    $items = @($Values | Where-Object { $_ } | Sort-Object -Unique)
    if ($items.Count -le $Limit) {
        return ($items -join ', ')
    }

    return (($items | Select-Object -First $Limit) -join ', ') + " +$($items.Count - $Limit) more"
}

function Test-OperationalBranch {
    param([Parameter(Mandatory)][string]$BranchName)

    foreach ($pattern in $script:OperationalBranchPatternsForReport) {
        if ($BranchName -like $pattern) {
            return $true
        }
    }

    return $false
}

function Get-RiskRank {
    param([Parameter(Mandatory)][string]$Risk)

    switch ($Risk) {
        'Critical' { return 0 }
        'High' { return 1 }
        'Medium' { return 2 }
        default { return 3 }
    }
}

if (-not (Test-Path -LiteralPath $JsonPath)) {
    throw "JSON scan artifact not found: $JsonPath"
}

$resolvedJsonPath = (Resolve-Path -LiteralPath $JsonPath).Path
$scan = Get-Content -LiteralPath $resolvedJsonPath -Raw | ConvertFrom-Json
$scanMode = 'CommitWindow (legacy artifact)'
if ($scan.PSObject.Properties['ScanMode'] -and $scan.ScanMode) {
    $scanMode = [string]$scan.ScanMode
}

if (-not $HtmlOutputPath) {
    $HtmlOutputPath = Join-Path (Split-Path -Parent $resolvedJsonPath) 'miasma-remote-audit.html'
}

$parent = Split-Path -Parent $HtmlOutputPath
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$agentPaths = @(
    '.claude/settings.json',
    '.gemini/settings.json',
    '.cursor/rules/setup.mdc',
    '.vscode/tasks.json'
)

$repoSummaries = foreach ($repo in @($scan.Results)) {
    $findings = @($repo.Findings)
    if ($findings.Count -eq 0) {
        continue
    }

    $branches = [System.Collections.Generic.List[string]]::new()
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($finding in $findings) {
        foreach ($branch in @($finding.Branches)) {
            if ($branch -and -not $branches.Contains([string]$branch)) {
                $branches.Add([string]$branch) | Out-Null
            }
        }
        foreach ($path in @($finding.MatchedPaths)) {
            if ($path -and -not $paths.Contains([string]$path)) {
                $paths.Add([string]$path) | Out-Null
            }
        }
    }

    $hasSetupJs = $paths.Contains('.github/setup.js')
    $hasAgentPersistence = @($agentPaths | Where-Object { $paths.Contains($_) }).Count -gt 0
    $hasOperationalBranch = @($branches | Where-Object { Test-OperationalBranch -BranchName $_ }).Count -gt 0

    if ($hasSetupJs -and $hasAgentPersistence -and $hasOperationalBranch) {
        $risk = 'Critical'
    }
    elseif ($hasSetupJs -and $hasAgentPersistence) {
        $risk = 'High'
    }
    elseif ($hasSetupJs -or $hasOperationalBranch) {
        $risk = 'High'
    }
    else {
        $risk = 'Medium'
    }

    $action = switch ($risk) {
        'Critical' { 'Freeze affected branch work; preserve refs and SHAs; clean, delete, or reset branch tips before reopening in agent-enabled tools.' }
        'High' { 'Quarantine affected branches; notify listed authors; delete stale branches or remove persistence paths with reviewed commits.' }
        default { 'Review matched paths and branch reachability; clean or document false positives before resuming normal work.' }
    }

    [pscustomobject]@{
        Risk = $risk
        RiskRank = Get-RiskRank -Risk $risk
        Repository = [string]$repo.Repository
        Visibility = [string]$repo.Visibility
        BranchCount = [int]$repo.BranchCount
        CommitCount = [int]$repo.JuneCommitCount
        FindingCount = [int]$repo.FindingCount
        Branches = @($branches)
        MatchedPaths = @($paths)
        HasSetupJs = $hasSetupJs
        HasOperationalBranch = $hasOperationalBranch
        Action = $action
        Findings = $findings
    }
}

$repoSummaries = @($repoSummaries | Sort-Object RiskRank, Repository)
$findingBearingCommitTrees = 0
foreach ($repo in @($scan.Results)) {
    $findingBearingCommitTrees += [int]$repo.FindingCount
}

$criticalRepos = @($repoSummaries | Where-Object { $_.Risk -eq 'Critical' })
$highRepos = @($repoSummaries | Where-Object { $_.Risk -eq 'High' })
$mediumRepos = @($repoSummaries | Where-Object { $_.Risk -eq 'Medium' })
$scanErrors = @($scan.Errors)
$errorSummary = @($scanErrors | Group-Object Type | Sort-Object Count -Descending | ForEach-Object { "$($_.Name): $($_.Count)" })
$errorWarningHtml = ''
if ($scanErrors.Count -gt 0) {
    $errorSummaryText = ConvertTo-HtmlText ($errorSummary -join '; ')
    $errorWarningHtml = "<p><strong>Coverage warning:</strong> $($scanErrors.Count) API/read errors were recorded ($errorSummaryText). Treat zero findings as limited to successfully scanned branch tips until failed repositories are rerun.</p>"
}
$summaryRows = foreach ($item in $repoSummaries) {
    $branches = ConvertTo-HtmlText (Join-Limited -Values $item.Branches -Limit 8)
    $paths = ConvertTo-HtmlText (Join-Limited -Values $item.MatchedPaths -Limit 8)
    $action = ConvertTo-HtmlText $item.Action
    $repoName = ConvertTo-HtmlText $item.Repository
    $visibility = ConvertTo-HtmlText $item.Visibility
    $risk = ConvertTo-HtmlText $item.Risk
    $riskClass = $item.Risk.ToLowerInvariant()

    @"
<tr>
  <td><span class="risk $riskClass">$risk</span></td>
  <td><strong>$repoName</strong><span class="meta-line">$visibility | $($item.BranchCount) branches | $($item.CommitCount) scanned commits</span></td>
  <td class="num">$($item.FindingCount)</td>
  <td>$branches</td>
  <td>$paths</td>
  <td>$action</td>
</tr>
"@
}

$detailRows = foreach ($item in $repoSummaries) {
    foreach ($finding in @($item.Findings | Sort-Object CommitterDate, Sha)) {
        $sha = [string]$finding.Sha
        $shortSha = if ($sha.Length -ge 12) { $sha.Substring(0, 12) } else { $sha }
        $branches = ConvertTo-HtmlText (Join-Limited -Values @($finding.Branches) -Limit 12)
        $paths = ConvertTo-HtmlText (Join-Limited -Values @($finding.MatchedPaths) -Limit 8)
        $subject = ConvertTo-HtmlText $finding.Subject
        $author = ConvertTo-HtmlText $finding.Author
        $committer = ConvertTo-HtmlText $finding.Committer
        $repoName = ConvertTo-HtmlText $item.Repository

        @"
<tr>
  <td><code>$shortSha</code></td>
  <td>$repoName</td>
  <td>$paths</td>
  <td>$branches</td>
  <td>$($finding.CommitterDate)</td>
  <td>$author / $committer</td>
  <td>$subject</td>
</tr>
"@
    }
}

$sourcePath = ConvertTo-HtmlText $resolvedJsonPath
$owner = ConvertTo-HtmlText $scan.Owner
$since = ConvertTo-HtmlText $scan.Since
$until = ConvertTo-HtmlText $scan.Until
$started = ConvertTo-HtmlText $scan.StartedAt
$finished = ConvertTo-HtmlText $scan.FinishedAt
$scanModeText = ConvertTo-HtmlText $scanMode
$titleText = ConvertTo-HtmlText $Title

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$titleText</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #0f141b;
      --panel: #151b24;
      --panel-2: #1b2330;
      --text: #e8edf4;
      --muted: #9aa7b7;
      --line: #2a3444;
      --critical: #ff647c;
      --high: #ffb454;
      --medium: #f5df72;
      --ok: #6ee7b7;
      --accent: #77b7ff;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: "Segoe UI", Arial, sans-serif;
      line-height: 1.5;
    }
    main { max-width: 1480px; margin: 0 auto; padding: 28px; }
    header { margin-bottom: 22px; }
    h1 { margin: 4px 0 10px; font-size: 32px; letter-spacing: 0; }
    h2 { margin: 0 0 12px; font-size: 20px; }
    p { margin: 0 0 10px; color: var(--muted); }
    code { color: #d7e8ff; background: #111722; padding: 2px 5px; border-radius: 4px; }
    .eyebrow { color: var(--accent); text-transform: uppercase; font-size: 12px; font-weight: 700; letter-spacing: .08em; }
    .lead { font-size: 17px; max-width: 1100px; }
    .stats-grid { display: grid; grid-template-columns: repeat(6, minmax(150px, 1fr)); gap: 12px; margin: 20px 0; }
    .stat, .card {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 16px;
    }
    .stat-value { display: block; font-size: 28px; font-weight: 750; }
    .stat-label { color: var(--muted); font-size: 13px; }
    .section { margin-top: 18px; }
    .section-grid { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); gap: 16px; }
    .table-wrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 8px; }
    table { width: 100%; border-collapse: collapse; background: var(--panel); }
    th, td { padding: 10px 12px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }
    th { background: var(--panel-2); font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: .04em; }
    tr:last-child td { border-bottom: 0; }
    .num { text-align: right; font-variant-numeric: tabular-nums; }
    .meta-line { display: block; color: var(--muted); font-size: 12px; margin-top: 3px; }
    .risk { display: inline-block; min-width: 74px; padding: 3px 8px; border-radius: 4px; font-size: 12px; font-weight: 700; text-align: center; }
    .risk.critical { color: #270711; background: var(--critical); }
    .risk.high { color: #241300; background: var(--high); }
    .risk.medium { color: #221d00; background: var(--medium); }
    .actions-list { margin: 0; padding-left: 20px; color: var(--muted); }
    .actions-list li { margin-bottom: 8px; }
    @media (max-width: 980px) {
      main { padding: 18px; }
      .stats-grid, .section-grid { grid-template-columns: 1fr; }
      h1 { font-size: 26px; }
    }
  </style>
</head>
<body>
<main>
  <header>
    <div class="eyebrow">$owner | Miasma remote branch audit</div>
    <h1>$titleText</h1>
    <p class="lead">Generated from <code>$sourcePath</code>. The scan inspected <strong>$($scan.RepositoriesScanned)</strong> repositories using <strong>$scanModeText</strong> mode for branch commit trees from <strong>$since</strong> through <strong>$until</strong>.</p>
    <div class="stats-grid">
      <div class="stat"><span class="stat-value">$($criticalRepos.Count)</span><span class="stat-label">critical repos</span></div>
      <div class="stat"><span class="stat-value">$($repoSummaries.Count)</span><span class="stat-label">affected repos</span></div>
      <div class="stat"><span class="stat-value">$($scan.RepositoriesWithSetupJs)</span><span class="stat-label">repos with .github/setup.js</span></div>
      <div class="stat"><span class="stat-value">$findingBearingCommitTrees</span><span class="stat-label">finding-bearing commit trees</span></div>
      <div class="stat"><span class="stat-value">$($scan.ApiRequestsApproximate)</span><span class="stat-label">approx API calls</span></div>
      <div class="stat"><span class="stat-value">$($scanErrors.Count)</span><span class="stat-label">scan errors</span></div>
    </div>
  </header>

  <section class="section section-grid">
    <div class="card">
      <h2>Executive Summary</h2>
      <p>Treat this as an incident-response work queue. A repo is most concerning when <code>.github/setup.js</code> appears with Claude, Gemini, Cursor, or VS Code auto-run configuration paths, especially on default, release, staging, production, develop, or QA branches.</p>
      $errorWarningHtml
      <p>Scan started <code>$started</code> and finished <code>$finished</code>. Re-running later may produce different results if branch refs were deleted or rewritten.</p>
    </div>
    <div class="card">
      <h2>Recommended Course</h2>
      <ol class="actions-list">
        <li>Contain first: do not checkout or open affected branches in agent-enabled editors.</li>
        <li>Preserve evidence: refs, SHAs, parent SHAs, tree SHAs, audit records, and actor names.</li>
        <li>Prioritize operational branches before stale feature branches.</li>
        <li>Delete stale branches; clean protected branches with reviewed removal commits or resets.</li>
        <li>Add monitoring for <code>.github/setup.js</code>, AI-agent auto-run configs, and unexpected <code>binding.gyp</code>.</li>
      </ol>
    </div>
  </section>

  <section class="section">
    <h2>Affected Repositories</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Risk</th><th>Repository</th><th>Findings</th><th>Affected branches</th><th>Matched paths</th><th>Human action</th></tr></thead>
        <tbody>
$($summaryRows -join "`n")
        </tbody>
      </table>
    </div>
  </section>

  <section class="section">
    <h2>Finding Detail</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>SHA</th><th>Repository</th><th>Matched paths</th><th>Branches</th><th>Committer date</th><th>Author / Committer</th><th>Subject</th></tr></thead>
        <tbody>
$($detailRows -join "`n")
        </tbody>
      </table>
    </div>
  </section>
</main>
</body>
</html>
"@

$html | Set-Content -LiteralPath $HtmlOutputPath -Encoding utf8

[pscustomobject]@{
    HtmlOutputPath = (Resolve-Path -LiteralPath $HtmlOutputPath).Path
    RepositoriesScanned = [int]$scan.RepositoriesScanned
    AffectedRepositories = $repoSummaries.Count
    CriticalRepositories = $criticalRepos.Count
    HighRepositories = $highRepos.Count
    MediumRepositories = $mediumRepos.Count
    FindingBearingCommitTrees = $findingBearingCommitTrees
}
