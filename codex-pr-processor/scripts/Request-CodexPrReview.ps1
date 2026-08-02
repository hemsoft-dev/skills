[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Url,

    [Parameter(Mandatory = $false)]
    [string] $Repo,

    [Parameter(Mandatory = $false)]
    [int] $PullNumber,

    [Parameter(Mandatory = $false)]
    [switch] $SkipCodeRabbit,

    [Parameter(Mandatory = $false)]
    [switch] $SkipMacroscope,

    [Parameter(Mandatory = $false)]
    [switch] $IncludeGreptile,

    [Parameter(Mandatory = $false)]
    [switch] $GreptileReady,

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

$script:Gh = (Get-Command gh -CommandType Application -ErrorAction Stop).Source
$identity = Resolve-PrIdentity -InputUrl $Url -InputRepo $Repo -InputPullNumber $PullNumber

$prJson = Invoke-Gh -Arguments @(
    'pr', 'view', "$($identity.PullNumber)",
    '--repo', "$($identity.Owner)/$($identity.Name)",
    '--json', 'url,headRefOid'
)
$pr = $prJson | ConvertFrom-Json

if ($IncludeGreptile -and -not $GreptileReady) {
    throw 'Greptile was requested, but -GreptileReady was not supplied. Verify the repository is enabled and indexed before consuming review quota.'
}

$reviewComments = @('@codex review')
if (-not $SkipCodeRabbit) {
    $reviewComments += '@coderabbitai review'
}
if (-not $SkipMacroscope) {
    $reviewComments += '@Macroscope-App review'
}
if ($IncludeGreptile) {
    $reviewComments += '@greptileai'
}

if ($DryRun) {
    [pscustomobject]@{
        requested = $false
        dryRun = $true
        url = $pr.url
        headRefOid = $pr.headRefOid
        greptileReady = [bool] $GreptileReady
        comments = $reviewComments
    } | ConvertTo-Json -Depth 5
    exit 0
}

$posted = foreach ($comment in $reviewComments) {
    $url = Invoke-Gh -Arguments @(
        'pr', 'comment', "$($identity.PullNumber)",
        '--repo', "$($identity.Owner)/$($identity.Name)",
        '--body', $comment
    )

    [pscustomobject]@{
        body = $comment
        url = $url
    }
}

[pscustomobject]@{
    requested = $true
    method = 'pull request trigger comments'
    url = $pr.url
    headRefOid = $pr.headRefOid
    comments = $posted
} | ConvertTo-Json -Depth 10
