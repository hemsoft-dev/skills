[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$bootstrapPath = Join-Path $PSScriptRoot 'prepare-mini-host.sh'
$bootstrap = Get-Content -Raw -LiteralPath $bootstrapPath
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($bootstrap))
$remoteCommand = "printf '%s' '$encoded' | base64 -d | sudo bash"

Write-Host 'Connecting to mini. Enter the sudo password when prompted.' -ForegroundColor Cyan
& ssh -tt mini $remoteCommand

if ($LASTEXITCODE -ne 0) {
    Write-Error "mini host preparation failed with SSH exit code $LASTEXITCODE."
}

Write-Host 'mini host preparation command finished.' -ForegroundColor Green
Read-Host 'Press Enter to close this window'
