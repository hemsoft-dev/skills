$token = $env:SLACK_TOKEN

$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
}

$body = @{
    channel = '#pe-bot-test'
    text = '<@U08GJU7S7BM> What can you help me with?'
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri 'https://slack.com/api/chat.postMessage' -Headers $headers -Method Post -Body $body
$response
