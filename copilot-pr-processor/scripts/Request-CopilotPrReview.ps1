[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Url,

    [Parameter(Mandatory = $false)]
    [string] $Repo,

    [Parameter(Mandatory = $false)]
    [int] $PullNumber,

    [Parameter(Mandatory = $false)]
    [string] $ReviewerLogin = 'copilot-pull-request-reviewer',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Bot', 'User')]
    [string] $ReviewerKind = 'Bot',

    [Parameter(Mandatory = $false)]
    [switch] $DryRun,

    [Parameter(Mandatory = $false)]
    [switch] $SkipRestFallback
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
        method = "graphql requestReviewsByLogin $ReviewerKind"
        reviewer = $ReviewerLogin
        url = $pr.url
        headRefOid = $pr.headRefOid
    } | ConvertTo-Json -Depth 5
    exit 0
}

if ($ReviewerKind -eq 'Bot') {
    $mutation = @"
mutation(`$pullRequestId: ID!, `$login: String!) {
  requestReviewsByLogin(input: {pullRequestId: `$pullRequestId, botLogins: [`$login], union: true}) {
    pullRequest {
      url
      headRefOid
    }
  }
}
"@
} else {
    $mutation = @"
mutation(`$pullRequestId: ID!, `$login: String!) {
  requestReviewsByLogin(input: {pullRequestId: `$pullRequestId, userLogins: [`$login], union: true}) {
    pullRequest {
      url
      headRefOid
    }
  }
}
"@
}

try {
    $result = Invoke-Gh -Arguments @(
        'api', 'graphql',
        '-f', "query=$mutation",
        '-F', "pullRequestId=$($pr.id)",
        '-F', "login=$ReviewerLogin"
    )

    $parsed = $result | ConvertFrom-Json
    [pscustomobject]@{
        requested = $true
        method = "graphql requestReviewsByLogin $ReviewerKind"
        reviewer = $ReviewerLogin
        url = $parsed.data.requestReviewsByLogin.pullRequest.url
        headRefOid = $parsed.data.requestReviewsByLogin.pullRequest.headRefOid
    } | ConvertTo-Json -Depth 5
    exit 0
} catch {
    $graphQlError = $_.Exception.Message

    if ($SkipRestFallback) {
        throw
    }

    $restResult = Invoke-Gh -Arguments @(
        'api',
        '-X', 'POST',
        "repos/$($identity.Owner)/$($identity.Name)/pulls/$($identity.PullNumber)/requested_reviewers",
        '-f', "reviewers[]=$ReviewerLogin"
    )

    [pscustomobject]@{
        requested = $true
        method = 'rest requested_reviewers fallback'
        reviewer = $ReviewerLogin
        graphQlError = $graphQlError
        response = ($restResult | ConvertFrom-Json)
    } | ConvertTo-Json -Depth 20
}
