$headers = @{
    Authorization = "Bearer $env:SLACK_TOKEN"
    'Content-Type' = 'application/json'
}

# Get messages from #pe-bot-test
$response = Invoke-RestMethod -Uri 'https://slack.com/api/conversations.history?channel=C08H7CG4NTS&limit=1' -Headers $headers -Method Get

if ($response.messages.count -gt 0) {
    $message = $response.messages[0]
    $ts = $message.ts
    
    # Get thread replies
    $threadResponse = Invoke-RestMethod -Uri "https://slack.com/api/conversations.replies?channel=C08H7CG4NTS&ts=$ts" -Headers $headers -Method Get
    
    $threadResponse.messages | ForEach-Object {
        Write-Host "User: $($_.user) | Bot: $($_.bot_id)"
        Write-Host "Text: $($_.text)"
        Write-Host "---"
    }
}
