[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Get-Location) 'bitbucket-audit-report.csv'),
    [string]$Workspace = $(if ($env:BITBUCKET_WORKSPACE) { $env:BITBUCKET_WORKSPACE } else { 'relias' }),
    [string]$GitHubOwner = $(if ($env:GITHUB_OWNER) { $env:GITHUB_OWNER } else { 'relias-engineering' }),
    [string[]]$RepoPattern = @('*'),
    [int]$MaxRepos = 0,
    [int]$StaleWarningDays = 180,
    [int]$StaleCriticalDays = 365,
    [switch]$OpenInExcel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$invokeScript = Join-Path $PSScriptRoot 'Invoke-BitbucketMigrationAudit.ps1'
if (-not (Test-Path $invokeScript)) {
    throw "Required script not found: $invokeScript"
}

$columnOrder = @(
    'BitbucketRepo',
    'BitbucketName',
    'BitbucketProject',
    'BitbucketArchived',
    'BitbucketDefaultBranch',
    'BitbucketCommitLookupStatus',
    'BitbucketCommitLookupError',
    'BitbucketLastCommitAt',
    'BitbucketLastCommitAgeDays',
    'BitbucketStaleness',
    'BitbucketUpdatedOn',
    'BitbucketUrl',
    'GitHubRepoFound',
    'GitHubRepo',
    'GitHubArchived',
    'GitHubDefaultBranch',
    'GitHubPushedAt',
    'GitHubLastPushAgeDays',
    'GitHubUrl',
    'MigrationStatus'
)

$results = & $invokeScript `
    -Workspace $Workspace `
    -GitHubOwner $GitHubOwner `
    -RepoPattern $RepoPattern `
    -MaxRepos $MaxRepos `
    -StaleWarningDays $StaleWarningDays `
    -StaleCriticalDays $StaleCriticalDays

$orderedResults = @($results | Select-Object $columnOrder)

$parent = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

$orderedResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "Wrote exact-format audit report to $OutputPath"

if ($OpenInExcel.IsPresent) {
    try {
        $excel = $null
        try { $excel = [Runtime.InteropServices.Marshal]::GetActiveObject('Excel.Application') } catch {}
        if ($null -eq $excel) { $excel = New-Object -ComObject Excel.Application }
        $excel.Visible = $true
        $null = $excel.Workbooks.Open((Resolve-Path $OutputPath).Path)
        try { $excel.WindowState = -4137 } catch {}
    }
    catch {
        Write-Warning "Excel could not be opened automatically: $($_.Exception.Message)"
    }
}

$orderedResults
