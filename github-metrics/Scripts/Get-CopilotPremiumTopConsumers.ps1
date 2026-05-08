[CmdletBinding()]
param(
    [string]$Repository = 'relias-engineering/org-metrics',
    [string]$WorkflowFile = 'copilot-metrics.yml',
    [string]$Ref = 'main',
    [string]$ReportMonth = (Get-Date).ToString('yyyy-MM'),
    [int]$Top = 10,
    [int]$PollSeconds = 15,
    [int]$TimeoutMinutes = 10
)

$ErrorActionPreference = 'Stop'

if ($Top -lt 1) {
    throw '-Top must be at least 1.'
}

$headers = @(
    '-H', 'Accept: application/vnd.github+json',
    '-H', 'X-GitHub-Api-Version: 2022-11-28'
)

$dispatchStartedAt = (Get-Date).ToUniversalTime()
$dispatchBody = @{
    ref = $Ref
    inputs = @{
        'report-month' = $ReportMonth
        'skip-slack'   = 'true'
    }
} | ConvertTo-Json -Depth 5 -Compress

$null = $dispatchBody | gh api @headers "repos/$Repository/actions/workflows/$WorkflowFile/dispatches" --method POST --input -
Start-Sleep -Seconds 8

$run = $null
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)

while ((Get-Date) -lt $deadline) {
    $runs = gh api @headers "repos/$Repository/actions/workflows/$WorkflowFile/runs?event=workflow_dispatch&branch=$Ref&per_page=10" | ConvertFrom-Json
    $run = $runs.workflow_runs |
        Where-Object { ([datetime]$_.created_at).ToUniversalTime() -ge $dispatchStartedAt.AddMinutes(-1) } |
        Sort-Object created_at -Descending |
        Select-Object -First 1

    if ($null -eq $run) {
        Start-Sleep -Seconds $PollSeconds
        continue
    }

    if ($run.status -eq 'completed') {
        break
    }

    Start-Sleep -Seconds $PollSeconds
}

if ($null -eq $run) {
    throw "No workflow run was detected for $WorkflowFile after dispatch."
}

if ($run.status -ne 'completed') {
    throw "Workflow run $($run.id) did not complete within $TimeoutMinutes minute(s)."
}

if ($run.conclusion -ne 'success') {
    throw "Workflow run $($run.id) completed with conclusion '$($run.conclusion)'."
}

$reportPath = "reports/copilot-metrics-$ReportMonth.html"
$report = gh api @headers "repos/$Repository/contents/$reportPath?ref=$Ref" | ConvertFrom-Json
$html = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($report.content -replace "`n", '')))

$sectionStart = $html.IndexOf('<h2>&#128293; Top 50 Most Active Users</h2>')
if ($sectionStart -lt 0) {
    throw "Top 50 section not found in $reportPath."
}

$tbodyStart = $html.IndexOf('<tbody>', $sectionStart)
$tbodyEnd = $html.IndexOf('</tbody>', $tbodyStart)
if ($tbodyStart -lt 0 -or $tbodyEnd -lt 0) {
    throw "Top 50 table body not found in $reportPath."
}

$tbody = $html.Substring($tbodyStart + 7, $tbodyEnd - ($tbodyStart + 7))
$rows = [regex]::Matches($tbody, '<tr><td>([^<]+)</td><td>([^<]+)</td><td>([^<]+)</td><td>([^<]*)</td><td>([^<]+)</td></tr>')

if ($rows.Count -eq 0) {
    throw "No premium ranking rows were parsed from $reportPath."
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($row in ($rows | Select-Object -First $Top)) {
    $premiumText = ($row.Groups[2].Value -replace ',', '').Trim()
    $premiumValue = 0.0
    $null = [double]::TryParse($premiumText, [ref]$premiumValue)

    $results.Add([pscustomobject]@{
        Rank            = $results.Count + 1
        Login           = $row.Groups[1].Value
        PremiumRequests = [math]::Round($premiumValue, 1)
        DaysActive      = [int]$row.Groups[3].Value
        LastEditor      = $row.Groups[4].Value
        LastActivity    = $row.Groups[5].Value
    }) | Out-Null
}

[pscustomobject]@{
    Repository = $Repository
    WorkflowRunId = $run.id
    WorkflowUrl = $run.html_url
    ReportMonth = $ReportMonth
    ReportPath = $reportPath
    TopConsumers = $results
}
