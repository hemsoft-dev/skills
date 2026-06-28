[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Url,

    [Parameter(Mandatory = $false)]
    [string] $Repo,

    [Parameter(Mandatory = $false)]
    [int] $PullNumber,

    [Parameter(Mandatory = $false)]
    [string] $ReviewerAuthorPattern = '(?i)(codex|chatgpt-codex-connector|coderabbitai|macroscopeapp)'
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

$script:Gh = (Get-Command gh.exe).Source
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
} | ConvertTo-Json -Depth 20
