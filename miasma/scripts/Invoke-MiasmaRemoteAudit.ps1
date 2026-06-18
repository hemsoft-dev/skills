[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter()]
    [string]$Owner = 'relias-engineering',

    [Parameter()]
    [ValidateSet('', 'public', 'private', 'internal')]
    [string]$Visibility = '',

    [Parameter()]
    [datetime]$Since = (Get-Date -Year (Get-Date).Year -Month 5 -Day 1 -Hour 0 -Minute 0 -Second 0),

    [Parameter()]
    [datetime]$Until = (Get-Date),

    [Parameter()]
    [ValidateSet('BranchTip', 'CommitWindow', 'Both')]
    [string]$ScanMode = 'BranchTip',

    [Parameter()]
    [string]$OutputRoot,

    [Parameter()]
    [string]$OutputDirectory,

    [Parameter()]
    [string[]]$RepositoryName = @(),

    [Parameter()]
    [string]$RepositoryNamePath,

    [Parameter()]
    [ValidateRange(0, 5000)]
    [int]$RepositoryLimit = 0,

    [Parameter()]
    [ValidateRange(0, 5000)]
    [int]$ThrottleMilliseconds = 250,

    [Parameter()]
    [string]$UseExistingJsonPath,

    [Parameter()]
    [string]$UseExistingTextPath,

    [Parameter()]
    [string]$ReportTitle = 'High-signal persistence indicators found across active branch trees'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $skillRoot 'output\remote'
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $OutputRoot "$Owner\$stamp"
}
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$jsonPath = Join-Path $OutputDirectory 'miasma-remote-scan.json'
$textPath = Join-Path $OutputDirectory 'miasma-remote-scan.txt'
$htmlPath = Join-Path $OutputDirectory 'miasma-remote-audit.html'
$scannerPath = Join-Path $scriptRoot 'Scan-GitHubMiasmaRemote.ps1'
$builderPath = Join-Path $scriptRoot 'Build-MiasmaRemoteReport.ps1'

if ($UseExistingJsonPath) {
    if (-not (Test-Path -LiteralPath $UseExistingJsonPath)) {
        throw "Existing JSON path not found: $UseExistingJsonPath"
    }
    Copy-Item -LiteralPath $UseExistingJsonPath -Destination $jsonPath -Force
    if ($UseExistingTextPath) {
        if (-not (Test-Path -LiteralPath $UseExistingTextPath)) {
            throw "Existing text path not found: $UseExistingTextPath"
        }
        Copy-Item -LiteralPath $UseExistingTextPath -Destination $textPath -Force
    }
}
else {
    $scanArgs = @{
        Owner = $Owner
        Visibility = $Visibility
        Since = $Since
        Until = $Until
        ScanMode = $ScanMode
        OutputDirectory = $OutputDirectory
        JsonOutputPath = $jsonPath
        TextOutputPath = $textPath
        RepositoryLimit = $RepositoryLimit
        ThrottleMilliseconds = $ThrottleMilliseconds
    }
    if ($RepositoryName.Count -gt 0) {
        $scanArgs.RepositoryName = $RepositoryName
    }
    if ($RepositoryNamePath) {
        $scanArgs.RepositoryNamePath = $RepositoryNamePath
    }

    & $scannerPath @scanArgs | Tee-Object -FilePath (Join-Path $OutputDirectory 'miasma-remote-scan-console.txt')
}

$report = & $builderPath -JsonPath $jsonPath -HtmlOutputPath $htmlPath -Title $ReportTitle

[pscustomobject]@{
    Owner = $Owner
    ScanMode = if ($UseExistingJsonPath) { 'ExistingJson' } else { $ScanMode }
    OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
    JsonPath = (Resolve-Path -LiteralPath $jsonPath).Path
    TextPath = if (Test-Path -LiteralPath $textPath) { (Resolve-Path -LiteralPath $textPath).Path } else { $null }
    HtmlPath = (Resolve-Path -LiteralPath $htmlPath).Path
    RepositoriesScanned = $report.RepositoriesScanned
    AffectedRepositories = $report.AffectedRepositories
    CriticalRepositories = $report.CriticalRepositories
    FindingBearingCommitTrees = $report.FindingBearingCommitTrees
}
