[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Url,

    [Parameter(Mandatory = $false)]
    [string] $Repo,

    [Parameter(Mandatory = $false)]
    [int] $PullNumber,

    [Parameter(Mandatory = $false)]
    [string] $ReviewerLogin = 'copilot-pull-request-reviewer[bot]',

    [Parameter(Mandatory = $false)]
    [switch] $DryRun
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
      headRefOid
    }
  }
}
'@

$prJson = Invoke-Gh -Arguments @(
    'api', 'graphql',
    '-f', "query=$query",
    '-F', "owner=$($identity.Owner)",
    '-F', "name=$($identity.Name)",
    '-F', "number=$($identity.PullNumber)"
)

$prData = $prJson | ConvertFrom-Json
$pr = $prData.data.repository.pullRequest
if (-not $pr) {
    throw "PR not found: $($identity.Owner)/$($identity.Name)#$($identity.PullNumber)"
}

if ($DryRun) {
    [pscustomobject]@{
        requested = $false
        dryRun = $true
        method = 'rest requested_reviewers'
        reviewer = $ReviewerLogin
        url = $pr.url
        headRefOid = $pr.headRefOid
    } | ConvertTo-Json -Depth 5
    exit 0
}

$restResult = Invoke-Gh -Arguments @(
    'api',
    '-X', 'POST',
    "repos/$($identity.Owner)/$($identity.Name)/pulls/$($identity.PullNumber)/requested_reviewers",
    '-f', "reviewers[]=$ReviewerLogin"
)

$response = $restResult | ConvertFrom-Json
$requestedReviewers = @($response.requested_reviewers)
$requestVisible = $requestedReviewers.login -contains $ReviewerLogin

[pscustomobject]@{
    requested = $requestVisible
    accepted = $true
    method = 'rest requested_reviewers'
    reviewer = $ReviewerLogin
    url = $pr.url
    headRefOid = $pr.headRefOid
    visibleRequestedReviewers = @($requestedReviewers.login)
    warning = if ($requestVisible) {
        $null
    } else {
        'GitHub accepted the API call but did not add Copilot to requested_reviewers. Treat Copilot review as unavailable until a review appears.'
    }
} | ConvertTo-Json -Depth 10

if (-not $requestVisible) {
    exit 2
}
