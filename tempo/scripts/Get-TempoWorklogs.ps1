<#
.SYNOPSIS
    Retrieves Tempo worklogs for a specific date with enriched issue titles and account names.

.DESCRIPTION
    Queries the Tempo API to get time entries for the current user on a given date.
    Enriches the output with Jira issue titles and Tempo account names for human-readable results.

.PARAMETER Date
    The date to retrieve worklogs for in yyyy-MM-dd format. Defaults to today.

.EXAMPLE
    .\Get-TempoWorklogs.ps1
    # Gets today's worklogs

.EXAMPLE
    .\Get-TempoWorklogs.ps1 -Date "2026-01-26"
    # Gets worklogs for January 26, 2026

.NOTES
    Requires environment variables:
    - TEMPO_API_TOKEN (system level)
    - ATLASSIAN_EMAIL
    - ATLASSIAN_API_TOKEN
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Date = (Get-Date -Format "yyyy-MM-dd")
)

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

# Get Tempo token from system environment
$tempoToken = [Environment]::GetEnvironmentVariable("TEMPO_API_TOKEN", "Machine")
if (-not $tempoToken) {
    Write-Error "TEMPO_API_TOKEN not found in system environment variables"
    exit 1
}

# Get Atlassian credentials
$atlassianEmail = $env:ATLASSIAN_EMAIL
$atlassianToken = $env:ATLASSIAN_API_TOKEN

if (-not $atlassianEmail -or -not $atlassianToken) {
    Write-Error "ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN environment variables required"
    exit 1
}

# Setup headers
$tempoHeaders = @{
    "Authorization" = "Bearer $tempoToken"
    "Accept"        = "application/json"
}

$authString = "${atlassianEmail}:${atlassianToken}"
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($authString))
$jiraHeaders = @{
    "Authorization" = "Basic $base64Auth"
    "Accept"        = "application/json"
}

$tempoBase = "https://api.tempo.io/4"
$jiraBase = "https://relias.atlassian.net"

# Step 1: Get current user's Jira account ID
Write-Information "`e[36mLooking up your Jira account...`e[0m"
try {
    $currentUser = Invoke-RestMethod -Uri "$jiraBase/rest/api/3/myself" -Headers $jiraHeaders -Method Get
    $accountId = $currentUser.accountId
    $displayName = $currentUser.displayName
    Write-Information "`e[32mFound: $displayName`e[0m"
}
catch {
    Write-Error "Failed to get Jira user: $($_.Exception.Message)"
    exit 1
}

# Step 2: Get account names from Tempo (for enrichment)
Write-Information "`e[36mLoading Tempo accounts...`e[0m"
try {
    $accounts = Invoke-RestMethod -Uri "$tempoBase/accounts" -Headers $tempoHeaders -Method Get
    $accountMap = @{}
    $accounts.results | ForEach-Object { $accountMap[$_.key] = $_.name }
}
catch {
    Write-Warning "Could not load accounts: $($_.Exception.Message)"
    $accountMap = @{}
}

# Step 3: Get worklogs for the specified date
Write-Information "`e[36mFetching worklogs for $Date...`e[0m"
try {
    $worklogs = Invoke-RestMethod -Uri "$tempoBase/worklogs/user/$accountId`?from=$Date&to=$Date" -Headers $tempoHeaders -Method Get
}
catch {
    Write-Error "Failed to get worklogs: $($_.Exception.Message)"
    exit 1
}

if ($worklogs.metadata.count -eq 0) {
    Write-Information "`e[33mNo worklogs found for $Date`e[0m"
    exit 0
}

# Step 4: Get unique issue IDs and fetch their titles from Jira
$issueIds = $worklogs.results | ForEach-Object { $_.issue.id } | Sort-Object -Unique
$issueMap = @{}

Write-Information "`e[36mEnriching with issue titles...`e[0m"
foreach ($issueId in $issueIds) {
    try {
        # Tempo gives us issue ID, we need to get the key and summary from Jira
        $issue = Invoke-RestMethod -Uri "$jiraBase/rest/api/3/issue/$issueId`?fields=key,summary" -Headers $jiraHeaders -Method Get
        $issueMap[$issueId] = @{
            Key     = $issue.key
            Summary = $issue.fields.summary
        }
    }
    catch {
        $issueMap[$issueId] = @{
            Key     = "Unknown"
            Summary = "(Could not retrieve)"
        }
    }
}

# Step 5: Build results
$totalHours = 0
$results = @()

foreach ($entry in ($worklogs.results | Sort-Object startTime)) {
    $hours = [math]::Round($entry.timeSpentSeconds / 3600, 2)
    $totalHours += $hours
    
    $issueId = $entry.issue.id
    $issueInfo = $issueMap[$issueId]
    $issueKey = $issueInfo.Key
    $issueSummary = $issueInfo.Summary
    
    $accountKey = $entry.attributes.values | Where-Object { $_.key -eq "_Account_" } | Select-Object -ExpandProperty value -ErrorAction SilentlyContinue
    $accountName = if ($accountKey -and $accountMap[$accountKey]) { $accountMap[$accountKey] } else { $accountKey }
    
    # Truncate time to HH:mm
    $time = $entry.startTime.Substring(0, 5)
    
    $results += [PSCustomObject]@{
        Time    = $time
        Hours   = $hours
        Issue   = $issueKey
        Title   = $issueSummary
        Account = $accountName
    }
}

# Output header
Write-Information ""
Write-Information "`e[32mTempo Entries for $displayName - $Date`e[0m"
Write-Information ""

# Output table
$results | Format-Table -AutoSize -Property Time, Hours, Issue, Title, Account | Out-String | Write-Information

# Output total
Write-Information "`e[32mTOTAL: $totalHours hours`e[0m"
