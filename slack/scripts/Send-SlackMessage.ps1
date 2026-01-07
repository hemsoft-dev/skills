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
    Write-Information "Error: SLACK_TOKEN environment variable not set" -ForegroundColor Red
    Write-Information "Please set it with: [Environment]::SetEnvironmentVariable('SLACK_TOKEN', 'xoxb-...', 'User')" -ForegroundColor Yellow
    exit 1
}

# Validate that at least Text or FilePath is provided
if (-not $Text -and -not $FilePath) {
    Write-Information "Error: Must provide either -Text or -FilePath (or both)" -ForegroundColor Red
    exit 1
}

# Validate file exists if provided
if ($FilePath -and -not (Test-Path $FilePath)) {
    Write-Information "Error: File not found: $FilePath" -ForegroundColor Red
    exit 1
}

# Resolve channel name to ID if needed
$channelId = $Channel
if ($Channel -match '^#') {
    Write-Information "Resolving channel name..." -ForegroundColor Gray
    $channelName = $Channel.TrimStart('#')
    
    $listHeaders = @{ "Authorization" = "Bearer $env:SLACK_TOKEN" }
    $channels = Invoke-RestMethod -Uri "https://slack.com/api/conversations.list?types=public_channel,private_channel&limit=1000" -Headers $listHeaders
    
    $foundChannel = $channels.channels | Where-Object { $_.name -eq $channelName }
    if ($foundChannel) {
        $channelId = $foundChannel.id
        Write-Information "  → $Channel = $channelId" -ForegroundColor Gray
    } else {
        Write-Information "Error: Channel $Channel not found" -ForegroundColor Red
        exit 1
    }
}

# Display approval prompt
Write-Information "`n========================================" -ForegroundColor Cyan
Write-Information "SLACK MESSAGE APPROVAL" -ForegroundColor Cyan
Write-Information "========================================" -ForegroundColor Cyan
Write-Information "Channel:  $Channel" -ForegroundColor Yellow
Write-Information "ID:       $channelId" -ForegroundColor Gray
if ($Text) {
    Write-Information "Message:  $Text" -ForegroundColor White
}
if ($FilePath) {
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $fileSize = (Get-Item $FilePath).Length
    $fileSizeKB = [math]::Round($fileSize / 1KB, 1)
    Write-Information "File:     $fileName ($fileSizeKB KB)" -ForegroundColor Magenta
    if ($FileTitle) {
        Write-Information "Title:    $FileTitle" -ForegroundColor Gray
    }
}
if ($ThreadTs) {
    Write-Information "Thread:   $ThreadTs" -ForegroundColor Gray
}
Write-Information "========================================`n" -ForegroundColor Cyan

$confirmation = Read-Host "Send this message? (yes/no)"
if ($confirmation -ne 'yes') {
    Write-Information "✗ Message not sent (user cancelled)" -ForegroundColor Yellow
    exit 0
}

# Prepare request
$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type" = "application/json"
}

# Handle file upload if FilePath provided
if ($FilePath) {
    Write-Information "`nUploading file..." -ForegroundColor Gray
    try {
        # Read file
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        
        # Step 1: Get upload URL
        $uploadHeaders = @{ "Authorization" = "Bearer $env:SLACK_TOKEN"; "Content-Type" = "application/x-www-form-urlencoded" }
        $uploadBody = "filename=$([System.Web.HttpUtility]::UrlEncode($fileName))&length=$($fileBytes.Length)"
        $uploadUrlResponse = Invoke-RestMethod -Uri "https://slack.com/api/files.getUploadURLExternal" -Headers $uploadHeaders -Method Post -Body $uploadBody
        
        if (-not $uploadUrlResponse.ok) {
            Write-Information "`n✗ Failed to get upload URL: $($uploadUrlResponse.error)" -ForegroundColor Red
            exit 1
        }
        
        # Step 2: Upload file bytes
        Write-Information "  Uploading bytes..." -ForegroundColor Gray
        $null = Invoke-WebRequest -Uri $uploadUrlResponse.upload_url -Method Post -ContentType "application/octet-stream" -Body $fileBytes
        
        # Step 3: Complete upload
        Write-Information "  Completing upload..." -ForegroundColor Gray
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
            Write-Information "`n✓ File uploaded successfully!" -ForegroundColor Green
            Write-Information "  Channel: $channelId" -ForegroundColor Yellow
            Write-Information "  File ID: $($result.files[0].id)" -ForegroundColor Yellow
            Write-Information "  Permalink: $($result.files[0].permalink)" -ForegroundColor Cyan
        } else {
            Write-Information "`n✗ Slack API Error: $($result.error)" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Information "`n✗ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Information "`nSending message..." -ForegroundColor Gray
    try {
        $result = Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Headers $headers -Method Post -Body $bodyJson
        
        if ($result.ok) {
            Write-Information "`n✓ Message sent successfully!" -ForegroundColor Green
            Write-Information "  Channel: $($result.channel)" -ForegroundColor Yellow
            Write-Information "  Timestamp: $($result.ts)" -ForegroundColor Yellow
            Write-Information "  Permalink: https://relias-engineering.slack.com/archives/$($result.channel)/p$($result.ts.Replace('.', ''))" -ForegroundColor Cyan
        } else {
            Write-Information "`n✗ Slack API Error: $($result.error)" -ForegroundColor Red
            if ($result.needed) {
                Write-Information "  Required scope: $($result.needed)" -ForegroundColor Yellow
            }
            exit 1
        }
    } catch {
        Write-Information "`n✗ Request failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
