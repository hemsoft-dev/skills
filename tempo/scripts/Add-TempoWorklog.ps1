<#
.SYNOPSIS
    Adds a Tempo worklog entry for a specific issue.

.DESCRIPTION
    Creates a new time entry in Tempo for the current user on a given issue.
    Automatically looks up the issue ID from the issue key and sets the account.

.PARAMETER IssueKey
    The Jira issue key (e.g., "INT-14", "PE-992").

.PARAMETER Hours
    The number of hours to log (supports decimals, e.g., 1.5).

.PARAMETER Date
    The date for the entry in yyyy-MM-dd format. Defaults to today.

.PARAMETER StartTime
    The start time in HH:mm format. Defaults to "08:00".

.PARAMETER Account
    The Tempo account key (e.g., "INT", "GEN-DEV"). Defaults based on issue prefix.

.PARAMETER Description
    Optional description for the worklog. Defaults to "Working on issue {IssueKey}".

.EXAMPLE
    .\Add-TempoWorklog.ps1 -IssueKey "INT-14" -Hours 2
    # Adds 2 hours to INT-14 today at 08:00

.EXAMPLE
    .\Add-TempoWorklog.ps1 -IssueKey "PE-992" -Hours 4 -StartTime "13:00" -Account "GEN-DEV"
    # Adds 4 hours to PE-992 today at 13:00 with GEN-DEV account

.EXAMPLE
    .\Add-TempoWorklog.ps1 -IssueKey "INT-5" -Hours 1.5 -Date "2026-01-27" -Description "Training session"
    # Adds 1.5 hours to INT-5 on a specific date with custom description

.NOTES
    Requires environment variables:
    - TEMPO_API_TOKEN (system level)
    - ATLASSIAN_EMAIL
    - ATLASSIAN_API_TOKEN
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$IssueKey,

    [Parameter(Mandatory = $true, Position = 1)]
    [decimal]$Hours,

    [Parameter(Position = 2)]
    [string]$Date = (Get-Date -Format "yyyy-MM-dd"),

    [Parameter()]
    [string]$StartTime = "08:00",

    [Parameter()]
    [string]$Account,

    [Parameter()]
    [string]$Description
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
    "Content-Type"  = "application/json"
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
Write-Information "`e[36mGetting your Jira account...`e[0m"
try {
    $currentUser = Invoke-RestMethod -Uri "$jiraBase/rest/api/3/myself" -Headers $jiraHeaders -Method Get
    $authorAccountId = $currentUser.accountId
    $displayName = $currentUser.displayName
}
catch {
    Write-Error "Failed to get Jira user: $($_.Exception.Message)"
    exit 1
}

# Step 2: Get issue ID from issue key
Write-Information "`e[36mLooking up issue $IssueKey...`e[0m"
try {
    $issue = Invoke-RestMethod -Uri "$jiraBase/rest/api/3/issue/$IssueKey`?fields=id,summary" -Headers $jiraHeaders -Method Get
    $issueId = [int]$issue.id
    $issueSummary = $issue.fields.summary
    Write-Information "`e[32mFound: $issueSummary`e[0m"
}
catch {
    Write-Error "Failed to get issue $IssueKey : $($_.Exception.Message)"
    exit 1
}

# Step 3: Determine account if not specified
if (-not $Account) {
    # Default account mapping based on issue prefix
    $prefix = ($IssueKey -split "-")[0]
    $Account = switch ($prefix) {
        "INT"   { "INT" }
        "PE"    { "GEN-DEV" }
        "RPLAT" { "GEN-DEV" }
        "RCOMM" { "GEN-DEV" }
        "PORT"  { "GEN-DEV" }
        default { "GEN-DEV" }
    }
    Write-Information "`e[33mUsing default account: $Account`e[0m"
}

# Step 4: Set default description if not provided
if (-not $Description) {
    $Description = "Working on issue $IssueKey"
}

# Step 5: Normalize start time format (API expects HH:mm:ss)
if ($StartTime -match "^\d{1,2}:\d{2}$") {
    # HH:mm format - add seconds
    $StartTime = "${StartTime}:00"
}
elseif ($StartTime -match "^\d{1,2}$") {
    # Just hour - add minutes and seconds
    $StartTime = "${StartTime}:00:00"
}

# Step 6: Build and send the request
$timeSpentSeconds = [int]($Hours * 3600)

$payload = @{
    issueId          = $issueId
    timeSpentSeconds = $timeSpentSeconds
    startDate        = $Date
    startTime        = $StartTime
    authorAccountId  = $authorAccountId
    description      = $Description
    attributes       = @(
        @{
            key   = "_Account_"
            value = $Account
        }
    )
} | ConvertTo-Json -Depth 3

Write-Information "`e[36mCreating worklog...`e[0m"
try {
    $response = Invoke-RestMethod -Uri "$tempoBase/worklogs" -Headers $tempoHeaders -Method Post -Body $payload
    
    Write-Information ""
    Write-Information "`e[32mWorklog created successfully!`e[0m"
    Write-Information ""
    
    # Display result as table
    $result = [PSCustomObject]@{
        Date        = $response.startDate
        Time        = $response.startTime.Substring(0, 5)
        Hours       = $Hours
        Issue       = $IssueKey
        Title       = $issueSummary
        Account     = $Account
        WorklogID   = $response.tempoWorklogId
    }
    
    $result | Format-Table -AutoSize | Out-String | Write-Information
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Failed to create worklog (HTTP $statusCode): $($_.Exception.Message)"
    
    try {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $errorBody = $reader.ReadToEnd()
        Write-Error "API Error: $errorBody"
    }
    catch { }
    
    exit 1
}
