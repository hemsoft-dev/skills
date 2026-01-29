$headers = @{
    'Authorization' = 'Bearer ' + $env:SLACK_TOKEN
    'Content-Type' = 'application/json'
}

$body = @{
    channel = 'C08H7CG4NTS'
    text = '<@U08GJU7S7BM> What is your version?'
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri 'https://slack.com/api/chat.postMessage' -Headers $headers -Method Post -Body $body

if ($response.ok) {
    Write-Host 'Message posted successfully to #pe-bot-test'
} else {
    Write-Host "Error: $($response.error)"
}
