<#
.SYNOPSIS
    Daily Outlook summary with today's count and sample messages.
.DESCRIPTION
    Child script for personal Outlook/Hotmail account. Called by parent mail-summary.ps1.
#>
param()

$ErrorActionPreference = 'Stop'

$LibPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib'
. (Join-Path $LibPath 'outlook-auth.ps1')

if (-not (Test-OutlookConfigured)) {
    return @{ configured = $false; today = 0; unread = 0; total = 0; highlights = @() }
}

try {
    $accessToken = Get-OutlookAccessToken
    if (-not $accessToken) {
        return @{ configured = $false; today = 0; unread = 0; total = 0; highlights = @() }
    }

    $start = (Get-Date).Date.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $todayFilter = "receivedDateTime ge $start"
    $unreadFilter = "isRead eq false"

    $stats = Get-OutlookInboxStatistic -AccessToken $accessToken
    $todayCount = Get-OutlookMessageCount -AccessToken $accessToken -Filter $todayFilter
    $unreadCount = $stats.unreadItemCount
    $highlights = if ($unreadCount -gt 0) {
        @(Get-OutlookInboxMessage -AccessToken $accessToken -Count 3 -Filter $unreadFilter)
    }
    elseif ($todayCount -gt 0) {
        @(Get-OutlookInboxMessage -AccessToken $accessToken -Count 3 -Filter $todayFilter)
    }
    else {
        @()
    }

    return @{
        configured = $true
        today      = $todayCount
        unread     = $unreadCount
        total      = $stats.totalItemCount
        highlights = $highlights
    }
}
catch {
    Write-Error "Outlook summary error: $_"
    return @{ configured = $true; today = 0; unread = 0; total = 0; highlights = @(); error = $_.Exception.Message }
}
