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
    Write-Host "Error: SLACK_TOKEN environment variable not set" -ForegroundColor Red
    Write-Host "Please set it with: [Environment]::SetEnvironmentVariable('SLACK_TOKEN', 'xoxb-...', 'User')" -ForegroundColor Yellow
    exit 1
}

# Validate that at least Text or FilePath is provided
if (-not $Text -and -not $FilePath) {
    Write-Host "Error: Must provide either -Text or -FilePath (or both)" -ForegroundColor Red
    exit 1
}

# Validate file exists if provided
if ($FilePath -and -not (Test-Path $FilePath)) {
    Write-Host "Error: File not found: $FilePath" -ForegroundColor Red
    exit 1
}

# Resolve channel name to ID if needed
$channelId = $Channel
if ($Channel -match '^#') {
    Write-Host "Resolving channel name..." -ForegroundColor Gray
    $channelName = $Channel.TrimStart('#')
    
    $listHeaders = @{ "Authorization" = "Bearer $env:SLACK_TOKEN" }
    $channels = Invoke-RestMethod -Uri "https://slack.com/api/conversations.list?types=public_channel,private_channel&limit=1000" -Headers $listHeaders
    
    $foundChannel = $channels.channels | Where-Object { $_.name -eq $channelName }
    if ($foundChannel) {
        $channelId = $foundChannel.id
        Write-Host "  → $Channel = $channelId" -ForegroundColor Gray
    } else {
        Write-Host "Error: Channel $Channel not found" -ForegroundColor Red
        exit 1
    }
}

# Display approval prompt
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SLACK MESSAGE APPROVAL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Channel:  $Channel" -ForegroundColor Yellow
Write-Host "ID:       $channelId" -ForegroundColor Gray
if ($Text) {
    Write-Host "Message:  $Text" -ForegroundColor White
}
if ($FilePath) {
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $fileSize = (Get-Item $FilePath).Length
    $fileSizeKB = [math]::Round($fileSize / 1KB, 1)
    Write-Host "File:     $fileName ($fileSizeKB KB)" -ForegroundColor Magenta
    if ($FileTitle) {
        Write-Host "Title:    $FileTitle" -ForegroundColor Gray
    }
}
if ($ThreadTs) {
    Write-Host "Thread:   $ThreadTs" -ForegroundColor Gray
}
Write-Host "========================================`n" -ForegroundColor Cyan

$confirmation = Read-Host "Send this message? (yes/no)"
if ($confirmation -ne 'yes') {
    Write-Host "✗ Message not sent (user cancelled)" -ForegroundColor Yellow
    exit 0
}

# Prepare request
$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type" = "application/json"
}

# Handle file upload if FilePath provided
if ($FilePath) {
    Write-Host "`nUploading file..." -ForegroundColor Gray
    try {
        # Read file
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        
        # Step 1: Get upload URL
        $uploadHeaders = @{ "Authorization" = "Bearer $env:SLACK_TOKEN"; "Content-Type" = "application/x-www-form-urlencoded" }
        $uploadBody = "filename=$([System.Web.HttpUtility]::UrlEncode($fileName))&length=$($fileBytes.Length)"
        $uploadUrlResponse = Invoke-RestMethod -Uri "https://slack.com/api/files.getUploadURLExternal" -Headers $uploadHeaders -Method Post -Body $uploadBody
        
        if (-not $uploadUrlResponse.ok) {
            Write-Host "`n✗ Failed to get upload URL: $($uploadUrlResponse.error)" -ForegroundColor Red
            exit 1
        }
        
        # Step 2: Upload file bytes
        Write-Host "  Uploading bytes..." -ForegroundColor Gray
        $null = Invoke-WebRequest -Uri $uploadUrlResponse.upload_url -Method Post -ContentType "application/octet-stream" -Body $fileBytes
        
        # Step 3: Complete upload
        Write-Host "  Completing upload..." -ForegroundColor Gray
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
            Write-Host "`n✓ File uploaded successfully!" -ForegroundColor Green
            Write-Host "  Channel: $channelId" -ForegroundColor Yellow
            Write-Host "  File ID: $($result.files[0].id)" -ForegroundColor Yellow
            Write-Host "  Permalink: $($result.files[0].permalink)" -ForegroundColor Cyan
        } else {
            Write-Host "`n✗ Slack API Error: $($result.error)" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "`n✗ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "`nSending message..." -ForegroundColor Gray
    try {
        $result = Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Headers $headers -Method Post -Body $bodyJson
        
        if ($result.ok) {
            Write-Host "`n✓ Message sent successfully!" -ForegroundColor Green
            Write-Host "  Channel: $($result.channel)" -ForegroundColor Yellow
            Write-Host "  Timestamp: $($result.ts)" -ForegroundColor Yellow
            Write-Host "  Permalink: https://relias-engineering.slack.com/archives/$($result.channel)/p$($result.ts.Replace('.', ''))" -ForegroundColor Cyan
        } else {
            Write-Host "`n✗ Slack API Error: $($result.error)" -ForegroundColor Red
            if ($result.needed) {
                Write-Host "  Required scope: $($result.needed)" -ForegroundColor Yellow
            }
            exit 1
        }
    } catch {
        Write-Host "`n✗ Request failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
