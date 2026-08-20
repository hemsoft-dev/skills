<#
.SYNOPSIS
    Changes the processor between DryRun and Live mode.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('DryRun', 'Live')]
    [string]$Mode,

    [switch]$ConfirmLive
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Mode -eq 'Live' -and -not $ConfirmLive) {
    throw 'Live mode requires -ConfirmLive because it can purchase Copilot seats and write to Slack.'
}

$skillRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $skillRoot 'config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$config.Mode = $Mode
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding utf8

Write-Information "Processor mode changed to $Mode."
