$token = $env:SLACK_TOKEN
$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
}

$channel = 'C08H7CG4NTS'
$ts = '1769611658.625129'

$response = Invoke-RestMethod -Uri "https://slack.com/api/conversations.replies?channel=$channel&ts=$ts" -Headers $headers -Method Get

if ($response.ok) {
    Write-Host "Thread replies:"
    Write-Host "==============="
    foreach ($message in $response.messages) {
        $user = $message.user
        $text = $message.text
        $username = if ($message.username) { $message.username } else { $message.user }
        Write-Host ""
        Write-Host "User: $username"
        Write-Host "Text: $text"
        Write-Host "---"
    }
} else {
    Write-Host "Error: $($response.error)"
}
