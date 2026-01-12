<#
.SYNOPSIS
    Search Gmail messages by keyword.
.DESCRIPTION
    Child script for Gmail account. Called by parent mail-search.ps1.
.PARAMETER Query
    Search query string (supports Gmail search operators).
.PARAMETER Count
    Number of messages to return (default: 10, max: 50).
#>
param(
    [string]$Query,
    [int]$Count = 10
)

$ErrorActionPreference = 'Stop'
$Count = [Math]::Clamp($Count, 1, 50)

# Load Gmail authentication library
$LibPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib'
. (Join-Path $LibPath 'gmail-auth.ps1')

# Check configuration
if (-not (Test-GmailConfigured)) {
    return @{ configured = $false; count = 0; messages = @() }
}

if (-not $Query) {
    return @{ configured = $true; count = 0; messages = @(); error = "Query parameter required" }
}

try {
    $accessToken = Get-GmailAccessToken
    if (-not $accessToken) {
        return @{ configured = $false; count = 0; messages = @() }
    }

    # Search with query
    $searchQuery = "in:inbox $Query"
    $listParams = "q=$([System.Web.HttpUtility]::UrlEncode($searchQuery))&maxResults=$Count"
    $response = Invoke-GmailApi -AccessToken $accessToken -Uri "/users/me/messages?$listParams"
    
    $messages = @()
    $totalCount = $response.resultSizeEstimate ?? 0
    
    foreach ($msg in $response.messages) {
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
    
    return @{
        configured = $true
        count      = $totalCount
        messages   = $messages
    }
}
catch {
    Write-Error "Gmail search error: $_"
    return @{ configured = $true; count = 0; messages = @(); error = $_.Exception.Message }
}
