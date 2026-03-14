#Requires -Version 7.0
<#
.SYNOPSIS
    Calculates a universal productivity score for one or more GitHub users.
.DESCRIPTION
    Uses Get-UserProductivityBreakdown.ps1 as the source of truth for raw metrics,
    then computes a normalized composite score across all numeric outputs. Each
    metric is log-transformed and percentile-ranked within the requested user set
    to keep large outliers from dominating the score.

    The v1 weighting model keeps all numeric metrics in play with near-equal
    importance while giving a slight edge to premium requests, commits, and merged
    pull requests.
.PARAMETER Usernames
    GitHub usernames to score.
.PARAMETER Since
    Inclusive start date for the scoring window.
.PARAMETER Until
    Inclusive end date for the scoring window.
.PARAMETER OutputFormat
    Output mode: Table or Json.
.EXAMPLE
    .\Get-UserProductivityScores.ps1 -Usernames npeterson-relias,fhemmerrelias -Since '2026-03-01' -Until '2026-03-14'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Usernames,

    [Parameter(Mandatory)]
    [datetime]$Since,

    [Parameter(Mandatory)]
    [datetime]$Until,

    [ValidateSet('Table', 'Json')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

if ($Since.Date -gt $Until.Date) {
    throw 'Since must be earlier than or equal to Until.'
}

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

function Get-TransformedMetricValue {
    param(
        [Parameter(Mandatory)]
        [double]$Value
    )

    if ($Value -lt 0) {
        return -[math]::Log(1 + [math]::Abs($Value))
    }

    return [math]::Log(1 + $Value)
}

function Get-PercentileScoreMap {
    param(
        [Parameter(Mandatory)]
        [object[]]$Results,

        [Parameter(Mandatory)]
        [string]$MetricName
    )

    $entries = @(
        foreach ($result in $Results) {
            [PSCustomObject]@{
                Username    = $result.Username
                Transformed = Get-TransformedMetricValue -Value ([double]$result.$MetricName)
            }
        }
    )

    $scoreMap = @{}
    if ($entries.Count -eq 1) {
        $scoreMap[$entries[0].Username] = 100.0
        return $scoreMap
    }

    $distinctValues = @($entries.Transformed | Sort-Object -Unique)
    if ($distinctValues.Count -eq 1) {
        foreach ($entry in $entries) {
            $scoreMap[$entry.Username] = 50.0
        }

        return $scoreMap
    }

    $sortedEntries = @($entries | Sort-Object -Property Transformed, Username)
    $position = 0
    while ($position -lt $sortedEntries.Count) {
        $groupStart = $position
        $currentValue = $sortedEntries[$position].Transformed

        while (($position + 1) -lt $sortedEntries.Count -and $sortedEntries[$position + 1].Transformed -eq $currentValue) {
            $position++
        }

        $groupEnd = $position
        $averageIndex = ($groupStart + $groupEnd) / 2.0
        $score = [math]::Round(($averageIndex / ($sortedEntries.Count - 1)) * 100, 2)

        for ($index = $groupStart; $index -le $groupEnd; $index++) {
            $scoreMap[$sortedEntries[$index].Username] = $score
        }

        $position++
    }

    return $scoreMap
}

$breakdownScriptPath = Join-Path $PSScriptRoot 'Get-UserProductivityBreakdown.ps1'
if (-not (Test-Path -LiteralPath $breakdownScriptPath)) {
    throw "Could not find breakdown script at '$breakdownScriptPath'."
}

$distinctUsernames = @($Usernames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
if ($distinctUsernames.Count -eq 0) {
    throw 'At least one username is required.'
}

$rawResults = [System.Collections.Generic.List[object]]::new()
foreach ($username in $distinctUsernames) {
    Write-Information "Calculating raw productivity metrics for $username..." -InformationAction Continue
    $rawJson = & $breakdownScriptPath -Username $username -Since $Since -Until $Until -OutputFormat Json
    $rawResults.Add(($rawJson | ConvertFrom-Json))
}

$metricScoreMaps = @{}
foreach ($metricName in $metricWeights.Keys) {
    $metricScoreMaps[$metricName] = Get-PercentileScoreMap -Results $rawResults -MetricName $metricName
}

$scoredResults = @(
    foreach ($result in $rawResults) {
        $normalizedScores = [ordered]@{}
        $weightedContributions = [ordered]@{}
        $universalScore = 0.0

        foreach ($metricName in $metricWeights.Keys) {
            $metricScore = [double]$metricScoreMaps[$metricName][$result.Username]
            $weightedContribution = [math]::Round($metricScore * $metricWeights[$metricName], 2)
            $normalizedScores[$metricName] = $metricScore
            $weightedContributions[$metricName] = $weightedContribution
            $universalScore += $weightedContribution
        }

        [PSCustomObject]@{
            Username              = $result.Username
            UniversalScore        = [math]::Round($universalScore, 2)
            StartDate             = $result.StartDate
            EndDate               = $result.EndDate
            PremiumRequests       = $result.PremiumRequests
            Commits               = $result.Commits
            LinesAdded            = $result.LinesAdded
            LinesDeleted          = $result.LinesDeleted
            NetLOC                = $result.NetLOC
            TotalLinesChanged     = $result.TotalLinesChanged
            OpenPRs               = $result.OpenPRs
            MergedPRs             = $result.MergedPRs
            ClosedPRs             = $result.ClosedPRs
            ApprovedReviews       = $result.ApprovedReviews
            CommentReviews        = $result.CommentReviews
            OpenIssues            = $result.OpenIssues
            ClosedIssues          = $result.ClosedIssues
            WorkflowRuns          = $result.WorkflowRuns
            NormalizedScores      = [PSCustomObject]$normalizedScores
            WeightedContributions = [PSCustomObject]$weightedContributions
        }
    }
)

$rankedResults = @(
    $scoredResults |
        Sort-Object -Property @(
            @{ Expression = 'UniversalScore'; Descending = $true }
            @{ Expression = 'Username'; Descending = $false }
        )
)

$outputResults = [System.Collections.Generic.List[object]]::new()
$rank = 1
foreach ($result in $rankedResults) {
    $outputResults.Add([PSCustomObject]@{
        Rank                  = $rank
        Username              = $result.Username
        UniversalScore        = $result.UniversalScore
        StartDate             = $result.StartDate
        EndDate               = $result.EndDate
        PremiumRequests       = $result.PremiumRequests
        Commits               = $result.Commits
        LinesAdded            = $result.LinesAdded
        LinesDeleted          = $result.LinesDeleted
        NetLOC                = $result.NetLOC
        TotalLinesChanged     = $result.TotalLinesChanged
        OpenPRs               = $result.OpenPRs
        MergedPRs             = $result.MergedPRs
        ClosedPRs             = $result.ClosedPRs
        ApprovedReviews       = $result.ApprovedReviews
        CommentReviews        = $result.CommentReviews
        OpenIssues            = $result.OpenIssues
        ClosedIssues          = $result.ClosedIssues
        WorkflowRuns          = $result.WorkflowRuns
        NormalizedScores      = $result.NormalizedScores
        WeightedContributions = $result.WeightedContributions
    })
    $rank++
}

if ($OutputFormat -eq 'Json') {
    [PSCustomObject]@{
        StartDate = $Since.ToString('yyyy-MM-dd')
        EndDate   = $Until.ToString('yyyy-MM-dd')
        Weights   = [PSCustomObject]$metricWeights
        Users     = @($outputResults)
    } | ConvertTo-Json -Depth 8 | Write-Output
    return
}

$outputResults |
    Select-Object Rank, Username, UniversalScore, PremiumRequests, Commits, LinesAdded, LinesDeleted,
        NetLOC, TotalLinesChanged, OpenPRs, MergedPRs, ClosedPRs, ApprovedReviews,
        CommentReviews, OpenIssues, ClosedIssues, WorkflowRuns |
    Format-Table -AutoSize | Out-String | Write-Output