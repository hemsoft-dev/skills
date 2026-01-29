$headers = @{
    'Authorization' = "Bearer $env:SLACK_TOKEN"
    'Content-Type' = 'application/json'
}

$body = @{
    channel = 'C08H7CG4NTS'
    text = '<@U08GJU7S7BM> How many bereavement days do we have at Relias?'
} | ConvertTo-Json

$result = Invoke-RestMethod -Uri 'https://slack.com/api/chat.postMessage' -Headers $headers -Method Post -Body $body

if ($result.ok) {
    Write-Host 'Posted to #pe-bot-test'
} else {
    Write-Host "Error: $($result.error)"
}
