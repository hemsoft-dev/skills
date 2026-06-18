[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter()]
    [ValidateSet('Table', 'Json', 'Csv')]
    [string]$Format = 'Table',

    [Parameter()]
    [string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Get-GitHubOrgAdmins.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Admin inventory script not found: $scriptPath"
}

$arguments = @{
    Owner = 'relias-engineering'
    Format = $Format
}

if ($OutputPath) {
    $arguments.OutputPath = $OutputPath
}

& $scriptPath @arguments

