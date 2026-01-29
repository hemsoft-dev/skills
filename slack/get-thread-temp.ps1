$headers = @{
    'Authorization' = 'Bearer ' + $env:SLACK_TOKEN
    'Content-Type' = 'application/json'
}

# First get the latest message from pe-bot-test
$messagesUrl = 'https://slack.com/api/conversations.history?channel=C08H7CG4NTS&limit=1'
$messagesResponse = Invoke-RestMethod -Uri $messagesUrl -Headers $headers -Method Get

if ($messagesResponse.ok -and $messagesResponse.messages.Count -gt 0) {
    $latestMessage = $messagesResponse.messages[0]
    $threadTs = $latestMessage.ts

    Write-Host "Latest message timestamp: $threadTs"

    # Now get thread replies
    $threadUrl = "https://slack.com/api/conversations.replies?channel=C08H7CG4NTS&ts=$threadTs"
    $threadResponse = Invoke-RestMethod -Uri $threadUrl -Headers $headers -Method Get

    if ($threadResponse.ok) {
        Write-Host "Thread has $($threadResponse.messages.Count) messages`n"

        # Display each message in the thread
        foreach ($msg in $threadResponse.messages) {
            $user = $msg.user
            if ($msg.bot_id) {
                $user = "BOT: $($msg.bot_id)"
            }
            Write-Host "[$user] $($msg.text)"
            Write-Host "---"
        }
    } else {
        Write-Host "Error getting thread: $($threadResponse.error)"
    }
} else {
    Write-Host "Error getting messages: $($messagesResponse.error)"
}
