$headers = @{"Authorization" = "Bearer $($env:SLACK_TOKEN)"}
$channelId = "C08H7CG4NTS"
$ts = "1769575676.315779"

Write-Host "Getting thread replies for rlms-website message:`n"
$r = Invoke-RestMethod -Uri "https://slack.com/api/conversations.replies?channel=$channelId&ts=$ts" -Headers $headers

if ($r.ok) {
    Write-Host "Thread messages:"
    foreach ($msg in $r.messages) {
        Write-Host "`nTS: $($msg.ts)"
        Write-Host "User: $($msg.user)"
        Write-Host "Text: $($msg.text)"
    }
} else {
    Write-Host "Error: $($r.error)"
}
