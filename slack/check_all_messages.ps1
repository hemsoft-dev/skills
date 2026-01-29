$headers = @{"Authorization" = "Bearer $($env:SLACK_USER_TOKEN)"}
$channelId = "C08H7CG4NTS"

# Get recent messages
$r = Invoke-RestMethod -Uri "https://slack.com/api/conversations.history?channel=$channelId&limit=10" -Headers $headers

Write-Host "Recent messages in #pe-bot-test:`n"
foreach ($msg in $r.messages) {
    Write-Host "TS: $($msg.ts)"
    Write-Host "User: $($msg.user)"
    Write-Host "Text: $($msg.text)"
    Write-Host "Thread TS: $($msg.thread_ts)"
    Write-Host "Reply Count: $($msg.reply_count)"
    Write-Host "---"
}
