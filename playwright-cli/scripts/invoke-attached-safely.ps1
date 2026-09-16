[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Session,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z][a-z0-9-]*$')]
    [string]$Command,

    [string[]]$CommandArguments = @(),

    [ValidateRange(500, 50000)]
    [int]$MaxOutputCharacters = 8000,

    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$cli = Join-Path $env:APPDATA 'npm\playwright-cli.cmd'
if (-not (Test-Path -LiteralPath $cli)) {
    $resolved = Get-Command playwright-cli -ErrorAction Stop
    $cli = $resolved.Source
}

$outputDirectory = Join-Path $env:TEMP (
    'playwright-attached-command-' + [Guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $outputDirectory | Out-Null

$priorOutputDirectory = $env:PLAYWRIGHT_MCP_OUTPUT_DIR

try {
    $env:PLAYWRIGHT_MCP_OUTPUT_DIR = $outputDirectory
    $arguments = @("-s=$Session", '--raw', $Command) + $CommandArguments
    $output = (& $cli @arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE

    $sanitized = $output
    foreach ($scope in @('Process', 'User', 'Machine')) {
        $token = [Environment]::GetEnvironmentVariable(
            'PLAYWRIGHT_MCP_EXTENSION_TOKEN',
            $scope
        )
        if (-not [string]::IsNullOrWhiteSpace($token)) {
            $sanitized = $sanitized.Replace($token, '<REDACTED>')
        }
    }

    $connectionPattern = (
        'chrome-extension://mmlmfjhmonkocbjadbfplnigmagldckm/' +
        'connect\.html\?[^\s\)\]\}\"'']+'
    )
    $sanitized = [Regex]::Replace(
        $sanitized,
        $connectionPattern,
        'chrome-extension://mmlmfjhmonkocbjadbfplnigmagldckm/connect.html?<REDACTED>',
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $sanitized = [Regex]::Replace(
        $sanitized,
        '(?i)(token(?:=|%3D))[^&\s\)\]\}\"'']+',
        '$1<REDACTED>'
    )

    if ($sanitized.Length -gt $MaxOutputCharacters) {
        $sanitized = (
            $sanitized.Substring(0, $MaxOutputCharacters) +
            "`n<TRUNCATED BY invoke-attached-safely.ps1>"
        )
    }

    if ($exitCode -ne 0) {
        throw "Playwright command '$Command' failed with exit code $exitCode.`n$sanitized"
    }

    if (-not $Quiet -and -not [string]::IsNullOrWhiteSpace($sanitized)) {
        Write-Output $sanitized.TrimEnd()
    }
}
finally {
    $env:PLAYWRIGHT_MCP_OUTPUT_DIR = $priorOutputDirectory
    Remove-Item -LiteralPath $outputDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
