<#
.SYNOPSIS
    Runs the GitHub Copilot license processor from a Linux systemd user service.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$credentialsPath = Join-Path $HOME '.config/github-copilot-license-processor/credentials.json'
if (-not (Test-Path -LiteralPath $credentialsPath -PathType Leaf)) {
    throw "Credentials file not found: $credentialsPath"
}

$credentials = Get-Content -LiteralPath $credentialsPath -Raw | ConvertFrom-Json
foreach ($name in @('GH_TOKEN', 'SLACK_TOKEN')) {
    $property = $credentials.PSObject.Properties[$name]
    if (-not $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        throw "Credentials file is missing $name."
    }
}

$env:GH_TOKEN = [string]$credentials.GH_TOKEN
$env:SLACK_TOKEN = [string]$credentials.SLACK_TOKEN
$env:LOCALAPPDATA = Join-Path $HOME '.local/share'

try {
    & (Join-Path $PSScriptRoot 'Invoke-CopilotLicenseProcessor.ps1')
}
finally {
    Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:SLACK_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue
}
