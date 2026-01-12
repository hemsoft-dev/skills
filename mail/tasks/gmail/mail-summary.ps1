<#
.SYNOPSIS
    Daily Gmail summary with today's count and sample messages.
.DESCRIPTION
    Child script for Gmail account. Called by parent mail-summary.ps1.
#>
param()

$ErrorActionPreference = 'Stop'

# Load Gmail authentication library
$LibPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib'
. (Join-Path $LibPath 'gmail-auth.ps1')

# Check configuration
if (-not (Test-GmailConfigured)) {
    return @{ configured = $false; today = 0; unread = 0; highlights = @() }
}

try {
    $accessToken = Get-GmailAccessToken
    if (-not $accessToken) {
        return @{ configured = $false; today = 0; unread = 0; highlights = @() }
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
    
    # Get highlights (up to 3 recent unread or today's messages)
    $highlights = @()
    
    if ($unreadCount -gt 0) {
        $hlParams = "q=$([System.Web.HttpUtility]::UrlEncode($unreadQuery))&maxResults=3"
        $hlResponse = Invoke-GmailApi -AccessToken $accessToken -Uri "/users/me/messages?$hlParams"
        
        foreach ($msg in $hlResponse.messages) {
            $details = Get-GmailMessage -AccessToken $accessToken -MessageId $msg.id -Format 'metadata'
            
            $from = Get-GmailHeader -Message $details -HeaderName 'From'
            $subject = Get-GmailHeader -Message $details -HeaderName 'Subject'
            
            $highlights += @{
                from    = $from ?? 'Unknown'
                subject = $subject ?? '(No subject)'
            }
        }
    } elseif ($todayCount -gt 0) {
        $hlParams = "q=$([System.Web.HttpUtility]::UrlEncode($todayQuery))&maxResults=3"
        $hlResponse = Invoke-GmailApi -AccessToken $accessToken -Uri "/users/me/messages?$hlParams"
        
        foreach ($msg in $hlResponse.messages) {
            $details = Get-GmailMessage -AccessToken $accessToken -MessageId $msg.id -Format 'metadata'
            
            $from = Get-GmailHeader -Message $details -HeaderName 'From'
            $subject = Get-GmailHeader -Message $details -HeaderName 'Subject'
            
            $highlights += @{
                from    = $from ?? 'Unknown'
                subject = $subject ?? '(No subject)'
            }
        }
    }
    
    return @{
        configured = $true
        today      = $todayCount
        unread     = $unreadCount
        highlights = $highlights
    }
}
catch {
    Write-Error "Gmail summary error: $_"
    return @{ configured = $true; today = 0; unread = 0; highlights = @(); error = $_.Exception.Message }
}
