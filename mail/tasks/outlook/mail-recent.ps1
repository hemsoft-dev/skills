<#
.SYNOPSIS
    List recent Outlook messages (regardless of read status).
.DESCRIPTION
    Child script for personal Outlook/Hotmail account. Called by parent mail-recent.ps1.
.PARAMETER Count
    Number of messages to return (default: 10, max: 50).
.PARAMETER Days
    Filter to emails from N days ago (0=today, 1=yesterday, etc.). If omitted, no date filter.
#>
param(
    [int]$Count = 10,
    [int]$Days = -1
)

$ErrorActionPreference = 'Stop'
$Count = [Math]::Clamp($Count, 1, 50)

$LibPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib'
. (Join-Path $LibPath 'outlook-auth.ps1')

if (-not (Test-OutlookConfigured)) {
    return @{ configured = $false; count = 0; total = 0; messages = @() }
}

try {
    $accessToken = Get-OutlookAccessToken
    if (-not $accessToken) {
        return @{ configured = $false; count = 0; total = 0; messages = @() }
    }

    $filter = $null
    if ($Days -ge 0) {
        $start = (Get-Date).Date.AddDays(-$Days).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $end = (Get-Date).Date.AddDays(-$Days + 1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $filter = "receivedDateTime ge $start and receivedDateTime lt $end"
    }

    $stats = Get-OutlookInboxStatistic -AccessToken $accessToken
    $messages = @(Get-OutlookInboxMessage -AccessToken $accessToken -Count $Count -Filter $filter)
    $total = if ($filter) { Get-OutlookMessageCount -AccessToken $accessToken -Filter $filter } else { $stats.totalItemCount }

    return @{
        configured = $true
        count      = $messages.Count
        total      = $total
        messages   = $messages
    }
}
catch {
    Write-Error "Outlook error: $_"
    return @{ configured = $true; count = 0; total = 0; messages = @(); error = $_.Exception.Message }
}
