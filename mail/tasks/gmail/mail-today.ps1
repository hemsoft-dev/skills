<#
.SYNOPSIS
    List today's Gmail messages.
.DESCRIPTION
    Child script for Gmail account. Called by parent mail-today.ps1.
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

# Load Gmail authentication library
$LibPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib'
. (Join-Path $LibPath 'gmail-auth.ps1')

# Check configuration
if (-not (Test-GmailConfigured)) {
    return @{ configured = $false; today = 0; unread = 0; messages = @() }
}

try {
    $accessToken = Get-GmailAccessToken
    if (-not $accessToken) {
        return @{ configured = $false; today = 0; unread = 0; messages = @() }
    }

    $today = (Get-Date).ToString("yyyy/MM/dd")
    
    # Count today's messages
    $todayQuery = "in:inbox after:$today"
    $todayParams = "q=$([System.Web.HttpUtility]::UrlEncode($todayQuery))&maxResults=1"
    $todayResponse = Invoke-GmailApi -AccessToken $accessToken -Uri "/users/me/messages?$todayParams"
    $todayCount = $todayResponse.resultSizeEstimate ?? 0
    
    # Count unread messages
    $unreadQuery = "in:inbox is:unread"
    $unreadParams = "q=$([System.Web.HttpUtility]::UrlEncode($unreadQuery))&maxResults=1"
    $unreadResponse = Invoke-GmailApi -AccessToken $accessToken -Uri "/users/me/messages?$unreadParams"
    $unreadCount = $unreadResponse.resultSizeEstimate ?? 0
    
    $messages = @()
    
    if ($List -and $todayCount -gt 0) {
        # Fetch today's messages
        $listParams = "q=$([System.Web.HttpUtility]::UrlEncode($todayQuery))&maxResults=$Count"
        $listResponse = Invoke-GmailApi -AccessToken $accessToken -Uri "/users/me/messages?$listParams"
        
        foreach ($msg in $listResponse.messages) {
            $details = Get-GmailMessage -AccessToken $accessToken -MessageId $msg.id -Format 'metadata'
            
            $from = Get-GmailHeader -Message $details -HeaderName 'From'
            $subject = Get-GmailHeader -Message $details -HeaderName 'Subject'
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
    }
    
    return @{
        configured = $true
        today      = $todayCount
        unread     = $unreadCount
        messages   = $messages
    }
}
catch {
    Write-Error "Gmail error: $_"
    return @{ configured = $true; today = 0; unread = 0; messages = @(); error = $_.Exception.Message }
}
