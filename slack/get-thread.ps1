$token = $env:SLACK_TOKEN
$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
}

# Get the message thread
$result = Invoke-RestMethod -Uri 'https://slack.com/api/conversations.replies?channel=C08H7CG4NTS&ts=1769512149.165509&limit=100' -Headers $headers -Method Get
if ($result.ok) {
    Write-Host "Found $($result.messages.Count) messages in thread"
    $result.messages | ForEach-Object {
        Write-Host "---"
        Write-Host "User: $($_.user)"
        Write-Host "Text: $($_.text)"
        Write-Host "---"
    }
} else {
    Write-Host "Error: $($result.error)"
}
