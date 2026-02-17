# Search-JiraTickets.ps1
# Searches JIRA tickets using JQL. Returns key, summary, status, priority, assignee, and URL.
# Requires ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables.
param(
    [Parameter(Mandatory)]
    [string]$JQL,

    [int]$MaxResults = 25
)

$baseUrl = "https://relias.atlassian.net"
$email   = $env:ATLASSIAN_EMAIL
$token   = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables."
    exit 1
}

$auth    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; "Content-Type" = "application/json" }

$body = @{
    jql        = $JQL
    maxResults = $MaxResults
    fields     = @("key", "summary", "status", "priority", "assignee", "issuetype", "updated")
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod `
        -Uri "$baseUrl/rest/api/3/search/jql" `
        -Headers $headers `
        -Method Post `
        -Body $body `
        -ErrorAction Stop
}
catch {
    Write-Error "JIRA API error: $($_.Exception.Message)"
    exit 1
}

$total = $response.total
Write-Host "Found $total ticket(s) (showing up to $MaxResults):" -ForegroundColor Cyan

$response.issues | ForEach-Object {
    [PSCustomObject]@{
        Key      = $_.key
        Summary  = $_.fields.summary
        Status   = $_.fields.status.name
        Priority = $_.fields.priority.name
        Assignee = $_.fields.assignee.displayName
        Updated  = $_.fields.updated
        URL      = "$baseUrl/browse/$($_.key)"
    }
} | Format-Table -AutoSize

# Emit individual links for easy access
$response.issues | ForEach-Object {
    Write-Host "[$($_.key)] $($_.fields.summary) - $baseUrl/browse/$($_.key)"
}
