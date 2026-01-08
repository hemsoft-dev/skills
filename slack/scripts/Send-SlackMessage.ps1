<#
.SYNOPSIS
    Sends a message to a Slack channel or user, optionally with a file attachment.

.DESCRIPTION
    Posts a message to a specified Slack channel or direct message.
    Requires SLACK_TOKEN environment variable with chat:write scope.
    For file uploads, also requires files:write scope.
    Displays an approval prompt before sending for safety.

.PARAMETER Channel
    Channel name (#channel-name), channel ID (C123ABC), or user ID (@username or U123ABC)

.PARAMETER Text
    The message text to send. Supports Slack markdown formatting.

.PARAMETER FilePath
    Optional path to a file to upload with the message.

.PARAMETER FileTitle
    Optional title for the uploaded file (defaults to filename).

.PARAMETER ThreadTs
    Optional timestamp of a parent message to reply in thread

.PARAMETER AsUser
    Post as the authenticated user instead of bot (requires user token)

.EXAMPLE
    .\Send-SlackMessage.ps1 -Channel "#pe-bot-test" -Text "Hello from PowerShell!"

.EXAMPLE
    .\Send-SlackMessage.ps1 -Channel "C08H7CG4NTS" -Text "Check out this image!" -FilePath "D:\image.png"

.EXAMPLE
    .\Send-SlackMessage.ps1 -Channel "#pe-bot-test" -Text "Report attached" -FilePath "C:\report.pdf" -FileTitle "Monthly Report"
#>

$InformationPreference = 'Continue'

param(
    [Parameter(Mandatory=$true)]
    [string]$Channel,
    
    [Parameter(Mandatory=$false)]
    [string]$Text,
    
    [Parameter(Mandatory=$false)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$false)]
    [string]$FileTitle,
    
    [Parameter(Mandatory=$false)]
    [string]$ThreadTs,
    
    [Parameter(Mandatory=$false)]
    [switch]$AsUser
)

# Validate environment variable
if (-not $env:SLACK_TOKEN) {
    Write-Information "[31mError: SLACK_TOKEN environment variable not set`e[0m"
    Write-Information "[33mPlease set it with: [Environment]::SetEnvironmentVariable('SLACK_TOKEN', 'xoxb-...', 'User')`e[0m"
    exit 1
}

# Validate that at least Text or FilePath is provided
if (-not $Text -and -not $FilePath) {
    Write-Information "[31mError: Must provide either -Text or -FilePath (or both)`e[0m"
    exit 1
}

# Validate file exists if provided
if ($FilePath -and -not (Test-Path $FilePath)) {
    Write-Information "[31mError: File not found: $FilePath`e[0m"
    exit 1
}

# Resolve channel name to ID if needed
$channelId = $Channel
if ($Channel -match '^#') {
    Write-Information "[90mResolving channel name...`e[0m"
    $channelName = $Channel.TrimStart('#')
    
    $listHeaders = @{ "Authorization" = "Bearer $env:SLACK_TOKEN" }
    $channels = Invoke-RestMethod -Uri "https://slack.com/api/conversations.list?types=public_channel,private_channel&limit=1000" -Headers $listHeaders
    
    $foundChannel = $channels.channels | Where-Object { $_.name -eq $channelName }
    if ($foundChannel) {
        $channelId = $foundChannel.id
        Write-Information "[90m  → $Channel = $channelId`e[0m"
    } else {
        Write-Information "[31mError: Channel $Channel not found`e[0m"
        exit 1
    }
}

# Display approval prompt
Write-Information "[36m`n========================================`e[0m"
Write-Information "[36mSLACK MESSAGE APPROVAL`e[0m"
Write-Information "[36m========================================`e[0m"
Write-Information "[33mChannel:  $Channel`e[0m"
Write-Information "[90mID:       $channelId`e[0m"
if ($Text) {
    Write-Information "[97mMessage:  $Text`e[0m"
}
if ($FilePath) {
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $fileSize = (Get-Item $FilePath).Length
    $fileSizeKB = [math]::Round($fileSize / 1KB, 1)
    Write-Information "[35mFile:     $fileName ($fileSizeKB KB)`e[0m"
    if ($FileTitle) {
        Write-Information "[90mTitle:    $FileTitle`e[0m"
    }
}
if ($ThreadTs) {
    Write-Information "[90mThread:   $ThreadTs`e[0m"
}
Write-Information "[36m========================================`n`e[0m"

$confirmation = Read-Host "Send this message? (yes/no)"
if ($confirmation -ne 'yes') {
    Write-Information "[33m✗ Message not sent (user cancelled)`e[0m"
    exit 0
}

# Prepare request
$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type" = "application/json"
}

# Handle file upload if FilePath provided
if ($FilePath) {
    Write-Information "[90m`nUploading file...`e[0m"
    try {
        # Read file
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        
        # Step 1: Get upload URL
        $uploadHeaders = @{ "Authorization" = "Bearer $env:SLACK_TOKEN"; "Content-Type" = "application/x-www-form-urlencoded" }
        $uploadBody = "filename=$([System.Web.HttpUtility]::UrlEncode($fileName))&length=$($fileBytes.Length)"
        $uploadUrlResponse = Invoke-RestMethod -Uri "https://slack.com/api/files.getUploadURLExternal" -Headers $uploadHeaders -Method Post -Body $uploadBody
        
        if (-not $uploadUrlResponse.ok) {
            Write-Information "[31m`n✗ Failed to get upload URL: $($uploadUrlResponse.error)`e[0m"
            exit 1
        }
        
        # Step 2: Upload file bytes
        Write-Information "[90m  Uploading bytes...`e[0m"
        $null = Invoke-WebRequest -Uri $uploadUrlResponse.upload_url -Method Post -ContentType "application/octet-stream" -Body $fileBytes
        
        # Step 3: Complete upload
        Write-Information "[90m  Completing upload...`e[0m"
        $title = if ($FileTitle) { $FileTitle } else { $fileName }
        $completeBody = @{
            files = @(@{ id = $uploadUrlResponse.file_id; title = $title })
            channel_id = $channelId
        }
        if ($Text) {
            $completeBody.initial_comment = $Text
        }
        
        $completeJson = $completeBody | ConvertTo-Json -Depth 5
        $result = Invoke-RestMethod -Uri "https://slack.com/api/files.completeUploadExternal" -Headers $headers -Method Post -Body $completeJson
        
        if ($result.ok) {
            Write-Information "[32m`n✓ File uploaded successfully!`e[0m"
            Write-Information "[33m  Channel: $channelId`e[0m"
            Write-Information "[33m  File ID: $($result.files[0].id)`e[0m"
            Write-Information "[36m  Permalink: $($result.files[0].permalink)`e[0m"
        } else {
            Write-Information "[31m`n✗ Slack API Error: $($result.error)`e[0m"
            exit 1
        }
    } catch {
        Write-Information "[31m`n✗ Upload failed: $($_.Exception.Message)`e[0m"
        exit 1
    }
} else {
    # Regular text message (no file)
    $body = @{
        channel = $channelId
        text = $Text
    }

    if ($ThreadTs) {
        $body.thread_ts = $ThreadTs
    }

    if ($AsUser) {
        $body.as_user = $true
    }

    $bodyJson = $body | ConvertTo-Json

    # Send message
    Write-Information "[90m`nSending message...`e[0m"
    try {
        $result = Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Headers $headers -Method Post -Body $bodyJson
        
        if ($result.ok) {
            Write-Information "[32m`n✓ Message sent successfully!`e[0m"
            Write-Information "[33m  Channel: $($result.channel)`e[0m"
            Write-Information "[33m  Timestamp: $($result.ts)`e[0m"
            Write-Information "[36m  Permalink: https://relias-engineering.slack.com/archives/$($result.channel)/p$($result.ts.Replace('.', ''))`e[0m"
        } else {
            Write-Information "[31m`n✗ Slack API Error: $($result.error)`e[0m"
            if ($result.needed) {
                Write-Information "[33m  Required scope: $($result.needed)`e[0m"
            }
            exit 1
        }
    } catch {
        Write-Information "[31m`n✗ Request failed: $($_.Exception.Message)`e[0m"
        exit 1
    }
}
