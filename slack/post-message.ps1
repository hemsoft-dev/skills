$token = $env:SLACK_TOKEN
$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
}

$message = '<@U08GJU7S7BM> Use the slack skill to search for messages regarding rlms-website.'
$body = @{
    channel = 'C08H7CG4NTS'
    text = $message
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri 'https://slack.com/api/chat.postMessage' -Headers $headers -Method Post -Body $body

if ($response.ok) {
    Write-Host 'Message posted successfully to #pe-bot-test'
    Write-Host "Message timestamp: $($response.ts)"
} else {
    Write-Host "Error: $($response.error)"
}
