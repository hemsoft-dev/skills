[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Url,

    [Parameter(Mandatory = $false)]
    [string] $Repo,

    [Parameter(Mandatory = $false)]
    [int] $PullNumber,

    [Parameter(Mandatory = $false)]
    [string] $ReviewerAuthorPattern = '(?i)(codex|chatgpt-codex-connector|coderabbitai|macroscopeapp|greptile(?:ai|-apps))'
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

$script:Gh = (Get-Command gh -CommandType Application -ErrorAction Stop).Source
$identity = Resolve-PrIdentity -InputUrl $Url -InputRepo $Repo -InputPullNumber $PullNumber

$query = @'
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id
      url
      number
      title
      state
      isDraft
      headRefOid
      reviewDecision
      mergeStateStatus
      reviews(last: 100) {
        nodes {
          author {
            login
          }
          state
          body
          submittedAt
          url
          commit {
            oid
          }
        }
      }
      comments(last: 100) {
        nodes {
          author {
            login
          }
          body
          createdAt
          url
        }
      }
      reviewThreads(first: 100) {
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
              createdAt
              url
              pullRequestReview {
                state
                commit {
                  oid
                }
              }
            }
          }
        }
      }
    }
  }
}
'@

$json = Invoke-Gh -Arguments @(
    'api', 'graphql',
    '-f', "query=$query",
    '-F', "owner=$($identity.Owner)",
    '-F', "name=$($identity.Name)",
    '-F', "number=$($identity.PullNumber)"
)

$data = $json | ConvertFrom-Json
$pr = $data.data.repository.pullRequest
if (-not $pr) {
    throw "PR not found: $($identity.Owner)/$($identity.Name)#$($identity.PullNumber)"
}

$reviewerReviews = @($pr.reviews.nodes) | Where-Object {
    $_.author -and $_.author.login -match $ReviewerAuthorPattern
}

$reviewerComments = @($pr.comments.nodes) | Where-Object {
    $_.author -and $_.author.login -match $ReviewerAuthorPattern
}

$reviewerThreads = @($pr.reviewThreads.nodes) | Where-Object {
    $thread = $_
    $hasReviewerComment = @($thread.comments.nodes) | Where-Object {
        $_.author -and $_.author.login -match $ReviewerAuthorPattern
    }
    -not $thread.isResolved -and $hasReviewerComment
}

$threadSummaries = @($reviewerThreads) | ForEach-Object {
    $thread = $_
    $firstReviewerComment = @($thread.comments.nodes) | Where-Object {
        $_.author -and $_.author.login -match $ReviewerAuthorPattern
    } | Select-Object -First 1

    [pscustomobject]@{
        id = $thread.id
        path = $thread.path
        line = $thread.line
        isOutdated = $thread.isOutdated
        firstReviewerAuthor = $firstReviewerComment.author.login
        firstReviewerUrl = $firstReviewerComment.url
        firstReviewerBody = $firstReviewerComment.body
        reviewCommitOid = if ($firstReviewerComment.pullRequestReview) { $firstReviewerComment.pullRequestReview.commit.oid } else { $null }
    }
}

function Get-ProviderState {
    param(
        [Parameter(Mandatory = $true)]
        [object] $PullRequest,

        [Parameter(Mandatory = $true)]
        [string] $AuthorPattern,

        [AllowNull()]
        [object] $LatestCheck
    )

    $reviews = @($PullRequest.reviews.nodes) | Where-Object {
        $_.author -and $_.author.login -match $AuthorPattern
    }
    $comments = @($PullRequest.comments.nodes) | Where-Object {
        $_.author -and $_.author.login -match $AuthorPattern
    }
    $threads = @($PullRequest.reviewThreads.nodes) |
        Where-Object {
            $thread = $_
            -not $thread.isResolved -and @(
                $thread.comments.nodes | Where-Object {
                    $_.author -and $_.author.login -match $AuthorPattern
                }
            ).Count -gt 0
        } |
        ForEach-Object {
            $thread = $_
            $firstComment = @($thread.comments.nodes) | Where-Object {
                $_.author -and $_.author.login -match $AuthorPattern
            } | Select-Object -First 1

            [pscustomobject]@{
                id = $thread.id
                path = $thread.path
                line = $thread.line
                isOutdated = $thread.isOutdated
                firstAuthor = $firstComment.author.login
                firstUrl = $firstComment.url
                firstBody = $firstComment.body
                reviewCommitOid = if ($firstComment.pullRequestReview) {
                    $firstComment.pullRequestReview.commit.oid
                } else {
                    $null
                }
            }
        }

    [pscustomobject]@{
        reviewCount = @($reviews).Count
        latestReview = @($reviews) |
            Sort-Object submittedAt -Descending |
            Select-Object -First 1
        prCommentCount = @($comments).Count
        latestPrComment = @($comments) |
            Sort-Object createdAt -Descending |
            Select-Object -First 1
        unresolvedThreadCount = @($threads).Count
        unresolvedThreads = $threads
        latestCheck = $LatestCheck
    }
}

$checksJson = Invoke-Gh -Arguments @(
    'pr', 'view', "$($identity.PullNumber)",
    '--repo', "$($identity.Owner)/$($identity.Name)",
    '--json', 'statusCheckRollup'
)
$checkRollup = @(($checksJson | ConvertFrom-Json).statusCheckRollup)

function Get-LatestCheck {
    param([string] $Pattern)

    @($checkRollup) |
        Where-Object {
            $name = $_.PSObject.Properties['name']
            $context = $_.PSObject.Properties['context']
            $workflowName = $_.PSObject.Properties['workflowName']

            ($name -and $name.Value -match $Pattern) -or
            ($context -and $context.Value -match $Pattern) -or
            ($workflowName -and $workflowName.Value -match $Pattern)
        } |
        Sort-Object {
            $completedAt = $_.PSObject.Properties['completedAt']
            $startedAt = $_.PSObject.Properties['startedAt']
            if ($completedAt -and $completedAt.Value) { $completedAt.Value }
            elseif ($startedAt -and $startedAt.Value) { $startedAt.Value }
            else { '' }
        } -Descending |
        Select-Object -First 1
}

$providerStates = [ordered]@{
    codex = Get-ProviderState `
        -PullRequest $pr `
        -AuthorPattern '(?i)(codex|chatgpt-codex-connector)' `
        -LatestCheck (Get-LatestCheck -Pattern '(?i)codex')
    codeRabbit = Get-ProviderState `
        -PullRequest $pr `
        -AuthorPattern '(?i)coderabbitai' `
        -LatestCheck (Get-LatestCheck -Pattern '(?i)coderabbit')
    macroscope = Get-ProviderState `
        -PullRequest $pr `
        -AuthorPattern '(?i)macroscopeapp' `
        -LatestCheck (Get-LatestCheck -Pattern '(?i)macroscope')
    greptile = Get-ProviderState `
        -PullRequest $pr `
        -AuthorPattern '(?i)greptile(?:ai|-apps)' `
        -LatestCheck (Get-LatestCheck -Pattern '(?i)greptile')
}

[pscustomobject]@{
    repository = "$($identity.Owner)/$($identity.Name)"
    pullNumber = $identity.PullNumber
    url = $pr.url
    title = $pr.title
    state = $pr.state
    isDraft = $pr.isDraft
    headRefOid = $pr.headRefOid
    reviewDecision = $pr.reviewDecision
    mergeStateStatus = $pr.mergeStateStatus
    reviewerReviewCount = @($reviewerReviews).Count
    latestReviewerReview = @($reviewerReviews) | Sort-Object submittedAt -Descending | Select-Object -First 1
    reviewerPrCommentCount = @($reviewerComments).Count
    latestReviewerPrComment = @($reviewerComments) | Sort-Object createdAt -Descending | Select-Object -First 1
    unresolvedReviewerThreadCount = @($threadSummaries).Count
    unresolvedReviewerThreads = $threadSummaries
    reviewers = $providerStates
} | ConvertTo-Json -Depth 20
