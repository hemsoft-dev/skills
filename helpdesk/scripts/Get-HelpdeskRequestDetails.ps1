# Get-HelpdeskRequestDetails.ps1
# Lists helpdesk tickets with detailed per-ticket history from JSM status/comment APIs.
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

function ConvertTo-ShortDate([long]$epochMillis) {
    $dt = [DateTimeOffset]::FromUnixTimeMilliseconds($epochMillis).LocalDateTime
    return $dt.ToString("dd/MM/yy")
}

function ConvertTo-DateTimeString([string]$value) {
    if (-not $value) { return "(unknown)" }
    return ([datetime]$value).ToString("yyyy-MM-dd HH:mm")
}

function Show-ServiceDesks {
    Write-Host "Discovering service desks..." -ForegroundColor Cyan

    $sdResponse = Invoke-RestMethod `
        -Uri "$baseUrl/rest/servicedeskapi/servicedesk" `
        -Headers $headers `
        -Method Get `
        -ErrorAction Stop

    if ($sdResponse.values.Count -eq 0) {
        Write-Warning "No service desks found. Check your permissions."
        return
    }

    Write-Host "`nAvailable Service Desks:" -ForegroundColor Cyan
    $sdResponse.values | ForEach-Object {
        Write-Host "  ID: $($_.id) | Key: $($_.projectKey) | Name: $($_.projectName)"
    }
    Write-Host ""
}

function Get-RequestStatusHistory([string]$issueKey) {
    $start = 0
    $pageSize = 50
    $allStatuses = @()

    do {
        $page = Invoke-RestMethod `
            -Uri "$baseUrl/rest/servicedeskapi/request/$issueKey/status?start=$start&limit=$pageSize" `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop

        if ($page.values) {
            $allStatuses += $page.values
        }

        $start += $page.size
    }
    while (-not $page.isLastPage)

    return $allStatuses
}

function Get-RequestComments([string]$issueKey) {
    $start = 0
    $pageSize = 50
    $allComments = @()

    do {
        $page = Invoke-RestMethod `
            -Uri "$baseUrl/rest/servicedeskapi/request/$issueKey/comment?start=$start&limit=$pageSize" `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop

        if ($page.values) {
            $allComments += $page.values
        }

        $start += $page.size
    }
    while (-not $page.isLastPage)

    return $allComments
}

function Build-TimelineEntries($statusHistory, $comments) {
    $entries = @()

    $statusOrdered = $statusHistory | Sort-Object { [datetime]$_.statusDate.jira }
    $previousStatus = $null
    foreach ($statusItem in $statusOrdered) {
        $currentStatus = $statusItem.status
        $changeText = if ($null -eq $previousStatus) {
            "status initialized -> $currentStatus"
        }
        else {
            "status changed: $previousStatus -> $currentStatus"
        }

        $entries += [PSCustomObject]@{
            SortDate = [datetime]$statusItem.statusDate.jira
            Display  = "{0} | {1} | {2}" -f (ConvertTo-DateTimeString $statusItem.statusDate.jira), "(actor unavailable)", $changeText
        }

        $previousStatus = $currentStatus
    }

    $commentOrdered = $comments | Sort-Object { [datetime]$_.created.jira }
    foreach ($comment in $commentOrdered) {
        $who = if ($comment.author.displayName) { $comment.author.displayName } else { "(unknown)" }
        $body = if ($comment.body) { $comment.body } else { "(empty comment)" }
        $body = ($body -replace "`r", " " -replace "`n", " ").Trim()
        if ($body.Length -gt 100) {
            $body = $body.Substring(0, 97) + "..."
        }

        $entries += [PSCustomObject]@{
            SortDate = [datetime]$comment.created.jira
            Display  = "{0} | {1} | comment: {2}" -f (ConvertTo-DateTimeString $comment.created.jira), $who, $body
        }
    }

    return $entries | Sort-Object SortDate
}

function Get-LatestCommentSummary($comments) {
    if (-not $comments -or $comments.Count -eq 0) {
        return "No comment updates yet."
    }

    $latestComment = $comments |
        Sort-Object { [datetime]$_.created.jira } |
        Select-Object -Last 1

    $who = if ($latestComment.author.displayName) { $latestComment.author.displayName } else { "(unknown)" }
    $when = ConvertTo-DateTimeString $latestComment.created.jira
    $body = if ($latestComment.body) { $latestComment.body } else { "(empty comment)" }
    $body = ($body -replace "`r", " " -replace "`n", " ").Trim()
    if ($body.Length -gt 140) {
        $body = $body.Substring(0, 137) + "..."
    }

    return "Last comment by {0} on {1}: {2}" -f $who, $when, $body
}

try {
    if (-not $PSBoundParameters.ContainsKey('ServiceDeskId')) {
        Show-ServiceDesks
    }

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
$sorted = $response.values | Sort-Object { [long]$_.createdDate.epochMillis }
$details = @()

foreach ($item in $sorted) {
    $issueKey      = $item.issueKey
    $summary       = if ($item.summary) { $item.summary } else { "(no summary)" }
    $ticketStatus  = $item.currentStatus.status
    $createdDate   = ConvertTo-ShortDate $item.createdDate.epochMillis
    $lastUpdated   = ConvertTo-ShortDate $item.currentStatus.statusDate.epochMillis
    $reporter      = if ($item.reporter.displayName) { $item.reporter.displayName } else { "(unknown)" }
    $requestType   = if ($item.requestType.name) { $item.requestType.name } else { "(unknown)" }

    $statusHistory = @()
    $comments = @()
    $timelineEntries = @()
    $historyNotice = $null
    $lastChangedBy = $reporter
    $lastCommentSummary = "No comment updates yet."

    try {
        $statusHistory = Get-RequestStatusHistory -issueKey $issueKey
    }
    catch {
        $historyNotice = "Status history unavailable: $($_.Exception.Message)"
    }

    try {
        $comments = Get-RequestComments -issueKey $issueKey
    }
    catch {
        if ($historyNotice) {
            $historyNotice = "$historyNotice | Comments unavailable: $($_.Exception.Message)"
        }
        else {
            $historyNotice = "Comments unavailable: $($_.Exception.Message)"
        }
    }

    $timelineEntries = Build-TimelineEntries -statusHistory $statusHistory -comments $comments
    if ($timelineEntries.Count -gt 0) {
        $lastEntry = $timelineEntries[-1]
        $lastUpdated = $lastEntry.SortDate.ToString("yyyy-MM-dd HH:mm")
    }

    if ($comments.Count -gt 0) {
        $latestComment = $comments |
            Sort-Object { [datetime]$_.created.jira } |
            Select-Object -Last 1
        $lastChangedBy = if ($latestComment.author.displayName) { $latestComment.author.displayName } else { $lastChangedBy }
    }
    elseif ($statusHistory.Count -gt 0) {
        $lastChangedBy = "(status actor unavailable)"
    }

    $lastCommentSummary = Get-LatestCommentSummary -comments $comments

    $shortSummary = $summary
    if ($shortSummary.Length -gt 40) { $shortSummary = $shortSummary.Substring(0, 37) + "..." }

    $details += [PSCustomObject]@{
        Key           = $issueKey
        Summary       = $summary
        ShortSummary  = $shortSummary
        Status        = $ticketStatus
        Created       = $createdDate
        Updated       = $lastUpdated
        LastChangedBy = $lastChangedBy
        LastComment   = $lastCommentSummary
        Reporter      = $reporter
        RequestType   = $requestType
        Timeline      = $timelineEntries
        HistoryNotice = $historyNotice
    }
}

$summaryRows = $details | ForEach-Object {
    [PSCustomObject]@{
        Key           = "$esc]8;;$baseUrl/browse/$($_.Key)$esc\$($_.Key)$esc]8;;$esc\"
        Summary       = $_.ShortSummary
        Status        = $_.Status
        Created       = $_.Created
        Updated       = $_.Updated
        LastChangedBy = $_.LastChangedBy
    }
}

$summaryRows | Format-Table Key, Summary, Status, Created, Updated, LastChangedBy -AutoSize

Write-Host "`nDetailed Ticket History:" -ForegroundColor Cyan

foreach ($ticket in $details) {
    Write-Host ""
    Write-Host "$esc]8;;$baseUrl/browse/$($ticket.Key)$esc\$($ticket.Key)$esc]8;;$esc\ - $($ticket.Summary)" -ForegroundColor White
    Write-Host "  Status: $($ticket.Status)"
    Write-Host "  Created: $($ticket.Created)"
    Write-Host "  Updated: $($ticket.Updated)"
    Write-Host "  Last Changed By: $($ticket.LastChangedBy)"
    Write-Host "  Last Change Comment: $($ticket.LastComment)"
    Write-Host "  Reporter: $($ticket.Reporter)"
    Write-Host "  Request Type: $($ticket.RequestType)"
    Write-Host "  Change History (oldest -> newest):"

    if ($ticket.HistoryNotice) {
        Write-Host "    Notice: $($ticket.HistoryNotice)"
    }

    if (-not $ticket.Timeline -or $ticket.Timeline.Count -eq 0) {
        Write-Host "    (No status or comment history available)"
        continue
    }

    foreach ($entry in $ticket.Timeline) {
        Write-Host "    $($entry.Display)"
    }
}
