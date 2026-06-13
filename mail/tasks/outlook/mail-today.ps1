<#
.SYNOPSIS
    List today's Outlook messages.
.DESCRIPTION
    Child script for personal Outlook/Hotmail account. Called by parent mail-today.ps1.
.PARAMETER Count
    Number of messages to return (default: 10, max: 50).
.PARAMETER List
    If present, returns message list. Otherwise returns counts only.
#>
param(
    [int]$Count = 10,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$Count = [Math]::Clamp($Count, 1, 50)

$LibPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib'
. (Join-Path $LibPath 'outlook-auth.ps1')

if (-not (Test-OutlookConfigured)) {
    return @{ configured = $false; today = 0; unread = 0; messages = @() }
}

try {
    $accessToken = Get-OutlookAccessToken
    if (-not $accessToken) {
        return @{ configured = $false; today = 0; unread = 0; messages = @() }
    }

    $start = (Get-Date).Date.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $todayFilter = "receivedDateTime ge $start"

    $todayCount = Get-OutlookMessageCount -AccessToken $accessToken -Filter $todayFilter
    $stats = Get-OutlookInboxStatistic -AccessToken $accessToken
    $messages = if ($List -and $todayCount -gt 0) {
        @(Get-OutlookInboxMessage -AccessToken $accessToken -Count $Count -Filter $todayFilter)
    }
    else {
        @()
    }

    return @{
        configured = $true
        today      = $todayCount
        unread     = $stats.unreadItemCount
        messages   = $messages
    }
}
catch {
    Write-Error "Outlook error: $_"
    return @{ configured = $true; today = 0; unread = 0; messages = @(); error = $_.Exception.Message }
}
