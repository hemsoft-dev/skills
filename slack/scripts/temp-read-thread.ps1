$headers = @{
    'Authorization' = "Bearer $env:SLACK_TOKEN"
    'Content-Type' = 'application/json'
}

# Get the most recent messages from pe-bot-test
$result = Invoke-RestMethod -Uri 'https://slack.com/api/conversations.history?channel=C08H7CG4NTS&limit=5' -Headers $headers

# Find the message we just posted
$myMessage = $result.messages | Where-Object { $_.text -like '*bereavement days*' } | Select-Object -First 1

if ($myMessage) {
    Write-Host "Found message with ts: $($myMessage.ts)"

    # Get replies to this message
    $threadResult = Invoke-RestMethod -Uri "https://slack.com/api/conversations.replies?channel=C08H7CG4NTS&ts=$($myMessage.ts)" -Headers $headers

    if ($threadResult.ok) {
        $replies = $threadResult.messages | Where-Object { $_.ts -ne $myMessage.ts }
        if ($replies) {
            Write-Host "Thread replies:"
            foreach ($reply in $replies) {
                Write-Host "---"
                Write-Host "$($reply.text)"
            }
        } else {
            Write-Host "No replies in thread yet"
        }
    }
} else {
    Write-Host "Could not find the message"
}
