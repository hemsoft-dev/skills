<#
.SYNOPSIS
    List unread Outlook messages.
.DESCRIPTION
    Child script for personal Outlook/Hotmail account. Called by parent mail-unread.ps1.
.PARAMETER Count
    Number of messages to return (default: 10, max: 50).
#>
param(
    [int]$Count = 10
)

$ErrorActionPreference = 'Stop'
$Count = [Math]::Clamp($Count, 1, 50)

$LibPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib'
. (Join-Path $LibPath 'outlook-auth.ps1')

if (-not (Test-OutlookConfigured)) {
    return @{ configured = $false; count = 0; messages = @() }
}

try {
    $accessToken = Get-OutlookAccessToken
    if (-not $accessToken) {
        return @{ configured = $false; count = 0; messages = @() }
    }

    $stats = Get-OutlookInboxStatistic -AccessToken $accessToken
    $messages = @(Get-OutlookInboxMessage -AccessToken $accessToken -Count $Count -Filter "isRead eq false")

    return @{
        configured = $true
        count      = $stats.unreadItemCount
        messages   = $messages
    }
}
catch {
    Write-Error "Outlook error: $_"
    return @{ configured = $true; count = 0; messages = @(); error = $_.Exception.Message }
}
