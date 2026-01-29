$userHeaders = @{"Authorization" = "Bearer $($env:SLACK_USER_TOKEN)"}
$botHeaders = @{"Authorization" = "Bearer $($env:SLACK_TOKEN)"}
$channelId = "C08H7CG4NTS"

Write-Host "Trying with bot token:`n"
$r = Invoke-RestMethod -Uri "https://slack.com/api/conversations.history?channel=$channelId&limit=10" -Headers $botHeaders

if ($r.ok) {
    Write-Host "Success! Messages found: $($r.messages.Count)"
    foreach ($msg in $r.messages) {
        Write-Host "`nTS: $($msg.ts)"
        Write-Host "Text: $($msg.text)"
        Write-Host "Reply Count: $($msg.reply_count)"
        Write-Host "Thread TS: $($msg.thread_ts)"
    }
} else {
    Write-Host "Error: $($r.error)"
}
