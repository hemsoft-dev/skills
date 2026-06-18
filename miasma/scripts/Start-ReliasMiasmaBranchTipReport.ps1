[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter()]
    [string]$Owner = 'relias-engineering',

    [Parameter()]
    [string]$ExpectedLogin = 'fhemmerrelias',

    [Parameter()]
    [ValidateRange(0, 5000)]
    [int]$ThrottleMilliseconds = 2000,

    [Parameter()]
    [ValidateRange(0, 5000)]
    [int]$RepositoryLimit = 0,

    [Parameter()]
    [string[]]$RepositoryName = @(),

    [Parameter()]
    [string]$RepositoryNamePath,

    [Parameter()]
    [string]$OutputDirectory,

    [Parameter()]
    [ValidateRange(0, 5000)]
    [int]$MinimumCoreRemaining = 500,

    [Parameter()]
    [ValidateRange(0, 50000)]
    [int]$MinimumGraphqlRemaining = 500,

    [Parameter()]
    [switch]$Background,

    [Parameter()]
    [switch]$PreflightOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
$runnerPath = Join-Path $scriptRoot 'Invoke-MiasmaRemoteAudit.ps1'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required.'
}
if (-not (Test-Path -LiteralPath $runnerPath)) {
    throw "Runner not found: $runnerPath"
}

Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue

$login = (& gh api user --jq .login 2>$null)
if ($LASTEXITCODE -ne 0 -or $login -ne $ExpectedLogin) {
    throw "gh must be authenticated as $ExpectedLogin. Current login: $login"
}

$probe = & gh api "repos/$Owner/supernurse-backend/branches?per_page=1" 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Unable to read $Owner/supernurse-backend branches with current gh auth: $($probe -join ' ')"
}

$rate = (& gh api rate_limit | ConvertFrom-Json)
$coreRemaining = [int]$rate.resources.core.remaining
$graphqlRemaining = [int]$rate.resources.graphql.remaining
if ($coreRemaining -lt $MinimumCoreRemaining) {
    throw "Core REST rate limit too low: $coreRemaining remaining; required $MinimumCoreRemaining."
}
if ($graphqlRemaining -lt $MinimumGraphqlRemaining) {
    throw "GraphQL rate limit too low: $graphqlRemaining remaining; required $MinimumGraphqlRemaining."
}

if (-not $OutputDirectory) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputDirectory = Join-Path $skillRoot "output\remote\$Owner\$stamp-graphql-branchtip"
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$stdoutPath = Join-Path $OutputDirectory 'run-stdout.txt'
$stderrPath = Join-Path $OutputDirectory 'run-stderr.txt'
$scanTextPath = Join-Path $OutputDirectory 'miasma-remote-scan.txt'
$jsonPath = Join-Path $OutputDirectory 'miasma-remote-scan.json'
$htmlPath = Join-Path $OutputDirectory 'miasma-remote-audit.html'

$runnerArgs = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $runnerPath,
    '-Owner', $Owner,
    '-ScanMode', 'BranchTip',
    '-Since', '2026-05-01T04:00:00Z',
    '-Until', (Get-Date).ToString('o'),
    '-OutputDirectory', $OutputDirectory,
    '-ThrottleMilliseconds', ([string]$ThrottleMilliseconds)
)
if ($RepositoryLimit -gt 0) {
    $runnerArgs += @('-RepositoryLimit', ([string]$RepositoryLimit))
}
if ($RepositoryName.Count -gt 0) {
    $runnerArgs += '-RepositoryName'
    $runnerArgs += $RepositoryName
}
if ($RepositoryNamePath) {
    $runnerArgs += @('-RepositoryNamePath', $RepositoryNamePath)
}

$preflight = [pscustomobject]@{
    Owner = $Owner
    Login = $login
    ThrottleMilliseconds = $ThrottleMilliseconds
    CoreRemaining = $coreRemaining
    GraphqlRemaining = $graphqlRemaining
    OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
    ScanTextPath = $scanTextPath
    JsonPath = $jsonPath
    HtmlPath = $htmlPath
    Runner = $runnerPath
}

if ($PreflightOnly) {
    return $preflight
}

if ($Background) {
    $process = Start-Process -FilePath 'pwsh' -ArgumentList $runnerArgs -WorkingDirectory $skillRoot -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru

    return [pscustomobject]@{
        ProcessId = $process.Id
        Owner = $Owner
        Login = $login
        ThrottleMilliseconds = $ThrottleMilliseconds
        OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
        StdoutPath = $stdoutPath
        StderrPath = $stderrPath
        ScanTextPath = $scanTextPath
        JsonPath = $jsonPath
        HtmlPath = $htmlPath
        MonitorCommand = "Get-Content -LiteralPath '$scanTextPath' -Tail 40 -Wait"
    }
}

& pwsh @runnerArgs 2>$stderrPath | Tee-Object -FilePath $stdoutPath
if ($LASTEXITCODE -ne 0) {
    throw "Miasma BranchTip report failed. See $stderrPath"
}

if (Test-Path -LiteralPath $jsonPath) {
    $scan = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    return [pscustomobject]@{
        Owner = $Owner
        Login = $login
        ThrottleMilliseconds = $ThrottleMilliseconds
        OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
        RepositoriesScanned = $scan.RepositoriesScanned
        RepositoriesWithAnyIndicator = $scan.RepositoriesWithAnyIndicator
        RepositoriesWithSetupJs = $scan.RepositoriesWithSetupJs
        Errors = @($scan.Errors).Count
        JsonPath = $jsonPath
        HtmlPath = $htmlPath
    }
}

throw "Expected JSON artifact was not created: $jsonPath"
