# Get-JiraBoardSprints.ps1
# Retrieves board details and sprint information using the JIRA Agile REST API.
# Can show board info, active/closed/future sprints, and issues in a specific sprint.
# Requires ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables.
param(
    [Parameter(Mandatory)]
    [int]$BoardId,

    [ValidateSet("active", "closed", "future", "all")]
    [string]$SprintState = "active",

    [switch]$IncludeIssues,

    [int]$MaxResults = 50
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

# --- Get Board Details ---
try {
    $board = Invoke-RestMethod `
        -Uri "$baseUrl/rest/agile/1.0/board/$BoardId" `
        -Headers $headers `
        -Method Get `
        -ErrorAction Stop

    Write-Host "Board: $($board.name) (ID: $($board.id), Type: $($board.type))" -ForegroundColor Cyan
    Write-Host "Project: $($board.location.projectName) ($($board.location.projectKey))" -ForegroundColor Cyan
    Write-Host "URL: $baseUrl/jira/software/c/projects/$($board.location.projectKey)/boards/$BoardId" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    $status = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { $null }
    if ($status -eq 404) {
        Write-Error "Board $BoardId not found."
    } else {
        Write-Error "JIRA Agile API error ($status): $($_.Exception.Message)"
    }
    exit 1
}

# --- Get Sprints ---
$sprintUri = "$baseUrl/rest/agile/1.0/board/$BoardId/sprint?maxResults=$MaxResults"
if ($SprintState -ne "all") {
    $sprintUri += "&state=$SprintState"
}

try {
    $sprintResponse = Invoke-RestMethod `
        -Uri $sprintUri `
        -Headers $headers `
        -Method Get `
        -ErrorAction Stop
}
catch {
    Write-Error "Error fetching sprints: $($_.Exception.Message)"
    exit 1
}

$sprints = $sprintResponse.values
if (-not $sprints -or $sprints.Count -eq 0) {
    Write-Host "No $SprintState sprints found for this board." -ForegroundColor Yellow
    exit 0
}

Write-Host "Sprints ($SprintState):" -ForegroundColor Cyan
Write-Host "---" -ForegroundColor Gray

foreach ($sprint in $sprints) {
    $startDate = if ($sprint.startDate) { ([DateTime]$sprint.startDate).ToString("yyyy-MM-dd") } else { "N/A" }
    $endDate   = if ($sprint.endDate)   { ([DateTime]$sprint.endDate).ToString("yyyy-MM-dd")   } else { "N/A" }

    Write-Host ""
    Write-Host "Sprint: $($sprint.name) (ID: $($sprint.id))" -ForegroundColor Green
    Write-Host "  State: $($sprint.state)"
    Write-Host "  Goal: $($sprint.goal)"
    Write-Host "  Start: $startDate | End: $endDate"

    if ($IncludeIssues) {
        # --- Get Issues in Sprint ---
        try {
            $issueUri = "$baseUrl/rest/agile/1.0/sprint/$($sprint.id)/issue?maxResults=$MaxResults&fields=key,summary,status,priority,assignee,issuetype,story_points"
            $issueResponse = Invoke-RestMethod `
                -Uri $issueUri `
                -Headers $headers `
                -Method Get `
                -ErrorAction Stop

            $issues = $issueResponse.issues
            $total  = $issueResponse.total

            Write-Host "  Issues: $total total" -ForegroundColor Yellow

            if ($issues -and $issues.Count -gt 0) {
                # Status breakdown
                $statusGroups = $issues | Group-Object { $_.fields.status.name }
                Write-Host "  Status Breakdown:" -ForegroundColor Yellow
                foreach ($group in $statusGroups | Sort-Object Name) {
                    Write-Host "    $($group.Name): $($group.Count)"
                }

                Write-Host ""
                $issues | ForEach-Object {
                    [PSCustomObject]@{
                        Key      = $_.key
                        Type     = $_.fields.issuetype.name
                        Summary  = $_.fields.summary
                        Status   = $_.fields.status.name
                        Priority = $_.fields.priority.name
                        Assignee = $_.fields.assignee.displayName
                        URL      = "$baseUrl/browse/$($_.key)"
                    }
                } | Format-Table -AutoSize

                # Emit individual links
                $issues | ForEach-Object {
                    Write-Host "[$($_.key)] $($_.fields.summary) - $baseUrl/browse/$($_.key)"
                }
            }
        }
        catch {
            Write-Host "  Error fetching issues: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
