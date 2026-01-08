<#
.SYNOPSIS
    Get recent messages from a Slack channel with thread support and file downloads.

.DESCRIPTION
    Retrieves the most recent messages from a Slack channel, including thread replies
    (limited to prevent output overflow) and downloads any attached files.

.PARAMETER Channel
    Channel name (without #) or channel ID. Examples: "dev-tribe", "C1KAF274N"

.PARAMETER Count
    Number of parent messages to retrieve. Default is 5.

.PARAMETER MaxThreadReplies
    Maximum number of thread replies to include per message. Default is 2 (most recent).
    Set to 0 to exclude threads entirely. Set to -1 for all replies (use with caution).

.PARAMETER IncludeFiles
    Download attached files to the output directory.

.PARAMETER OutputDir
    Directory to save downloaded files. Default is current directory.

.PARAMETER OutputFormat
    Output format: 'Summary' (default), 'Detailed', or 'JSON'.

.EXAMPLE
    .\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -Count 5
    Get last 5 messages from #dev-tribe with up to 2 thread replies each.

.EXAMPLE
    .\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -Count 1 -MaxThreadReplies 5 -IncludeFiles
    Get last message with up to 5 thread replies and download any attachments.

.EXAMPLE
    .\Get-SlackChannelMessages.ps1 -Channel "C1KAF274N" -Count 3 -MaxThreadReplies 0
    Get last 3 messages without any thread replies.

.NOTES
    Requires SLACK_USER_TOKEN environment variable (for channel lookup and history).
    Token must have 'channels:read' and 'channels:history' scopes, or use search workaround.
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Channel,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 50)]
    [int]$Count = 5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(-1, 100)]
    [int]$MaxThreadReplies = 2,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeFiles,

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet('Summary', 'Detailed', 'JSON')]
    [string]$OutputFormat = 'Summary'
)

$InformationPreference = 'Continue'

# Set default OutputDir to temp folder under slack skill if not specified
if ([string]::IsNullOrEmpty($OutputDir)) {
    $OutputDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\temp"))
}

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web

# Check for token
if (-not $env:SLACK_USER_TOKEN) {
    Write-Error "SLACK_USER_TOKEN environment variable not set."
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $env:SLACK_USER_TOKEN"
    "Content-Type"  = "application/json"
}

# Known channel cache (add more as discovered)
$knownChannels = @{
    "pe-bot-test" = "C08H7CG4NTS"
    "dev-tribe"   = "C1KAF274N"
    "devtribe"    = "CP8BNHJDC"
}

# ============================================================================
# Helper Functions
# ============================================================================

function Get-ChannelId {
    param([string]$ChannelInput)
    
    # Already an ID?
    if ($ChannelInput -match '^C[A-Z0-9]+$') {
        return $ChannelInput
    }
    
    # Remove # prefix if present
    $channelName = $ChannelInput.TrimStart('#')
    
    # Check known channels first
    if ($knownChannels.ContainsKey($channelName)) {
        Write-Verbose "Found channel ID in cache: $($knownChannels[$channelName])"
        return $knownChannels[$channelName]
    }
    
    # Try conversations.list
    Write-Verbose "Looking up channel: $channelName"
    try {
        $listUrl = "https://slack.com/api/conversations.list?types=public_channel,private_channel&limit=500"
        $response = Invoke-RestMethod -Uri $listUrl -Headers $headers -Method Get
        
        if ($response.ok) {
            $found = $response.channels | Where-Object { $_.name -eq $channelName }
            if ($found) {
                Write-Verbose "Found channel via conversations.list: $($found.id)"
                return $found.id
            }
        }
    } catch {
        Write-Verbose "conversations.list failed: $_"
    }
    
    # Fallback: Use search to find channel ID
    Write-Verbose "Falling back to search method..."
    try {
        $query = [System.Web.HttpUtility]::UrlEncode("in:$channelName")
        $searchUrl = "https://slack.com/api/search.messages?query=$query&count=1"
        $response = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get
        
        if ($response.ok -and $response.messages.matches.Count -gt 0) {
            $channelId = $response.messages.matches[0].channel.id
            Write-Verbose "Found channel via search: $channelId"
            return $channelId
        }
    } catch {
        Write-Verbose "Search fallback failed: $_"
    }
    
    Write-Error "Could not find channel: $channelName"
    exit 1
}

function Get-FormattedTimestamp {
    param([string]$ts)
    try {
        $unixTime = [double]$ts.Split('.')[0]
        return [DateTimeOffset]::FromUnixTimeSeconds($unixTime).LocalDateTime
    } catch {
        return $null
    }
}

function Get-UserName {
    param([string]$UserId)
    
    # Cache user lookups in script scope
    if (-not $script:userCache) { $script:userCache = @{} }
    
    if ($script:userCache.ContainsKey($UserId)) {
        return $script:userCache[$UserId]
    }
    
    try {
        $userUrl = "https://slack.com/api/users.info?user=$UserId"
        $response = Invoke-RestMethod -Uri $userUrl -Headers $headers -Method Get
        if ($response.ok) {
            $name = if ($response.user.profile.display_name) { 
                $response.user.profile.display_name 
            } else { 
                $response.user.real_name 
            }
            $script:userCache[$UserId] = $name
            return $name
        }
    } catch {
        Write-Verbose "Could not lookup user $UserId"
    }
    
    return $UserId
}

function Copy-SlackFile {
    param(
        [object]$File,
        [string]$OutputDirectory
    )
    
    if (-not $File.url_private) { return $null }
    
    $fileName = $File.name
    $outputPath = Join-Path $OutputDirectory $fileName
    
    # Handle duplicate filenames
    $counter = 1
    while (Test-Path $outputPath) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extension = [System.IO.Path]::GetExtension($fileName)
        $outputPath = Join-Path $OutputDirectory "$baseName`_$counter$extension"
        $counter++
    }
    
    # Try bot token first (requires bot to be in channel), then user token
    $tokensToTry = @()
    if ($env:SLACK_TOKEN) { $tokensToTry += $env:SLACK_TOKEN }
    if ($env:SLACK_USER_TOKEN) { $tokensToTry += $env:SLACK_USER_TOKEN }
    
    foreach ($token in $tokensToTry) {
        try {
            $downloadHeaders = @{ "Authorization" = "Bearer $token" }
            Invoke-WebRequest -Uri $File.url_private -Headers $downloadHeaders -OutFile $outputPath -ErrorAction Stop
            
            # Verify we got binary data, not HTML
            $firstBytes = [System.IO.File]::ReadAllBytes($outputPath)[0..10]
            $header = [System.Text.Encoding]::ASCII.GetString($firstBytes)
            if ($header -like "*<!DOCTYPE*" -or $header -like "*<html*") {
                # Got HTML instead of file - auth failed, try next token
                Remove-Item $outputPath -ErrorAction SilentlyContinue
                continue
            }
            
            return $outputPath
        } catch {
            Remove-Item $outputPath -ErrorAction SilentlyContinue
            continue
        }
    }
    
    # All tokens failed
    Write-Warning "Failed to download file: $fileName (bot may not be in channel, or missing files:read scope)"
    Write-Warning "  URL: $($File.url_private)"
    return $null
}

function Get-ThreadReply {
    param(
        [string]$ChannelId,
        [string]$ThreadTs,
        [int]$Limit
    )
    
    if ($Limit -eq 0) { return @() }
    
    try {
        # Get all replies then take last N (API returns oldest first)
        $replyUrl = "https://slack.com/api/conversations.replies?channel=$ChannelId&ts=$ThreadTs&limit=100"
        $response = Invoke-RestMethod -Uri $replyUrl -Headers $headers -Method Get
        
        if ($response.ok -and $response.messages.Count -gt 1) {
            # First message is the parent, skip it
            $replies = $response.messages | Select-Object -Skip 1
            
            if ($Limit -gt 0 -and $replies.Count -gt $Limit) {
                # Take only the last N replies
                $skipped = $replies.Count - $Limit
                $replies = $replies | Select-Object -Last $Limit
                return @{
                    Replies = $replies
                    Skipped = $skipped
                    Total   = $response.messages.Count - 1
                }
            }
            
            return @{
                Replies = $replies
                Skipped = 0
                Total   = $replies.Count
            }
        }
    } catch {
        Write-Verbose "Failed to get thread replies: $_"
    }
    
    return @{ Replies = @(); Skipped = 0; Total = 0 }
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Information "[36m`n=== Slack Channel Messages ===`e[0m"

# Resolve channel ID
$channelId = Get-ChannelId -ChannelInput $Channel
Write-Information "[33mChannel: #$Channel ($channelId)`e[0m"

# Create output directory if needed
if ($IncludeFiles -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Get channel history using search (workaround for missing history scope)
Write-Information "[90mFetching last $Count messages...`e[0m"

$query = [System.Web.HttpUtility]::UrlEncode("in:$Channel")
$searchUrl = "https://slack.com/api/search.messages?query=$query&count=$Count&sort=timestamp&sort_dir=desc"
$response = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get

if (-not $response.ok) {
    Write-Error "Failed to fetch messages: $($response.error)"
    exit 1
}

$messages = $response.messages.matches
Write-Information "[32mRetrieved $($messages.Count) messages`n`e[0m"

if ($messages.Count -eq 0) {
    Write-Information "[33mNo messages found in channel.`e[0m"
    exit 0
}

# Collect all results for JSON output
$allResults = @()
$downloadedFiles = @()

# Process each message
foreach ($msg in $messages) {
    $timestamp = Get-FormattedTimestamp -ts $msg.ts
    $userName = if ($msg.username) { $msg.username } else { Get-UserName -UserId $msg.user }
    
    $result = @{
        Timestamp   = $timestamp
        User        = $userName
        Text        = $msg.text
        ThreadTs    = $msg.ts
        Permalink   = $msg.permalink
        Files       = @()
        Replies     = @()
        ReplyCount  = 0
        SkippedReplies = 0
    }
    
    # Output based on format
    if ($OutputFormat -ne 'JSON') {
        Write-Information "[36m[$($timestamp.ToString('yyyy-MM-dd HH:mm:ss'))] @$userName`e[0m"
        Write-Information "[97m$($msg.text)`e[0m"
    }
    
    # Handle files/attachments
    if ($msg.files -and $msg.files.Count -gt 0) {
        foreach ($file in $msg.files) {
            $fileInfo = @{
                Name     = $file.name
                Type     = $file.mimetype
                Size     = $file.size
                Url      = $file.url_private
                LocalPath = $null
            }
            
            if ($OutputFormat -ne 'JSON') {
                Write-Information "[35m  📎 Attachment: $($file.name) ($($file.mimetype))`e[0m"
            }
            
            if ($IncludeFiles) {
                $localPath = Copy-SlackFile -File $file -OutputDirectory $OutputDir
                if ($localPath) {
                    $fileInfo.LocalPath = $localPath
                    $downloadedFiles += $localPath
                    if ($OutputFormat -ne 'JSON') {
                        Write-Information "[32m     ✅ Downloaded to: $localPath`e[0m"
                    }
                }
            }
            
            $result.Files += $fileInfo
        }
    }
    
    # Get thread replies if message has them
    if ($msg.thread_ts -or ($msg.reply_count -and $msg.reply_count -gt 0)) {
        $threadData = Get-ThreadReply -ChannelId $channelId -ThreadTs $msg.ts -Limit $MaxThreadReplies
        
        if ($threadData.Total -gt 0) {
            $result.ReplyCount = $threadData.Total
            $result.SkippedReplies = $threadData.Skipped
            
            if ($OutputFormat -ne 'JSON' -and $threadData.Skipped -gt 0) {
                Write-Information "[33m  💬 Thread: $($threadData.Total) replies (showing last $MaxThreadReplies, skipped $($threadData.Skipped))`e[0m"
            } elseif ($OutputFormat -ne 'JSON' -and $threadData.Total -gt 0) {
                Write-Information "[33m  💬 Thread: $($threadData.Total) replies`e[0m"
            }
            
            foreach ($reply in $threadData.Replies) {
                $replyTime = Get-FormattedTimestamp -ts $reply.ts
                $replyUser = if ($reply.username) { $reply.username } else { Get-UserName -UserId $reply.user }
                
                $replyInfo = @{
                    Timestamp = $replyTime
                    User      = $replyUser
                    Text      = $reply.text
                    Files     = @()
                }
                
                if ($OutputFormat -ne 'JSON') {
                    Write-Information "[36m    ↳ [$($replyTime.ToString('HH:mm'))] @$replyUser`e[0m"
                    # Truncate long replies in summary mode
                    $replyText = $reply.text
                    if ($OutputFormat -eq 'Summary' -and $replyText.Length -gt 200) {
                        $replyText = $replyText.Substring(0, 200) + "..."
                    }
                    Write-Information "[90m      $replyText`e[0m"
                }
                
                # Handle files in replies
                if ($reply.files -and $reply.files.Count -gt 0) {
                    foreach ($file in $reply.files) {
                        $fileInfo = @{
                            Name     = $file.name
                            Type     = $file.mimetype
                            LocalPath = $null
                        }
                        
                        if ($OutputFormat -ne 'JSON') {
                            Write-Information "[35m      📎 $($file.name)`e[0m"
                        }
                        
                        if ($IncludeFiles) {
                            $localPath = Copy-SlackFile -File $file -OutputDirectory $OutputDir
                            if ($localPath) {
                                $fileInfo.LocalPath = $localPath
                                $downloadedFiles += $localPath
                                if ($OutputFormat -ne 'JSON') {
                                    Write-Information "[32m         ✅ Downloaded: $localPath`e[0m"
                                }
                            }
                        }
                        
                        $replyInfo.Files += $fileInfo
                    }
                }
                
                $result.Replies += $replyInfo
            }
        }
    }
    
    if ($OutputFormat -ne 'JSON') {
        Write-Information "[90m---`e[0m"
        Write-Information ""
    }
    
    $allResults += $result
}

# JSON output
if ($OutputFormat -eq 'JSON') {
    $allResults | ConvertTo-Json -Depth 10
}

# Summary
Write-Information "[36m`n=== Summary ===`e[0m"
Write-Information "[97mMessages retrieved: $($messages.Count)`e[0m"
Write-Information "[97mThread reply limit: $MaxThreadReplies per message`e[0m"

if ($downloadedFiles.Count -gt 0) {
    Write-Information "[32mFiles downloaded: $($downloadedFiles.Count)`e[0m"
    Write-Information "[32mOutput directory: $(Resolve-Path $OutputDir)`e[0m"
    Write-Information "[33m`nDownloaded files:`e[0m"
    foreach ($file in $downloadedFiles) {
        Write-Information "[97m  • $file`e[0m"
    }
}

Write-Information ""
