# Get-HelpdeskRequests.ps1
# Lists helpdesk tickets (customer requests) from Jira Service Management.
# Requires ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables.
param(
    [int]$ServiceDeskId,

    [ValidateSet("OPEN", "CLOSED", "ALL")]
    [string]$Status = "OPEN",

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
$headers = @{
    Authorization  = "Basic $auth"
    "Content-Type" = "application/json"
    Accept         = "application/json"
}

# Step 1: If no ServiceDeskId provided, list available service desks first
if (-not $PSBoundParameters.ContainsKey('ServiceDeskId')) {
    Write-Host "Discovering service desks..." -ForegroundColor Cyan
    try {
        $sdResponse = Invoke-RestMethod `
            -Uri "$baseUrl/rest/servicedeskapi/servicedesk" `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop

        if ($sdResponse.values.Count -eq 0) {
            Write-Warning "No service desks found. Check your permissions."
            exit 0
        }

        Write-Host "`nAvailable Service Desks:" -ForegroundColor Cyan
        $sdResponse.values | ForEach-Object {
            Write-Host "  ID: $($_.id) | Key: $($_.projectKey) | Name: $($_.projectName)"
        }
        Write-Host ""
    }
    catch {
        Write-Error "Failed to list service desks: $($_.Exception.Message)"
        exit 1
    }
}

# Step 2: Build URI with query parameters
$uriBuilder = [System.UriBuilder]::new("$baseUrl/rest/servicedeskapi/request")
$query = [System.Web.HttpUtility]::ParseQueryString("")
$query["limit"] = $MaxResults.ToString()
$query["expand"] = "participant,status,requestType"

if ($PSBoundParameters.ContainsKey('ServiceDeskId')) {
    $query["serviceDeskId"] = $ServiceDeskId.ToString()
}

if ($Status -ne "ALL") {
    $requestStatus = switch ($Status) {
        "OPEN"   { "OPEN_REQUESTS" }
        "CLOSED" { "CLOSED_REQUESTS" }
    }
    $query["requestStatus"] = $requestStatus
}

$uriBuilder.Query = $query.ToString()

try {
    $response = Invoke-RestMethod `
        -Uri $uriBuilder.Uri.AbsoluteUri `
        -Headers $headers `
        -Method Get `
        -ErrorAction Stop
}
catch {
    Write-Error "JSM API error: $($_.Exception.Message)"
    exit 1
}

$total = $response.size
Write-Host "Found $total request(s) (showing up to $MaxResults):" -ForegroundColor Cyan

if ($response.values.Count -eq 0) {
    Write-Host "No requests found matching the criteria." -ForegroundColor Yellow
    exit 0
}

$esc = [char]27

# Helper: convert Atlassian epoch to DD/MM/YY
function ConvertTo-ShortDate([long]$epochMillis) {
    $dt = [DateTimeOffset]::FromUnixTimeMilliseconds($epochMillis).LocalDateTime
    return $dt.ToString("dd/MM/yy")
}

# Fetch changelog per ticket to find who last changed it
$sorted = $response.values | Sort-Object { [long]$_.createdDate.epochMillis }
$results = foreach ($item in $sorted) {
    $issueKey      = $item.issueKey
    $summary       = $item.summary
    $ticketStatus  = $item.currentStatus.status
    $createdDate   = ConvertTo-ShortDate $item.createdDate.epochMillis
    $lastUpdated   = ConvertTo-ShortDate $item.currentStatus.statusDate.epochMillis
    $lastUpdatedBy = $item.reporter.displayName  # fallback: ticket creator

    # Get changelog to find who last modified the ticket
    try {
        $issue = Invoke-RestMethod `
            -Uri "$baseUrl/rest/api/3/issue/${issueKey}?expand=changelog&fields=updated" `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop

        if ($issue.changelog.histories.Count -gt 0) {
            $lastChange    = $issue.changelog.histories[-1]
            $lastUpdatedBy = $lastChange.author.displayName
            $lastUpdated   = ([datetime]$lastChange.created).ToString("dd/MM/yy")
        }
    }
    catch {
        # keep fallback (reporter)
    }

    if (-not $summary) { $summary = "(no summary)" }
    if ($summary.Length -gt 30) { $summary = $summary.Substring(0, 27) + "..." }

    [PSCustomObject]@{
        Key     = "$esc]8;;$baseUrl/browse/$issueKey$esc\$issueKey$esc]8;;$esc\"
        Summary = $summary
        Status  = $ticketStatus
        Created = $createdDate
        Updated = $lastUpdated
        By      = $lastUpdatedBy
    }
}

$results | Format-Table Key, Summary, Status, Created, Updated, By -AutoSize

# Emit full summaries with links
Write-Host ""
$response.values | Sort-Object { [long]$_.createdDate.epochMillis } | ForEach-Object {
    $summary = $_.summary
    if (-not $summary) { $summary = "(no summary)" }
    Write-Host "$esc]8;;$baseUrl/browse/$($_.issueKey)$esc\$($_.issueKey)$esc]8;;$esc\ $summary"
}
