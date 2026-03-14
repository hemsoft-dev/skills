#Requires -Version 7.0
<#
.SYNOPSIS
    Reports premium requests and authored productivity counts for one user over a date range.
.DESCRIPTION
    Queries the Bertelsmann enterprise premium request billing endpoint and the
    GitHub APIs for authored activity in relias-engineering. The script accepts
    exactly three parameters: start date, end date, and GitHub username.

    Pull request counts are based on PRs created during the requested period and
    are bucketed into open, merged, and closed-unmerged states. Issue counts are
    based on issues created during the requested period and are bucketed into
    open and closed states. Workflow runs count runs triggered by the user
    during the requested period across all non-archived, non-forked repositories.
    Commit line totals are calculated from all committed file changes, and PR review
    activity counts submitted APPROVED and COMMENTED reviews during the period.
.PARAMETER Username
    GitHub username to analyze.
.PARAMETER Since
    Inclusive start date for the reporting period.
.PARAMETER Until
    Inclusive end date for the reporting period.
.EXAMPLE
    .\Get-UserProductivityBreakdown.ps1 -Username fhemmerrelias -Since '2026-02-01' -Until '2026-02-28'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory)]
    [datetime]$Since,

    [Parameter(Mandatory)]
    [datetime]$Until
)

$ErrorActionPreference = 'Stop'

$Organization = 'relias-engineering'
$Enterprise = 'bertelsmann'
$SinceUtc = $Since.Date.ToUniversalTime()
$UntilUtc = $Until.Date.AddDays(1).AddTicks(-1).ToUniversalTime()

if ($Since.Date -gt $Until.Date) {
    throw 'Since must be earlier than or equal to Until.'
}

function Test-IsWithinRange {
    param(
        [Parameter(Mandatory)]
        [datetime]$Value,

        [Parameter(Mandatory)]
        [datetime]$Start,

        [Parameter(Mandatory)]
        [datetime]$End
    )

    return $Value -ge $Start -and $Value -le $End
}

function Invoke-GhApiJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string[]]$Headers,

        [switch]$AllowFailure
    )

    $arguments = @('api')
    if ($null -ne $Headers) {
        foreach ($header in $Headers) {
            $arguments += @('-H', $header)
        }
    }
    $arguments += $Path

    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $output = & gh @arguments 2> $stderrFile
        $stderrOutput = Get-Content $stderrFile -Raw -ErrorAction SilentlyContinue
    }
    finally {
        if ([System.IO.File]::Exists($stderrFile)) {
            [System.IO.File]::Delete($stderrFile)
        }
    }

    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) {
            return $null
        }

        $errorMessage = $stderrOutput
        if ([string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = ($output | Out-String).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = "GitHub API call failed for '$Path'."
        }

        Write-Error -Message $errorMessage -ErrorAction Stop
    }

    if ([string]::IsNullOrWhiteSpace(($output | Out-String))) {
        return $null
    }

    return $output | ConvertFrom-Json
}

function Get-DateQualifier {
    param(
        [Parameter(Mandatory)]
        [string]$FieldName,

        [Parameter(Mandatory)]
        [datetime]$Start,

        [Parameter(Mandatory)]
        [datetime]$End
    )

    return "${FieldName}:$($Start.ToString('yyyy-MM-dd'))..$($End.ToString('yyyy-MM-dd'))"
}

function Get-SearchResults {
    param(
        [Parameter(Mandatory)]
        [string[]]$QueryParts
    )

    $page = 1
    $items = [System.Collections.Generic.List[object]]::new()

    do {
        $encodedQuery = [System.Uri]::EscapeDataString(($QueryParts -join ' '))
        $response = Invoke-GhApiJson -Path "/search/issues?q=$encodedQuery&per_page=100&page=$page"
        $batch = @($response.items)
        foreach ($item in $batch) {
            $items.Add($item)
        }
        $page++
    } while ($batch.Count -eq 100)

    return @($items)
}

function Get-PullRequestCount {
    param(
        [Parameter(Mandatory)]
        [string]$Author,

        [Parameter(Mandatory)]
        [string[]]$Qualifiers
    )

    $query = @(
        "org:$Organization",
        "author:$Author",
        'is:pr',
        (Get-DateQualifier -FieldName 'created' -Start $Since -End $Until)
    ) + $Qualifiers

    $encodedQuery = [System.Uri]::EscapeDataString(($query -join ' '))
    $result = Invoke-GhApiJson -Path "/search/issues?q=$encodedQuery&per_page=1"
    return [int]$result.total_count
}

function Get-IssueCount {
    param(
        [Parameter(Mandatory)]
        [string]$Author,

        [Parameter(Mandatory)]
        [string[]]$Qualifiers
    )

    $query = @(
        "org:$Organization",
        "author:$Author",
        'is:issue',
        (Get-DateQualifier -FieldName 'created' -Start $Since -End $Until)
    ) + $Qualifiers

    $encodedQuery = [System.Uri]::EscapeDataString(($query -join ' '))
    $result = Invoke-GhApiJson -Path "/search/issues?q=$encodedQuery&per_page=1"
    return [int]$result.total_count
}

function Get-CommitCountForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName
    )

    $queryParts = @(
        "author=$([System.Uri]::EscapeDataString($Username))",
        "since=$([System.Uri]::EscapeDataString($Since.ToUniversalTime().ToString('o')))",
        "until=$([System.Uri]::EscapeDataString($Until.Date.AddDays(1).AddTicks(-1).ToUniversalTime().ToString('o')))",
        'per_page=100'
    )

    $page = 1
    $commitCount = 0

    do {
        $path = "/repos/$Organization/$RepositoryName/commits?{0}&page={1}" -f ($queryParts -join '&'), $page
        $response = Invoke-GhApiJson -Path $path -AllowFailure
        if ($null -eq $response) {
            break
        }

        $batch = @($response)
        $commitCount += $batch.Count
        $page++
    } while ($batch.Count -eq 100)

    return $commitCount
}

function Get-CommitStatsForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName
    )

    $queryParts = @(
        "author=$([System.Uri]::EscapeDataString($Username))",
        "since=$([System.Uri]::EscapeDataString($SinceUtc.ToString('o')))",
        "until=$([System.Uri]::EscapeDataString($UntilUtc.ToString('o')))",
        'per_page=100'
    )

    $stats = [PSCustomObject]@{
        CommitCount       = 0
        LinesAdded        = 0
        LinesDeleted      = 0
        NetLinesOfCode    = 0
        TotalLinesChanged = 0
    }

    $page = 1

    do {
        $path = "/repos/$Organization/$RepositoryName/commits?{0}&page={1}" -f ($queryParts -join '&'), $page
        $response = Invoke-GhApiJson -Path $path -AllowFailure
        if ($null -eq $response) {
            break
        }

        $batch = @($response)
        foreach ($commit in $batch) {
            $stats.CommitCount++

            $commitSha = $commit.sha
            $details = Invoke-GhApiJson -Path "/repos/$Organization/$RepositoryName/commits/$commitSha" -AllowFailure
            if ($null -eq $details) {
                continue
            }

            foreach ($file in @($details.files)) {
                if ($null -eq $file) {
                    continue
                }

                $added = [int]$file.additions
                $deleted = [int]$file.deletions
                $stats.LinesAdded += $added
                $stats.LinesDeleted += $deleted
                $stats.NetLinesOfCode += ($added - $deleted)
                $stats.TotalLinesChanged += ($added + $deleted)
            }
        }

        $page++
    } while ($batch.Count -eq 100)

    return $stats
}

function Get-TotalCommitCount {
    $repositories = @(gh repo list $Organization --limit 500 --json name,isArchived,isFork | ConvertFrom-Json |
        Where-Object { -not $_.isArchived -and -not $_.isFork })

    $totalCommits = 0
    foreach ($repository in $repositories) {
        $totalCommits += Get-CommitCountForRepository -RepositoryName $repository.name
    }

    return $totalCommits
}

function Get-TotalCommitStats {
    param(
        [Parameter(Mandatory)]
        [object[]]$Repositories
    )

    $totals = [PSCustomObject]@{
        CommitCount       = 0
        LinesAdded        = 0
        LinesDeleted      = 0
        NetLinesOfCode    = 0
        TotalLinesChanged = 0
    }

    foreach ($repository in $Repositories) {
        $repositoryStats = Get-CommitStatsForRepository -RepositoryName $repository.name
        $totals.CommitCount += $repositoryStats.CommitCount
        $totals.LinesAdded += $repositoryStats.LinesAdded
        $totals.LinesDeleted += $repositoryStats.LinesDeleted
        $totals.NetLinesOfCode += $repositoryStats.NetLinesOfCode
        $totals.TotalLinesChanged += $repositoryStats.TotalLinesChanged
    }

    return $totals
}

function Get-RepositoryList {
    return @(gh repo list $Organization --limit 500 --json name,isArchived,isFork | ConvertFrom-Json |
        Where-Object { -not $_.isArchived -and -not $_.isFork })
}

function Get-WorkflowRunCountForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName
    )

    $queryParts = @(
        "actor=$([System.Uri]::EscapeDataString($Username))",
        "created=$([System.Uri]::EscapeDataString("$($Since.ToString('yyyy-MM-dd'))..$($Until.ToString('yyyy-MM-dd'))"))",
        'per_page=100'
    )

    $page = 1
    $workflowRuns = 0

    do {
        $path = "/repos/$Organization/$RepositoryName/actions/runs?{0}&page={1}" -f ($queryParts -join '&'), $page
        $response = Invoke-GhApiJson -Path $path -AllowFailure
        if ($null -eq $response) {
            break
        }

        $batch = @($response.workflow_runs)
        $workflowRuns += $batch.Count
        $page++
    } while ($batch.Count -eq 100)

    return $workflowRuns
}

function Get-TotalWorkflowRunCount {
    param(
        [Parameter(Mandatory)]
        [object[]]$Repositories
    )

    $totalWorkflowRuns = 0
    foreach ($repository in $Repositories) {
        $totalWorkflowRuns += Get-WorkflowRunCountForRepository -RepositoryName $repository.name
    }

    return $totalWorkflowRuns
}

function Get-PullRequestReviewActivity {
    $query = @(
        "org:$Organization",
        "reviewed-by:$Username",
        'is:pr',
        (Get-DateQualifier -FieldName 'updated' -Start $Since -End $Until)
    )

    $items = Get-SearchResults -QueryParts $query
    $activity = [PSCustomObject]@{
        ApprovedReviews = 0
        CommentReviews  = 0
    }

    foreach ($item in $items) {
        if ([string]::IsNullOrWhiteSpace($item.repository_url)) {
            continue
        }

        $repositorySegments = $item.repository_url.TrimEnd('/') -split '/'
        if ($repositorySegments.Count -lt 2) {
            continue
        }

        $repoOwner = $repositorySegments[-2]
        $repoName = $repositorySegments[-1]
        $page = 1

        do {
            $path = "/repos/$repoOwner/$repoName/pulls/$($item.number)/reviews?per_page=100&page=$page"
            $response = Invoke-GhApiJson -Path $path -AllowFailure
            if ($null -eq $response) {
                break
            }

            $batch = @($response)
            foreach ($review in $batch) {
                if ($null -eq $review.user -or $review.user.login -ine $Username) {
                    continue
                }

                if ([string]::IsNullOrWhiteSpace($review.submitted_at)) {
                    continue
                }

                $submittedAt = ([datetimeoffset]::Parse($review.submitted_at)).UtcDateTime
                if (-not (Test-IsWithinRange -Value $submittedAt -Start $SinceUtc -End $UntilUtc)) {
                    continue
                }

                switch ($review.state) {
                    'APPROVED' {
                        $activity.ApprovedReviews++
                    }
                    'COMMENTED' {
                        $activity.CommentReviews++
                    }
                }
            }

            $page++
        } while ($batch.Count -eq 100)
    }

    return $activity
}

function Get-PremiumRequestCount {
    $headers = @('Accept: application/vnd.github+json')
    $total = 0.0

    for ($date = $Since.Date; $date -le $Until.Date; $date = $date.AddDays(1)) {
        $queryString = @(
            "year=$($date.Year)",
            "month=$($date.Month)",
            "day=$($date.Day)",
            "user=$([System.Uri]::EscapeDataString($Username))",
            'product=Copilot'
        ) -join '&'

        $path = "/enterprises/$Enterprise/settings/billing/premium_request/usage?$queryString"
        $response = Invoke-GhApiJson -Path $path -Headers $headers
        foreach ($item in @($response.usageItems)) {
            if ($null -ne $item.grossQuantity) {
                $total += [double]$item.grossQuantity
            }
        }
    }

    return [math]::Round($total, 2)
}

try {
    $null = & gh auth status
}
catch {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

$null = Invoke-GhApiJson -Path "/users/$Username"

$repositories = Get-RepositoryList
$commitStats = Get-TotalCommitStats -Repositories $repositories
$reviewActivity = Get-PullRequestReviewActivity

$summary = [PSCustomObject]@{
    StartDate         = $Since.ToString('yyyy-MM-dd')
    EndDate           = $Until.ToString('yyyy-MM-dd')
    Username          = $Username
    PremiumRequests   = Get-PremiumRequestCount
    Commits           = $commitStats.CommitCount
    LinesAdded        = $commitStats.LinesAdded
    LinesDeleted      = $commitStats.LinesDeleted
    NetLinesOfCode    = $commitStats.NetLinesOfCode
    TotalLinesChanged = $commitStats.TotalLinesChanged
    OpenPRs           = Get-PullRequestCount -Author $Username -Qualifiers @('state:open')
    MergedPRs         = Get-PullRequestCount -Author $Username -Qualifiers @('is:merged')
    ClosedUnmergedPRs = Get-PullRequestCount -Author $Username -Qualifiers @('state:closed', '-is:merged')
    ApprovedReviews  = $reviewActivity.ApprovedReviews
    CommentReviews   = $reviewActivity.CommentReviews
    OpenIssues       = Get-IssueCount -Author $Username -Qualifiers @('state:open')
    ClosedIssues     = Get-IssueCount -Author $Username -Qualifiers @('state:closed')
    WorkflowRuns     = Get-TotalWorkflowRunCount -Repositories $repositories
}

$summaryTable = @(
    [PSCustomObject]@{ Metric = 'Start Date'; Value = $summary.StartDate }
    [PSCustomObject]@{ Metric = 'End Date'; Value = $summary.EndDate }
    [PSCustomObject]@{ Metric = 'Username'; Value = $summary.Username }
    [PSCustomObject]@{ Metric = 'Premium Requests'; Value = $summary.PremiumRequests }
    [PSCustomObject]@{ Metric = 'Commits'; Value = $summary.Commits }
    [PSCustomObject]@{ Metric = 'Lines Added'; Value = $summary.LinesAdded }
    [PSCustomObject]@{ Metric = 'Lines Deleted'; Value = $summary.LinesDeleted }
    [PSCustomObject]@{ Metric = 'Net LOC'; Value = $summary.NetLinesOfCode }
    [PSCustomObject]@{ Metric = 'Total Changed Lines'; Value = $summary.TotalLinesChanged }
    [PSCustomObject]@{ Metric = 'Open PRs'; Value = $summary.OpenPRs }
    [PSCustomObject]@{ Metric = 'Merged PRs'; Value = $summary.MergedPRs }
    [PSCustomObject]@{ Metric = 'Closed PRs'; Value = $summary.ClosedUnmergedPRs }
    [PSCustomObject]@{ Metric = 'Approved Reviews'; Value = $summary.ApprovedReviews }
    [PSCustomObject]@{ Metric = 'Comment Reviews'; Value = $summary.CommentReviews }
    [PSCustomObject]@{ Metric = 'Open Issues'; Value = $summary.OpenIssues }
    [PSCustomObject]@{ Metric = 'Closed Issues'; Value = $summary.ClosedIssues }
    [PSCustomObject]@{ Metric = 'Workflow Runs'; Value = $summary.WorkflowRuns }
)

$summaryTable | Format-Table -AutoSize | Out-String | Write-Output