#Requires -Version 7.0
<#
.SYNOPSIS
    Reports per-user productivity metrics across a GitHub organization.
.DESCRIPTION
    Collects authored pull requests and commit counts for a GitHub user across
    all repositories in an organization. Pull request metrics are grouped into
    open, merged, and closed-unmerged buckets. Commit counts are gathered per
    repository through the GitHub REST API and totaled across the organization.

    By default, the script analyzes all repositories in the organization and
    emits a human-readable table. Use -OutputFormat Json for structured output.
.PARAMETER Username
    GitHub username to analyze.
.PARAMETER Org
    GitHub organization to analyze. Defaults to relias-engineering.
.PARAMETER Since
    Optional lower bound for authored commits and pull requests. Pull request
    filtering is based on created date.
.PARAMETER Until
    Optional upper bound for authored commits and pull requests. Pull request
    filtering is based on created date.
.PARAMETER ThrottleMs
    Optional delay between per-repository commit API requests.
.PARAMETER IncludeArchived
    Include archived repositories.
.PARAMETER IncludeForks
    Include forked repositories.
.PARAMETER IncludeInactiveRepos
    Include repositories with zero commits and zero pull requests in the output.
.PARAMETER OutputFormat
    Output mode: Table or Json.
.EXAMPLE
    .\Get-UserOrgProductivity.ps1 -Username ssadhula-relias
.EXAMPLE
    .\Get-UserOrgProductivity.ps1 -Username ssadhula-relias -Since (Get-Date).AddDays(-30)
.EXAMPLE
    .\Get-UserOrgProductivity.ps1 -Username ssadhula-relias -OutputFormat Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [ValidateNotNullOrEmpty()]
    [string]$Org = 'relias-engineering',

    [Nullable[datetime]]$Since,

    [Nullable[datetime]]$Until,

    [ValidateRange(0, 5000)]
    [int]$ThrottleMs = 0,

    [switch]$IncludeArchived,

    [switch]$IncludeForks,

    [switch]$IncludeInactiveRepos,

    [ValidateSet('Table', 'Json')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

if ($Since -and $Until -and $Since -gt $Until) {
    throw 'Since must be earlier than or equal to Until.'
}

function Invoke-GhApiJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$AllowFailure
    )

    $output = & gh api $Path 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) {
            return $null
        }

        throw "GitHub API call failed for '$Path': $($output | Out-String)"
    }

    if ([string]::IsNullOrWhiteSpace(($output | Out-String))) {
        return $null
    }

    return $output | ConvertFrom-Json
}

function Invoke-GhGraphQlJson {
    param(
        [Parameter(Mandatory)]
        [string]$Query
    )

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tempFile, $Query)
        $output = & gh api graphql -f "query=$(Get-Content $tempFile -Raw)" 2>&1
    }
    finally {
        if ([System.IO.File]::Exists($tempFile)) {
            [System.IO.File]::Delete($tempFile)
        }
    }

    if ($LASTEXITCODE -ne 0) {
        throw "GitHub GraphQL query failed: $($output | Out-String)"
    }

    return $output | ConvertFrom-Json
}

function ConvertTo-GraphQlStringLiteral {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return ($Value -replace '\\', '\\\\' -replace '"', '\\"')
}

function Get-DateQualifier {
    param(
        [Parameter(Mandatory)]
        [string]$FieldName,

        [Nullable[datetime]]$Start,

        [Nullable[datetime]]$End
    )

    if (-not $Start -and -not $End) {
        return $null
    }

    if ($Start -and $End) {
        return "${FieldName}:$($Start.ToString('yyyy-MM-dd'))..$($End.ToString('yyyy-MM-dd'))"
    }

    if ($Start) {
        return "${FieldName}:>=$($Start.ToString('yyyy-MM-dd'))"
    }

    return "${FieldName}:<=$($End.ToString('yyyy-MM-dd'))"
}

function New-RepoMetric {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Repository
    )

    return [PSCustomObject]@{
        Repo               = $Repository.nameWithOwner
        Url                = $Repository.url
        IsArchived         = $Repository.isArchived
        IsFork             = $Repository.isFork
        OpenPRs            = 0
        MergedPRs          = 0
        ClosedUnmergedPRs  = 0
        DraftOpenPRs       = 0
        TotalPRs           = 0
        Commits            = 0
    }
}

function Get-CommitCountForRepository {
    param(
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [string]$Author,

        [Nullable[datetime]]$Start,

        [Nullable[datetime]]$End,

        [int]$DelayMs
    )

    $queryParts = @(
        "author=$([System.Uri]::EscapeDataString($Author))",
        'per_page=100'
    )

    if ($Start) {
        $queryParts += "since=$([System.Uri]::EscapeDataString($Start.ToUniversalTime().ToString('o')))"
    }

    if ($End) {
        $queryParts += "until=$([System.Uri]::EscapeDataString($End.ToUniversalTime().ToString('o')))"
    }

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

        if ($DelayMs -gt 0) {
            Start-Sleep -Milliseconds $DelayMs
        }
    } while ($batch.Count -eq 100)

    return $commitCount
}

try {
    [void](& gh auth status 2>&1)
}
catch {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

$userProfile = Invoke-GhApiJson -Path "/users/$Username"

$repositories = @(gh repo list $Org --limit 500 --json name,nameWithOwner,isArchived,isFork,url | ConvertFrom-Json)
if (-not $IncludeArchived) {
    $repositories = @($repositories | Where-Object { -not $_.isArchived })
}

if (-not $IncludeForks) {
    $repositories = @($repositories | Where-Object { -not $_.isFork })
}

$repoMetrics = [ordered]@{}
foreach ($repository in $repositories) {
    $repoMetrics[$repository.nameWithOwner] = New-RepoMetric -Repository $repository
}

$prSearchParts = @(
    "org:$Org",
    "author:$Username",
    'is:pr'
)

$createdDateQualifier = Get-DateQualifier -FieldName 'created' -Start $Since -End $Until
if ($createdDateQualifier) {
    $prSearchParts += $createdDateQualifier
}

$prSearch = $prSearchParts -join ' '
$escapedPrSearch = ConvertTo-GraphQlStringLiteral -Value $prSearch
$prCursor = $null

do {
    $afterClause = if ($prCursor) { ', after: "{0}"' -f $prCursor } else { '' }
    $query = @"
query {
  search(query: "$escapedPrSearch", type: ISSUE, first: 100$afterClause) {
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on PullRequest {
        repository { nameWithOwner }
        number
        title
        url
        state
        isDraft
        merged
        createdAt
        closedAt
        mergedAt
      }
    }
  }
}
"@

    $result = Invoke-GhGraphQlJson -Query $query
    $searchResult = $result.data.search

    foreach ($pullRequest in @($searchResult.nodes)) {
        if ($null -eq $pullRequest) {
            continue
        }

        if (-not $repoMetrics.Contains($pullRequest.repository.nameWithOwner)) {
            continue
        }

        $metric = $repoMetrics[$pullRequest.repository.nameWithOwner]
        $metric.TotalPRs++

        if ($pullRequest.state -eq 'OPEN') {
            $metric.OpenPRs++
            if ($pullRequest.isDraft) {
                $metric.DraftOpenPRs++
            }
            continue
        }

        if ($pullRequest.merged) {
            $metric.MergedPRs++
            continue
        }

        $metric.ClosedUnmergedPRs++
    }

    $prCursor = $searchResult.pageInfo.endCursor
    $hasNextPage = $searchResult.pageInfo.hasNextPage
} while ($hasNextPage)

$repoIndex = 0
foreach ($repository in $repositories) {
    $repoIndex++
    $percentComplete = if ($repositories.Count -gt 0) {
        [int](($repoIndex / $repositories.Count) * 100)
    }
    else {
        100
    }

    Write-Progress -Activity 'Collecting commit counts' -Status $repository.nameWithOwner -PercentComplete $percentComplete

    $metric = $repoMetrics[$repository.nameWithOwner]
    $metric.Commits = Get-CommitCountForRepository -Organization $Org -RepositoryName $repository.name -Author $Username -Start $Since -End $Until -DelayMs $ThrottleMs
}

Write-Progress -Activity 'Collecting commit counts' -Completed

$activeRepositories = @(
    $repoMetrics.Values | Where-Object {
        $_.TotalPRs -gt 0 -or $_.Commits -gt 0
    } | Sort-Object @{ Expression = { $_.Commits + $_.TotalPRs }; Descending = $true }, Repo
)

$displayRepositories = if ($IncludeInactiveRepos) {
    @($repoMetrics.Values | Sort-Object Repo)
}
else {
    $activeRepositories
}

$summary = [PSCustomObject]@{
    Username                 = $Username
    DisplayName              = $userProfile.name
    Organization             = $Org
    Since                    = if ($Since) { $Since.ToString('o') } else { $null }
    Until                    = if ($Until) { $Until.ToString('o') } else { $null }
    RepositoriesAnalyzed     = $repositories.Count
    RepositoriesWithActivity = $activeRepositories.Count
    PullRequestsOpen         = ($repoMetrics.Values | Measure-Object -Property OpenPRs -Sum).Sum
    PullRequestsMerged       = ($repoMetrics.Values | Measure-Object -Property MergedPRs -Sum).Sum
    PullRequestsClosedUnmerged = ($repoMetrics.Values | Measure-Object -Property ClosedUnmergedPRs -Sum).Sum
    DraftOpenPullRequests    = ($repoMetrics.Values | Measure-Object -Property DraftOpenPRs -Sum).Sum
    PullRequestsTotal        = ($repoMetrics.Values | Measure-Object -Property TotalPRs -Sum).Sum
    CommitsTotal             = ($repoMetrics.Values | Measure-Object -Property Commits -Sum).Sum
    CommitCountSource        = 'GitHub REST commits API (author=username)'
    GeneratedAt              = (Get-Date).ToString('o')
}

$report = [PSCustomObject]@{
    Summary      = $summary
    Repositories = $displayRepositories
}

if ($OutputFormat -eq 'Json') {
    $report | ConvertTo-Json -Depth 6
    return
}

$summaryTable = @(
    [PSCustomObject]@{ Metric = 'Username'; Value = $summary.Username }
    [PSCustomObject]@{ Metric = 'Display Name'; Value = if ($summary.DisplayName) { $summary.DisplayName } else { '-' } }
    [PSCustomObject]@{ Metric = 'Organization'; Value = $summary.Organization }
    [PSCustomObject]@{ Metric = 'Repositories analyzed'; Value = $summary.RepositoriesAnalyzed }
    [PSCustomObject]@{ Metric = 'Repositories with activity'; Value = $summary.RepositoriesWithActivity }
    [PSCustomObject]@{ Metric = 'Open PRs'; Value = $summary.PullRequestsOpen }
    [PSCustomObject]@{ Metric = 'Merged PRs'; Value = $summary.PullRequestsMerged }
    [PSCustomObject]@{ Metric = 'Closed unmerged PRs'; Value = $summary.PullRequestsClosedUnmerged }
    [PSCustomObject]@{ Metric = 'Draft open PRs'; Value = $summary.DraftOpenPullRequests }
    [PSCustomObject]@{ Metric = 'Total PRs'; Value = $summary.PullRequestsTotal }
    [PSCustomObject]@{ Metric = 'Total commits'; Value = $summary.CommitsTotal }
)

Write-Output "### Productivity for $Username in $Org"
Write-Output ''
$summaryTable | Format-Table -AutoSize | Out-String | Write-Output

if ($displayRepositories.Count -eq 0) {
    Write-Output 'No repository activity found for the supplied filters.'
    return
}

Write-Output '### Repository Breakdown'
Write-Output ''
$displayRepositories |
    Select-Object Repo, Commits, OpenPRs, MergedPRs, ClosedUnmergedPRs, DraftOpenPRs, TotalPRs |
    Format-Table -AutoSize | Out-String | Write-Output