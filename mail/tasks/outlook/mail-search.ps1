<#
.SYNOPSIS
    Search Outlook messages by keyword.
.DESCRIPTION
    Child script for personal Outlook/Hotmail account. Called by parent mail-search.ps1.
.PARAMETER Query
    Search query string.
.PARAMETER Count
    Number of messages to return (default: 10, max: 50).
#>
param(
    [string]$Query,
    [int]$Count = 10
)

$ErrorActionPreference = 'Stop'
$Count = [Math]::Clamp($Count, 1, 50)

$LibPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib'
. (Join-Path $LibPath 'outlook-auth.ps1')

if (-not (Test-OutlookConfigured)) {
    return @{ configured = $false; count = 0; messages = @() }
}

if (-not $Query) {
    return @{ configured = $true; count = 0; messages = @(); error = "Query parameter required" }
}

try {
    $accessToken = Get-OutlookAccessToken
    if (-not $accessToken) {
        return @{ configured = $false; count = 0; messages = @() }
    }

    $messages = @(Get-OutlookInboxMessage -AccessToken $accessToken -Count $Count -Search $Query)

    return @{
        configured = $true
        count      = $messages.Count
        messages   = $messages
    }
}
catch {
    Write-Error "Outlook search error: $_"
    return @{ configured = $true; count = 0; messages = @(); error = $_.Exception.Message }
}
