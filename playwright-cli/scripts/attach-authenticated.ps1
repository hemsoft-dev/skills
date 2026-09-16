[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Url,

    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Session = 'authenticated',

    [ValidateSet('chrome', 'msedge')]
    [string]$Channel = 'chrome'
)

$ErrorActionPreference = 'Stop'

$target = $null
if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$target) -or
    $target.Scheme -notin @('https', 'http')) {
    throw 'Url must be an absolute HTTP or HTTPS URL.'
}

$token = [Environment]::GetEnvironmentVariable(
    'PLAYWRIGHT_MCP_EXTENSION_TOKEN',
    'Process'
)
if ([string]::IsNullOrWhiteSpace($token)) {
    $token = [Environment]::GetEnvironmentVariable(
        'PLAYWRIGHT_MCP_EXTENSION_TOKEN',
        'User'
    )
}
if ([string]::IsNullOrWhiteSpace($token)) {
    $token = [Environment]::GetEnvironmentVariable(
        'PLAYWRIGHT_MCP_EXTENSION_TOKEN',
        'Machine'
    )
}
if ([string]::IsNullOrWhiteSpace($token)) {
    throw 'PLAYWRIGHT_MCP_EXTENSION_TOKEN is unavailable.'
}

$cli = Join-Path $env:APPDATA 'npm\playwright-cli.cmd'
if (-not (Test-Path -LiteralPath $cli)) {
    $command = Get-Command playwright-cli -ErrorAction Stop
    $cli = $command.Source
}

$outputDirectory = Join-Path $env:TEMP (
    'playwright-auth-attach-' + [Guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $outputDirectory | Out-Null

$priorToken = $env:PLAYWRIGHT_MCP_EXTENSION_TOKEN
$priorOutputDirectory = $env:PLAYWRIGHT_MCP_OUTPUT_DIR
$attached = $false

try {
    $env:PLAYWRIGHT_MCP_EXTENSION_TOKEN = $token
    $env:PLAYWRIGHT_MCP_OUTPUT_DIR = $outputDirectory

    $null = & $cli "-s=$Session" attach "--extension=$Channel" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Playwright extension attachment failed with exit code $LASTEXITCODE."
    }
    $attached = $true

    # The raw attach result includes the token-bearing chrome-extension URL.
    # Open the authorized target without returning either attach output or the
    # browser's existing tab inventory to the caller.
    $null = & $cli "-s=$Session" tab-new $target.AbsoluteUri 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Playwright could not open the authorized target with exit code $LASTEXITCODE."
    }

    [pscustomobject]@{
        Session = $Session
        Channel = $Channel
        Attached = $true
        TargetOrigin = $target.GetLeftPart([UriPartial]::Authority)
        RawAttachOutputSuppressed = $true
        TemporaryArtifactsRemoved = $true
    } | ConvertTo-Json -Compress
}
catch {
    if ($attached) {
        $null = & $cli "-s=$Session" detach 2>&1
    }
    throw
}
finally {
    $token = $null
    $env:PLAYWRIGHT_MCP_EXTENSION_TOKEN = $priorToken
    $env:PLAYWRIGHT_MCP_OUTPUT_DIR = $priorOutputDirectory
    Remove-Item -LiteralPath $outputDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
