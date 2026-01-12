<#
.SYNOPSIS
    List recent Gmail messages (regardless of read status).
.DESCRIPTION
    Child script for Gmail account. Called by parent mail-recent.ps1.
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

# Load Gmail authentication library
$LibPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib'
. (Join-Path $LibPath 'gmail-auth.ps1')

# Check configuration
if (-not (Test-GmailConfigured)) {
    return @{ configured = $false; count = 0; total = 0; messages = @() }
}

try {
    $accessToken = Get-GmailAccessToken
    if (-not $accessToken) {
        return @{ configured = $false; count = 0; total = 0; messages = @() }
    }

    # Build query
    $query = "in:inbox"
    if ($Days -ge 0) {
        $targetDate = (Get-Date).AddDays(-$Days).ToString("yyyy/MM/dd")
        if ($Days -eq 0) {
            $query += " after:$targetDate"
        } else {
            $nextDay = (Get-Date).AddDays(-$Days + 1).ToString("yyyy/MM/dd")
            $query += " after:$targetDate before:$nextDay"
        }
    }

    # List messages
    $listParams = "q=$([System.Web.HttpUtility]::UrlEncode($query))&maxResults=$Count"
    $response = Invoke-GmailApi -AccessToken $accessToken -Uri "/users/me/messages?$listParams"
    
    $messages = @()
    $totalCount = $response.resultSizeEstimate ?? 0
    
    foreach ($msg in $response.messages) {
        $details = Get-GmailMessage -AccessToken $accessToken -MessageId $msg.id -Format 'metadata'
        
        $from = Get-GmailHeader -Message $details -HeaderName 'From'
        $subject = Get-GmailHeader -Message $details -HeaderName 'Subject'
        $dateStr = Get-GmailHeader -Message $details -HeaderName 'Date'
        $internalDate = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$details.internalDate).LocalDateTime.ToString("MM/dd/yyyy HH:mm")
        
        $status = if ($details.labelIds -contains 'UNREAD') { 'NEW' } else { 'Read' }
        
        $messages += @{
            id      = $msg.id
            status  = $status
            from    = $from ?? 'Unknown'
            subject = $subject ?? '(No subject)'
            date    = $internalDate
        }
    }
    
    return @{
        configured = $true
        count      = $messages.Count
        total      = $totalCount
        messages   = $messages
    }
}
catch {
    Write-Error "Gmail error: $_"
    return @{ configured = $true; count = 0; total = 0; messages = @(); error = $_.Exception.Message }
}
