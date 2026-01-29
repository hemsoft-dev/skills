$headers = @{"Authorization" = "Bearer $($env:SLACK_USER_TOKEN)"}
$channelId = "C08H7CG4NTS"

# Get recent messages
$r = Invoke-RestMethod -Uri "https://slack.com/api/conversations.history?channel=$channelId&limit=5" -Headers $headers

# Find the message with our mention
$parentMsg = $r.messages | Where-Object { $_.text -match "rlms-website" } | Select-Object -First 1

if ($parentMsg -and $parentMsg.thread_ts) {
    Write-Host "Found parent message with thread`n"
    Write-Host "Parent: $($parentMsg.text)`n"

    # Get thread replies
    $threads = Invoke-RestMethod -Uri "https://slack.com/api/conversations.replies?channel=$channelId&ts=$($parentMsg.thread_ts)" -Headers $headers

    Write-Host "Thread replies:"
    foreach ($reply in $threads.messages) {
        if ($reply.ts -ne $reply.thread_ts) {
            Write-Host "`nUser: $($reply.user)"
            Write-Host "Text: $($reply.text)"
        }
    }
} else {
    Write-Host "No thread found yet or message not found"
}
