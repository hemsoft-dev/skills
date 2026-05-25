<#
.SYNOPSIS
    Get a comprehensive Slack daily briefing including mentions, DMs, and channel activity.

.DESCRIPTION
    Generates a summary of Slack activity including:
    - Direct @mentions of the user
    - Direct messages received
    - Activity in specified channels (or default important channels)
    - Key announcements (@channel, @here)
    - Action items and pending requests

.PARAMETER Username
    Your Slack username (without @). Used for finding mentions.
    Default: 'fhemmer'

.PARAMETER DaysBack
    Number of days to look back for messages. Default is 1 (today + yesterday).

.PARAMETER Channels
    Array of channel names to monitor. If not specified, uses default channels.

.PARAMETER IncludeDMs
    Include direct message summary. Default is $true.

.PARAMETER IncludeMentions
    Include @mentions summary. Default is $true.

.PARAMETER IncludeAnnouncements
    Search for @channel and @here announcements. Default is $true.

.PARAMETER OutputFormat
    Output format: 'Summary' (default), 'Detailed', or 'JSON'.

.PARAMETER MaxMessagesPerChannel
    Maximum messages to retrieve per channel. Default is 10.

.EXAMPLE
    .\Get-SlackDailyBriefing.ps1
    Get today's briefing with all defaults.

.EXAMPLE
    .\Get-SlackDailyBriefing.ps1 -DaysBack 3 -OutputFormat Detailed
    Get detailed briefing for the last 3 days.

.EXAMPLE
    .\Get-SlackDailyBriefing.ps1 -Channels @("relias-engineering", "productivity-engineering-public")
    Get briefing focused on specific channels.

.EXAMPLE
    .\Get-SlackDailyBriefing.ps1 -Username "jsmith" -IncludeDMs $false
    Get briefing for different user, excluding DMs.

.NOTES
    Requires SLACK_USER_TOKEN environment variable to be set.
    Token must have 'search:read' scope.
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Username = 'fhemmer',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 30)]
    [int]$DaysBack = 1,

    [Parameter(Mandatory = $false)]
    [string[]]$Channels = @(
        "ai-chapter",
        "dev-ex-private",
        "prod-eng-devex-private",
        "productivity-engineering-private",
        "productivity-engineering-public",
        "relias-cortex-external",
        "dev-tribe",
        "next-deployment",
        "swatteam",
        "systems-mangement",
        "architecture",
        "dev-env-help",
        "platform",
        "product-engineering",
        "relias-engineering",
        "software-quality",
        "sonarcloud-public"
    ),

    [Parameter(Mandatory = $false)]
    [bool]$IncludeDMs = $true,

    [Parameter(Mandatory = $false)]
    [bool]$IncludeMentions = $true,

    [Parameter(Mandatory = $false)]
    [bool]$IncludeAnnouncements = $true,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Summary', 'Detailed', 'JSON')]
    [string]$OutputFormat = 'Summary',

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 50)]
    [int]$MaxMessagesPerChannel = 10
)

$InformationPreference = 'Continue'

#region Helper Functions

function Get-SlackEnvironmentVariable {
    param([string]$Name)

    foreach ($scope in 'Process', 'User', 'Machine') {
        $value = [System.Environment]::GetEnvironmentVariable($Name, $scope)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return $null
}

function Write-Section {
    param([string]$Title, [string]$Emoji = "📌")
    Write-Information "[36m`n$Emoji $Title`e[0m"
    Write-Information "[36m$(("=" * ($Title.Length + 3)))`e[0m"
}

function Write-SubSection {
    param([string]$Title)
    Write-Information "[33m`n  $Title`e[0m"
}

function Format-SlackTimestamp {
    param([string]$Timestamp)
    try {
        $unixSeconds = [double]$Timestamp.Split('.')[0]
        return [DateTimeOffset]::FromUnixTimeSeconds($unixSeconds).LocalDateTime
    }
    catch {
        return $null
    }
}

function Invoke-SlackSearch {
    param(
        [string]$Query,
        [int]$Count = 20
    )
    
    $encodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)
    $apiUrl = "https://slack.com/api/search.messages?query=$encodedQuery&count=$Count&sort=timestamp&sort_dir=desc"
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $script:headers -Method Get -ErrorAction Stop
        if ($response.ok) {
            return $response
        }
        else {
            Write-Verbose "Search error: $($response.error)"
            return $null
        }
    }
    catch {
        Write-Verbose "Search failed: $_"
        return $null
    }
}

function Get-MessagePreview {
    param(
        [string]$Text,
        [int]$MaxLength = 200
    )
    $clean = (($Text -replace ':[a-zA-Z0-9_+-]+:', '') -replace '\s+', ' ').Trim()
    if ($clean.Length -gt $MaxLength) {
        return $clean.Substring(0, $MaxLength) + "..."
    }
    return $clean
}

# Cache for user real names - loaded in bulk at startup
$script:userCache = @{}

function Initialize-UserCache {
    <#
    .SYNOPSIS
        Loads all workspace users into cache with a single API call.
    #>

    $botHeaders = @{
        "Authorization" = "Bearer $script:slackBotToken"
        "Content-Type"  = "application/json"
    }
    
    $cursor = $null
    do {
        $url = "https://slack.com/api/users.list?limit=200"
        if ($cursor) { $url += "&cursor=$cursor" }
        
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $botHeaders -Method Get -ErrorAction Stop
            if ($response.ok) {
                foreach ($user in $response.members) {
                    # Prefer real_name over display_name (display_name is often just the username)
                    $realName = if ($user.profile.real_name -and $user.profile.real_name -ne $user.name) {
                        $user.profile.real_name
                    } elseif ($user.profile.display_name -and $user.profile.display_name -ne $user.name) {
                        $user.profile.display_name
                    } else {
                        $user.name
                    }
                    
                    # Cache by both user ID and username for flexible lookup
                    $script:userCache[$user.id] = $realName
                    $script:userCache[$user.name] = $realName
                }
                $cursor = $response.response_metadata.next_cursor
            } else {
                Write-Verbose "users.list failed: $($response.error)"
                break
            }
        }
        catch {
            Write-Verbose "users.list request failed: $_"
            break
        }
    } while ($cursor)
    
    Write-Verbose "Loaded $($script:userCache.Count / 2) users into cache"
}

function Get-SlackUserRealName {
    param(
        [string]$Username,
        [string]$UserId
    )
    
    # Try user ID first, then username
    if ($UserId -and $script:userCache.ContainsKey($UserId)) {
        return $script:userCache[$UserId]
    }
    if ($Username -and $script:userCache.ContainsKey($Username)) {
        return $script:userCache[$Username]
    }
    
    # Fallback to username if not in cache
    return $Username
}

#endregion

#region Initialization

# Load tokens from the process snapshot or persistent Windows environment.
$script:slackUserToken = Get-SlackEnvironmentVariable -Name 'SLACK_USER_TOKEN'
$script:slackBotToken = Get-SlackEnvironmentVariable -Name 'SLACK_TOKEN'

if (-not $script:slackUserToken) {
    Write-Error "SLACK_USER_TOKEN environment variable not set. Please set it with your user token (xoxp-)."
    exit 1
}

Add-Type -AssemblyName System.Web

$script:headers = @{
    "Authorization" = "Bearer $script:slackUserToken"
    "Content-Type"  = "application/json"
}

# Load all users into cache (single API call instead of per-user lookups)
Initialize-UserCache

$targetDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', $null)
$startDate = $targetDate.AddDays(-$DaysBack).ToString("yyyy-MM-dd")
$todayStr = $targetDate.ToString("yyyy-MM-dd")
$queryBeforeDate = $targetDate.AddDays(1).ToString("yyyy-MM-dd")

# Results collection for JSON output
$briefingData = @{
    GeneratedAt     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    DateRange       = @{
        From = $startDate
        To   = $todayStr
    }
    Username        = $Username
    Mentions        = @()
    DirectMessages  = @()
    Announcements   = @()
    ChannelActivity = @{}
    ActionItems     = @()
}

#endregion

#region Display Header

if ($OutputFormat -ne 'JSON') {
    Write-Information ""
    Write-Information "[35m╔════════════════════════════════════════════════════════════════╗`e[0m"
    Write-Information "[35m║              📋 SLACK DAILY BRIEFING                           ║`e[0m"
    Write-Information "[35m║              $(Get-Date -Format 'dddd, MMMM d, yyyy')                       ║`e[0m"
    Write-Information "[35m╚════════════════════════════════════════════════════════════════╝`e[0m"
    Write-Information "[90m`nDate Range: $startDate to $todayStr`e[0m"
    Write-Information "[90mUser: @$Username`e[0m"
}

#endregion

#region Mentions

if ($IncludeMentions) {
    if ($OutputFormat -ne 'JSON') { Write-Section "Direct @Mentions" "🔔" }
    
    $mentionQuery = "@$Username -from:$Username after:$startDate before:$queryBeforeDate"
    $mentionResults = Invoke-SlackSearch -Query $mentionQuery -Count 30
    
    if ($mentionResults -and $mentionResults.messages.total -gt 0) {
        $mentions = $mentionResults.messages.matches | Where-Object { $_.username -ne $Username }
        
        if ($OutputFormat -ne 'JSON') {
            Write-Information "[32mFound $($mentions.Count) mention(s)`e[0m"
        }
        
        foreach ($mention in $mentions) {
            $ts = Format-SlackTimestamp -Timestamp $mention.ts
            $preview = Get-MessagePreview -Text $mention.text
            $realName = Get-SlackUserRealName -Username $mention.username -UserId $mention.user
            
            $mentionData = @{
                Timestamp = $ts.ToString("yyyy-MM-dd HH:mm")
                Channel   = $mention.channel.name
                From      = $realName
                Text      = $preview
                Permalink = $mention.permalink
            }
            $briefingData.Mentions += $mentionData
            
            # Check if this looks like an action item
            if ($mention.text -match 'approve|review|please|can you|could you|need|urgent|asap') {
                $briefingData.ActionItems += @{
                    Type    = "Mention"
                    From    = $realName
                    Channel = $mention.channel.name
                    Text    = $preview
                    Link    = $mention.permalink
                }
            }
            
            if ($OutputFormat -eq 'Detailed') {
                Write-Information "[36m`n  [$($ts.ToString('MM/dd HH:mm'))] #$($mention.channel.name) - @$($realName):`e[0m"
                Write-Information "[97m  $preview`e[0m"
                if ($mention.permalink) {
                    Write-Information "[90m  $($mention.permalink)`e[0m"
                }
            }
            elseif ($OutputFormat -eq 'Summary') {
                Write-Information "[97m  • [$($ts.ToString('MM/dd HH:mm'))] @$($realName) in #$($mention.channel.name)`e[0m"
            }
        }
    }
    else {
        if ($OutputFormat -ne 'JSON') {
            Write-Information "[90m  No new mentions found.`e[0m"
        }
    }
}

#endregion

#region Direct Messages

if ($IncludeDMs) {
    if ($OutputFormat -ne 'JSON') { Write-Section "Direct Messages" "💬" }
    
    $dmQuery = "to:me after:$startDate before:$queryBeforeDate"
    $dmResults = Invoke-SlackSearch -Query $dmQuery -Count 30
    
    if ($dmResults -and $dmResults.messages.total -gt 0) {
        # Filter to actual DMs (not channel messages)
        $dms = $dmResults.messages.matches | Where-Object { 
            $_.channel.is_im -eq $true -or 
            $_.channel.name -eq "directmessage" -or
            $_.channel.name -match "^mpdm-" -or
            (-not $_.channel.name.StartsWith("#"))
        } | Where-Object { $_.username -ne $Username }
        
        if ($dms.Count -gt 0) {
            if ($OutputFormat -ne 'JSON') {
                Write-Information "[32mFound $($dms.Count) DM(s)`e[0m"
            }
            
            # Group by sender
            $dmGroups = $dms | Group-Object username
            
            foreach ($group in $dmGroups) {
                $groupRealName = Get-SlackUserRealName -Username $group.Name -UserId $group.Group[0].user
                if ($OutputFormat -ne 'JSON') {
                    Write-SubSection "From @$($groupRealName) ($($group.Count) message(s))"
                }
                
                foreach ($dm in ($group.Group | Select-Object -First 5)) {
                    $ts = Format-SlackTimestamp -Timestamp $dm.ts
                    $preview = Get-MessagePreview -Text $dm.text -MaxLength 150
                    $dmRealName = Get-SlackUserRealName -Username $dm.username -UserId $dm.user
                    
                    $dmData = @{
                        Timestamp = $ts.ToString("yyyy-MM-dd HH:mm")
                        From      = $dmRealName
                        Text      = $preview
                    }
                    $briefingData.DirectMessages += $dmData
                    
                    if ($OutputFormat -eq 'Detailed') {
                        Write-Information "[90m    [$($ts.ToString('MM/dd HH:mm'))]`e[0m"
                        Write-Information "[97m    $preview`e[0m"
                    }
                    elseif ($OutputFormat -eq 'Summary') {
                        Write-Information "[97m    • [$($ts.ToString('MM/dd HH:mm'))] $($preview.Substring(0, [Math]::Min(80, $preview.Length)))...`e[0m"
                    }
                }
            }
        }
        else {
            if ($OutputFormat -ne 'JSON') {
                Write-Information "[90m  No new DMs found.`e[0m"
            }
        }
    }
    else {
        if ($OutputFormat -ne 'JSON') {
            Write-Information "[90m  No new DMs found.`e[0m"
        }
    }
}

#endregion

#region Announcements

if ($IncludeAnnouncements) {
    if ($OutputFormat -ne 'JSON') { Write-Section "Announcements (@channel/@here)" "📢" }
    
    # Search for @channel and @here announcements
    $announcementQuery = "<!channel> OR <!here> after:$startDate before:$queryBeforeDate"
    $announcementResults = Invoke-SlackSearch -Query $announcementQuery -Count 20
    
    if ($announcementResults -and $announcementResults.messages.total -gt 0) {
        if ($OutputFormat -ne 'JSON') {
            Write-Information "[32mFound $($announcementResults.messages.matches.Count) announcement(s)`e[0m"
        }
        
        foreach ($ann in $announcementResults.messages.matches) {
            $ts = Format-SlackTimestamp -Timestamp $ann.ts
            $preview = Get-MessagePreview -Text $ann.text -MaxLength 250
            $annRealName = Get-SlackUserRealName -Username $ann.username -UserId $ann.user
            
            $annData = @{
                Timestamp = $ts.ToString("yyyy-MM-dd HH:mm")
                Channel   = $ann.channel.name
                From      = $annRealName
                Text      = $preview
                Permalink = $ann.permalink
            }
            $briefingData.Announcements += $annData
            
            if ($OutputFormat -eq 'Detailed') {
                Write-Information "[36m`n  [$($ts.ToString('MM/dd HH:mm'))] #$($ann.channel.name) - @$($annRealName):`e[0m"
                Write-Information "[97m  $preview`e[0m"
            }
            elseif ($OutputFormat -eq 'Summary') {
                $shortPreview = Get-MessagePreview -Text $ann.text -MaxLength 80
                Write-Information "[97m  • [$($ts.ToString('MM/dd HH:mm'))] #$($ann.channel.name): $shortPreview`e[0m"
            }
        }
    }
    else {
        if ($OutputFormat -ne 'JSON') {
            Write-Information "[90m  No announcements found.`e[0m"
        }
    }
}

#endregion

#region Channel Activity

if ($OutputFormat -ne 'JSON') { Write-Section "Channel Activity" "📁" }

# Also search for deployment channels matching pattern
$deploymentQuery = "in:#platform-deployment after:$startDate before:$queryBeforeDate"
$deployResults = Invoke-SlackSearch -Query $deploymentQuery -Count 5

# Find the most recent deployment channel
$activeDeployChannel = $null
if ($deployResults -and $deployResults.messages.matches.Count -gt 0) {
    $deployChannels = $deployResults.messages.matches | 
    Where-Object { $_.channel.name -match 'platform-deployment-\d{2}-\d{2}-\d{4}' } |
    Select-Object -ExpandProperty channel -Unique |
    Select-Object -First 1
    
    if ($deployChannels) {
        $activeDeployChannel = $deployChannels.name
    }
}

# Add active deployment channel to the list if found
$channelsToCheck = $Channels
if ($activeDeployChannel -and $activeDeployChannel -notin $channelsToCheck) {
    $channelsToCheck = @($activeDeployChannel) + $channelsToCheck
}

foreach ($channel in $channelsToCheck) {
    $channelQuery = "in:#$channel after:$startDate before:$queryBeforeDate -from:@email -from:@datadog -from:@pagerduty"
    $channelResults = Invoke-SlackSearch -Query $channelQuery -Count $MaxMessagesPerChannel
    
    if ($channelResults -and $channelResults.messages.total -gt 0) {
        $briefingData.ChannelActivity[$channel] = @{
            TotalMessages = $channelResults.messages.total
            RecentMessages = @()
        }
        
        if ($OutputFormat -ne 'JSON') {
            $isDeployChannel = $channel -match 'platform-deployment'
            $channelIcon = if ($isDeployChannel) { "🚀" } else { "💬" }
            Write-SubSection "$channelIcon #$channel ($($channelResults.messages.total) messages)"
        }
        
        $messagesToShow = if ($OutputFormat -eq 'Summary') { 3 } else { $MaxMessagesPerChannel }
        
        foreach ($msg in ($channelResults.messages.matches | Select-Object -First $messagesToShow)) {
            $ts = Format-SlackTimestamp -Timestamp $msg.ts
            $preview = Get-MessagePreview -Text $msg.text -MaxLength $(if ($OutputFormat -eq 'Summary') { 100 } else { 200 })
            $msgRealName = Get-SlackUserRealName -Username $msg.username -UserId $msg.user
            
            $msgData = @{
                Timestamp = $ts.ToString("yyyy-MM-dd HH:mm")
                From      = $msgRealName
                Text      = $preview
            }
            $briefingData.ChannelActivity[$channel].RecentMessages += $msgData
            
            # Skip empty/bot messages in summary
            if ($OutputFormat -eq 'Summary' -and $preview.Length -lt 10) { continue }
            
            if ($OutputFormat -eq 'Detailed') {
                Write-Information "[90m    [$($ts.ToString('MM/dd HH:mm'))] @$($msgRealName):`e[0m"
                Write-Information "[97m    $preview`e[0m"
            }
            elseif ($OutputFormat -eq 'Summary') {
                Write-Information "[97m    • @$($msgRealName): $preview`e[0m"
            }
        }
        
        if ($channelResults.messages.total -gt $messagesToShow -and $OutputFormat -ne 'JSON') {
            Write-Information "[90m    ... and $($channelResults.messages.total - $messagesToShow) more`e[0m"
        }
    }
    elseif ($OutputFormat -eq 'Detailed') {
        Write-Information "[90m`n  #$channel - No recent activity`e[0m"
    }
}

#endregion

#region Action Items Summary

if ($briefingData.ActionItems.Count -gt 0 -and $OutputFormat -ne 'JSON') {
    Write-Section "⚡ Potential Action Items" "⚡"
    Write-Information "[33m  These messages may require your attention:`e[0m"
    
    foreach ($item in $briefingData.ActionItems) {
        Write-Information "[36m`n  • From @$($item.From) in #$($item.Channel):`e[0m"
        Write-Information "[97m    $($item.Text)`e[0m"
        if ($item.Link) {
            Write-Information "[90m    $($item.Link)`e[0m"
        }
    }
}

#endregion

#region Output File Generation

# Always generate JSON output file for diary integration
$outputDir = Join-Path $PSScriptRoot ".." "output"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
$totalChannelMsgs = ($briefingData.ChannelActivity.Values | ForEach-Object { $_.TotalMessages } | Measure-Object -Sum).Sum
$briefingData.Summary = @{
    Mentions        = $briefingData.Mentions.Count
    DirectMessages  = $briefingData.DirectMessages.Count
    Announcements   = $briefingData.Announcements.Count
    ChannelMessages = $totalChannelMsgs
    Channels        = $briefingData.ChannelActivity.Count
    ActionItems     = $briefingData.ActionItems.Count
}
$outputFile = Join-Path $outputDir "$todayStr-slack-briefing.json"

$briefingData | ConvertTo-Json -Depth 12 | Set-Content -Path $outputFile -Encoding UTF8
Write-Information "[32m`nOutput saved to: $outputFile`e[0m"

#endregion

#region Output

if ($OutputFormat -eq 'JSON') {
    $briefingData | ConvertTo-Json -Depth 10
}
else {
    # Final summary
    Write-Information ""
    Write-Information "[35m╔════════════════════════════════════════════════════════════════╗`e[0m"
    Write-Information "[35m║                        📊 SUMMARY                              ║`e[0m"
    Write-Information "[35m╚════════════════════════════════════════════════════════════════╝`e[0m"
    
    $mentionColor = if ($briefingData.Mentions.Count -gt 0) { "`e[33m" } else { "`e[32m" }
    $dmColor = if ($briefingData.DirectMessages.Count -gt 0) { "`e[33m" } else { "`e[32m" }
    $annColor = if ($briefingData.Announcements.Count -gt 0) { "`e[33m" } else { "`e[32m" }
    $actionColor = if ($briefingData.ActionItems.Count -gt 0) { "`e[31m" } else { "`e[32m" }
    Write-Information "${mentionColor}  🔔 Mentions:      $($briefingData.Mentions.Count)`e[0m"
    Write-Information "${dmColor}  💬 DMs:           $($briefingData.DirectMessages.Count)`e[0m"
    Write-Information "${annColor}  📢 Announcements: $($briefingData.Announcements.Count)`e[0m"
    Write-Information "${actionColor}  ⚡ Action Items:  $($briefingData.ActionItems.Count)`e[0m"
    
    $totalChannelMessages = ($briefingData.ChannelActivity.Values | ForEach-Object { $_.TotalMessages } | Measure-Object -Sum).Sum
    Write-Information "[97m  📁 Channel Msgs:  $totalChannelMessages (across $($briefingData.ChannelActivity.Count) channels)`e[0m"
    
    Write-Information "[90m`n  Generated at $(Get-Date -Format 'HH:mm:ss')`e[0m"
}

#endregion
