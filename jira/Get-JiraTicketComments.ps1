# Get-JiraTicketComments.ps1
# Retrieves comments for a JIRA ticket in chronological order.
# Requires ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables.
param(
    [Parameter(Mandatory)]
    [string]$TicketKey,

    [int]$MaxResults = 20
)

$baseUrl = "https://relias.atlassian.net"
$email   = $env:ATLASSIAN_EMAIL
$token   = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables."
    exit 1
}

$auth    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/json" }

try {
    $response = Invoke-RestMethod `
        -Uri "$baseUrl/rest/api/3/issue/$TicketKey/comment?maxResults=$MaxResults&orderBy=+created" `
        -Headers $headers `
        -Method Get `
        -ErrorAction Stop
}
catch {
    $status = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { $null }
    if ($status -eq 404) {
        Write-Error "Ticket '$TicketKey' not found."
    } else {
        Write-Error "JIRA API error ($status): $($_.Exception.Message)"
    }
    exit 1
}

$total = $response.total
$ticketUrl = "$baseUrl/browse/$TicketKey"
Write-Host "$TicketKey has $total comment(s):" -ForegroundColor Cyan

$response.comments | ForEach-Object {
    $author  = $_.author.displayName
    $created = $_.created
    # Extract plain text from Atlassian Document Format body
    $text = ($_.body.content | ForEach-Object {
        $_.content | ForEach-Object { $_.text }
    }) -join " "
    Write-Host "`n--- $author ($created) ---" -ForegroundColor Yellow
    Write-Host $text
}

Write-Host "`nLink: $ticketUrl"
