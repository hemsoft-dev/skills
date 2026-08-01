[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Url,

    [Parameter(Mandatory = $false)]
    [string] $Repo,

    [Parameter(Mandatory = $false)]
    [int] $PullNumber,

    [Parameter(Mandatory = $false)]
    [string] $ReviewerAuthorPattern = '(?i)(set-it-free-loop|sfl-app)'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PrIdentity {
    param(
        [string] $InputUrl,
        [string] $InputRepo,
        [int] $InputPullNumber
    )

    if ($InputUrl) {
        if ($InputUrl -notmatch '^https://github\.com/([^/]+)/([^/]+)/pull/(\d+)(?:[/?#].*)?$') {
            throw "Unsupported PR URL: $InputUrl"
        }

        return [pscustomobject]@{
            Owner = $Matches[1]
            Name = $Matches[2]
            PullNumber = [int] $Matches[3]
        }
    }

    if (-not $InputRepo -or -not $InputPullNumber) {
        throw 'Provide either -Url or both -Repo OWNER/REPO and -PullNumber.'
    }

    $repoParts = $InputRepo -split '/', 2
    if ($repoParts.Count -ne 2 -or -not $repoParts[0] -or -not $repoParts[1]) {
        throw "Repo must be in OWNER/REPO form: $InputRepo"
    }

    [pscustomobject]@{
        Owner = $repoParts[0]
        Name = $repoParts[1]
        PullNumber = $InputPullNumber
    }
}

function Invoke-Gh {
    param(
        [string[]] $Arguments
    )

    $output = & $script:Gh @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "gh $($Arguments -join ' ') failed with exit code ${exitCode}: $($output -join [Environment]::NewLine)"
    }

    $output -join [Environment]::NewLine
}

function Get-GhEndpoint {
    param(
        [string] $Endpoint
    )

    try {
        (Invoke-Gh -Arguments @('api', $Endpoint)) | ConvertFrom-Json
    } catch {
        if ($_.Exception.Message -match '(?i)HTTP 404|Not Found') {
            return $null
        }

        throw
    }
}

function Get-Severity {
    param(
        [string] $Body
    )

    foreach ($severity in @('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')) {
        if ($Body -match "(?i)\*\*${severity}\s") {
            return $severity
        }
    }

    'UNKNOWN'
}

function Get-OptionalProperty {
    param(
        [object] $InputObject,
        [string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    $null
}

$script:Gh = (Get-Command gh.exe).Source
$identity = Resolve-PrIdentity -InputUrl $Url -InputRepo $Repo -InputPullNumber $PullNumber
$repository = "$($identity.Owner)/$($identity.Name)"

$workflow = Get-GhEndpoint -Endpoint "repos/$repository/actions/workflows/sfl-pr-review.lock.yml"
$label = Get-GhEndpoint -Endpoint "repos/$repository/labels/sfl-review"
$workflowExists = $null -ne $workflow
$workflowActive = $workflowExists -and $workflow.state -eq 'active'
$workflowState = if ($workflowExists) { [string] $workflow.state } else { $null }
$labelExists = $null -ne $label

$repoData = (Invoke-Gh -Arguments @('api', "repos/$repository")) | ConvertFrom-Json
$workflowSource = Get-GhEndpoint -Endpoint (
    "repos/$repository/contents/.github/workflows/sfl-pr-review.lock.yml" +
    "?ref=$([uri]::EscapeDataString([string] $repoData.default_branch))"
)
$workflowContent = if ($workflowSource -and $workflowSource.content) {
    [Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String(([string] $workflowSource.content -replace '\s', ''))
    )
} else {
    ''
}
$dispatchSupported = $workflowContent -match '(?m)^\s*workflow_dispatch:\s*$'
$requestMode = if ($dispatchSupported) {
    'workflow_dispatch'
} elseif ($labelExists) {
    'legacy_label'
} else {
    $null
}

$pr = (Invoke-Gh -Arguments @(
    'api',
    "repos/$repository/pulls/$($identity.PullNumber)"
)) | ConvertFrom-Json

$legacyWorkflowRuns = $null
if ($workflowExists -and $labelExists) {
    $encodedHeadRef = [uri]::EscapeDataString([string] $pr.head.ref)
    $legacyWorkflowRuns = Get-GhEndpoint -Endpoint (
        "repos/$repository/actions/workflows/sfl-pr-review.lock.yml/runs" +
        "?branch=$encodedHeadRef&event=pull_request&per_page=100"
    )
}

$currentHeadWorkflowRuns = if ($legacyWorkflowRuns) {
    @($legacyWorkflowRuns.workflow_runs) | Where-Object head_sha -eq $pr.head.sha
} else {
    @()
}

$activeSflRuns = @($currentHeadWorkflowRuns) | Where-Object status -ne 'completed'
$latestSflWorkflowRun = @($currentHeadWorkflowRuns) |
    Sort-Object created_at -Descending |
    Select-Object -First 1

$reviews = @((Invoke-Gh -Arguments @(
    'api',
    "repos/$repository/pulls/$($identity.PullNumber)/reviews?per_page=100"
)) | ConvertFrom-Json)

$sflReviews = @($reviews) | Where-Object {
    $_.user -and $_.user.login -match $ReviewerAuthorPattern
}

$currentHeadSflReviews = @($sflReviews) | Where-Object commit_id -eq $pr.head.sha
$latestSflReview = @($currentHeadSflReviews) |
    Sort-Object submitted_at -Descending |
    Select-Object -First 1

$reviewMatchesHead = $false
$verdictApproved = $false
$reviewRunId = $null
$reviewComments = @()

if ($latestSflReview) {
    $reviewMatchesHead = $latestSflReview.commit_id -eq $pr.head.sha
    $verdictApproved = $latestSflReview.body -match '(?i)Verdict:\s*APPROVE'

    if ($latestSflReview.body -match 'SFL run ID:\s*(\d+)') {
        $reviewRunId = $Matches[1]
    }

    $reviewComments = @((Invoke-Gh -Arguments @(
        'api',
        "repos/$repository/pulls/$($identity.PullNumber)/reviews/$($latestSflReview.id)/comments?per_page=100"
    )) | ConvertFrom-Json)
}

$findings = @($reviewComments) | ForEach-Object {
    [pscustomobject]@{
        id = $_.id
        severity = Get-Severity -Body $_.body
        path = Get-OptionalProperty -InputObject $_ -Name 'path'
        line = Get-OptionalProperty -InputObject $_ -Name 'line'
        url = Get-OptionalProperty -InputObject $_ -Name 'html_url'
        body = $_.body
    }
}

$severityCounts = [ordered]@{
    critical = @($findings | Where-Object severity -eq 'CRITICAL').Count
    high = @($findings | Where-Object severity -eq 'HIGH').Count
    medium = @($findings | Where-Object severity -eq 'MEDIUM').Count
    low = @($findings | Where-Object severity -eq 'LOW').Count
    unknown = @($findings | Where-Object severity -eq 'UNKNOWN').Count
}

$threadQuery = @'
query($owner: String!, $name: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $after) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 20) {
            nodes {
              author {
                login
              }
              body
              url
            }
          }
        }
      }
    }
  }
}
'@

$allThreadNodes = @()
$after = $null

do {
    $threadArguments = @(
        'api', 'graphql',
        '-f', "query=$threadQuery",
        '-F', "owner=$($identity.Owner)",
        '-F', "name=$($identity.Name)",
        '-F', "number=$($identity.PullNumber)"
    )

    if ($after) {
        $threadArguments += @('-F', "after=$after")
    }

    $threadData = (Invoke-Gh -Arguments $threadArguments) | ConvertFrom-Json
    $page = $threadData.data.repository.pullRequest.reviewThreads
    $allThreadNodes += @($page.nodes)
    $after = if ($page.pageInfo.hasNextPage) { $page.pageInfo.endCursor } else { $null }
} while ($after)

$unresolvedSflThreads = @($allThreadNodes) |
    Where-Object {
        $thread = $_
        $hasSflComment = @($thread.comments.nodes) | Where-Object {
            $_.author -and $_.author.login -match $ReviewerAuthorPattern
        }

        -not $thread.isResolved -and $hasSflComment
    } |
    ForEach-Object {
        $thread = $_
        $firstSflComment = @($thread.comments.nodes) | Where-Object {
            $_.author -and $_.author.login -match $ReviewerAuthorPattern
        } | Select-Object -First 1

        [pscustomobject]@{
            id = $thread.id
            path = $thread.path
            line = $thread.line
            isOutdated = $thread.isOutdated
            firstSflAuthor = $firstSflComment.author.login
            firstSflUrl = $firstSflComment.url
            firstSflBody = $firstSflComment.body
        }
    }

$checkRuns = @((Invoke-Gh -Arguments @(
    'api',
    "repos/$repository/commits/$($pr.head.sha)/check-runs?per_page=100"
)) | ConvertFrom-Json).check_runs

$approvalGate = @($checkRuns) |
    Where-Object name -eq 'SFL Reviewer Approval' |
    Sort-Object completed_at -Descending |
    Select-Object -First 1

$gatePassed = $approvalGate -and $approvalGate.status -eq 'completed' -and $approvalGate.conclusion -eq 'success'
$zeroFindings = ($severityCounts.critical + $severityCounts.high + $severityCounts.medium +
    $severityCounts.low + $severityCounts.unknown) -eq 0

[pscustomobject]@{
    repository = $repository
    pullNumber = $identity.PullNumber
    url = $pr.html_url
    headRefName = $pr.head.ref
    headRefOid = $pr.head.sha
    reviewerAvailable = $workflowActive -and [bool] $requestMode
    workflowExists = $workflowExists
    workflowState = $workflowState
    triggerLabelExists = $labelExists
    dispatchSupported = $dispatchSupported
    requestMode = $requestMode
    activeSflRunCount = @($activeSflRuns).Count
    latestSflWorkflowRun = $latestSflWorkflowRun
    sflReviewCount = @($sflReviews).Count
    currentHeadSflReviewCount = @($currentHeadSflReviews).Count
    latestSflReview = $latestSflReview
    latestReviewRunId = $reviewRunId
    reviewMatchesHead = $reviewMatchesHead
    verdictApproved = $verdictApproved
    findingCounts = $severityCounts
    findings = $findings
    unresolvedSflThreadCount = @($unresolvedSflThreads).Count
    unresolvedSflThreads = $unresolvedSflThreads
    approvalGate = $approvalGate
    approvalGatePassed = [bool] $gatePassed
    cleanSheet = [bool] (
        ($workflowActive -and [bool] $requestMode) -and
        $reviewMatchesHead -and
        $verdictApproved -and
        $zeroFindings -and
        @($unresolvedSflThreads).Count -eq 0 -and
        $gatePassed
    )
} | ConvertTo-Json -Depth 20
