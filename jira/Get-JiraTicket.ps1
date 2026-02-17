# Get-JiraTicket.ps1
# Retrieves detailed information for a single JIRA ticket by key (e.g., PE-123).
# Requires ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables.
param(
    [Parameter(Mandatory)]
    [string]$TicketKey
)

$baseUrl   = "https://relias.atlassian.net"
$email     = $env:ATLASSIAN_EMAIL
$token     = $env:ATLASSIAN_API_TOKEN

if (-not $email -or -not $token) {
    Write-Error "Set ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables."
    exit 1
}

$auth    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/json" }

$fields = "key,summary,description,status,issuetype,priority,assignee,reporter,created,updated,comment"

try {
    $response = Invoke-RestMethod `
        -Uri "$baseUrl/rest/api/3/issue/$TicketKey`?fields=$fields" `
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

$f        = $response.fields
$ticketUrl = "$baseUrl/browse/$($response.key)"

[PSCustomObject]@{
    Key         = $response.key
    Summary     = $f.summary
    Status      = $f.status.name
    Type        = $f.issuetype.name
    Priority    = $f.priority.name
    Assignee    = $f.assignee.displayName
    Reporter    = $f.reporter.displayName
    Created     = $f.created
    Updated     = $f.updated
    URL         = $ticketUrl
    Description = ($f.description | ConvertTo-Json -Compress)
} | Format-List

Write-Host "`nLink: $ticketUrl"
