#Requires -Version 7.0
<#
.SYNOPSIS
    Compatibility wrapper for the faster no-premium org collector path.
#>

[CmdletBinding()]
param(
    [datetime]$Since = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0),

    [datetime]$Until = (Get-Date),

    [string]$OutputPath,

    [ValidateRange(1, 10000)]
    [int]$UserLimit = 0,

    [ValidateRange(1, 10000)]
    [int]$RepoLimit = 0,

    [switch]$IncludePremiumRequests
)

$scriptPath = Join-Path $PSScriptRoot 'Get-OrgUserProductivity.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Could not find unified script at '$scriptPath'."
}

$arguments = @{
    Since = $Since
    Until = $Until
    UserLimit = $UserLimit
    RepoLimit = $RepoLimit
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $arguments.OutputPath = $OutputPath
}

if (-not $IncludePremiumRequests) {
    $arguments.SkipPremiumRequests = $true
}

& $scriptPath @arguments