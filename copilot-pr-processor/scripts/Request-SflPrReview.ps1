[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Url,

    [Parameter(Mandatory = $false)]
    [string] $Repo,

    [Parameter(Mandatory = $false)]
    [int] $PullNumber,

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

$workflowRuns = $null
if ($workflowExists -and $requestMode -eq 'legacy_label') {
    $encodedHeadRef = [uri]::EscapeDataString([string] $pr.head.ref)
    $workflowRuns = Get-GhEndpoint -Endpoint (
        "repos/$repository/actions/workflows/sfl-pr-review.lock.yml/runs" +
        "?branch=$encodedHeadRef&event=pull_request&per_page=100"
    )
}

$activeSflRuns = if ($workflowRuns) {
    @($workflowRuns.workflow_runs) | Where-Object {
        $_.head_sha -eq $pr.head.sha -and $_.status -ne 'completed'
    }
} else {
    @()
}

$hasWritePermission = [bool] (
    $repoData.permissions.admin -or
    $repoData.permissions.maintain -or
    $repoData.permissions.push
)

$labelAlreadyPresent = @($pr.labels) |
    Where-Object name -eq 'sfl-review' |
    Select-Object -First 1

$result = [ordered]@{
    requested = $false
    dryRun = [bool] $DryRun
    repository = $repository
    pullNumber = $identity.PullNumber
    url = $pr.html_url
    headRefOid = $pr.head.sha
    workflowExists = $workflowExists
    workflowState = $workflowState
    triggerLabelExists = $labelExists
    dispatchSupported = $dispatchSupported
    requestMode = $requestMode
    hasWritePermission = $hasWritePermission
    labelAlreadyPresent = [bool] $labelAlreadyPresent
    activeSflRunCount = @($activeSflRuns).Count
}

if (-not $workflowActive -or -not $requestMode) {
    $result.reason = 'SFL reviewer is unavailable: no active workflow-dispatch reviewer or legacy trigger label exists on the default branch.'
    [pscustomobject] $result | ConvertTo-Json -Depth 5
    exit 2
}

if ($pr.state -ne 'open') {
    $result.reason = "Pull request state is '$($pr.state)'; SFL reviews can only be requested for open pull requests."
    [pscustomobject] $result | ConvertTo-Json -Depth 5
    exit 5
}

if (-not $hasWritePermission) {
    $result.reason = 'The authenticated GitHub user lacks write, maintain, or admin permission required by the SFL activation gate.'
    [pscustomobject] $result | ConvertTo-Json -Depth 5
    exit 3
}

if ($requestMode -eq 'legacy_label' -and $labelAlreadyPresent) {
    $result.reason = 'The sfl-review label is already present. Inspect the workflow run or authorization failure before retrying.'
    [pscustomobject] $result | ConvertTo-Json -Depth 5
    exit 4
}

if ($requestMode -eq 'legacy_label' -and @($activeSflRuns).Count -gt 0) {
    $result.reason = 'An SFL review workflow is already active for the current head.'
    [pscustomobject] $result | ConvertTo-Json -Depth 5
    exit 6
}

if ($DryRun) {
    $result.reason = if ($requestMode -eq 'workflow_dispatch') {
        "Dry run succeeded. Dispatching the reviewer on base branch '$($pr.base.ref)' would review PR #$($identity.PullNumber)."
    } else {
        'Dry run succeeded. Applying sfl-review would trigger the legacy full-spectrum reviewer.'
    }
    [pscustomobject] $result | ConvertTo-Json -Depth 5
    exit 0
}

if ($requestMode -eq 'workflow_dispatch') {
    $awContext = [ordered]@{
        item_type = 'pull_request'
        item_number = $identity.PullNumber
    } | ConvertTo-Json -Compress

    Invoke-Gh -Arguments @(
        'workflow', 'run', 'sfl-pr-review.lock.yml',
        '--repo', $repository,
        '--ref', [string] $pr.base.ref,
        '-f', "item_number=$($identity.PullNumber)",
        '-f', "aw_context=$awContext"
    ) | Out-Null

    $result.requested = $true
    $result.reason = "Dispatched sfl-pr-review.lock.yml on base branch '$($pr.base.ref)' for PR #$($identity.PullNumber)."
} else {
    Invoke-Gh -Arguments @(
        'api',
        '-X', 'POST',
        "repos/$repository/issues/$($identity.PullNumber)/labels",
        '-f', 'labels[]=sfl-review'
    ) | Out-Null

    $result.requested = $true
    $result.reason = 'Applied the legacy sfl-review trigger label.'
}

[pscustomobject] $result | ConvertTo-Json -Depth 5
