<#
.SYNOPSIS
    Search Slack messages using the Slack Web API.

.DESCRIPTION
    Searches Slack workspace messages using the user token (SLACK_USER_TOKEN).
    Supports advanced search syntax including channel filters, date ranges, and user filters.

.PARAMETER Query
    Search query string. Can include advanced syntax:
    - in:#channel-name - Search in specific channel
    - from:@username - Search from specific user
    - after:2024-01-01 - Messages after date
    - before:2024-12-31 - Messages before date
    - has:link - Messages with links
    - has:emoji - Messages with reactions

.PARAMETER Count
    Number of results to return (1-100). Default is 10.

.PARAMETER SortBy
    Sort results by 'timestamp' or 'score'. Default is 'timestamp'.

.PARAMETER SortDirection
    Sort direction: 'desc' (newest first) or 'asc' (oldest first). Default is 'desc'.

.PARAMETER OutputFormat
    Output format: 'Table', 'List', or 'JSON'. Default is 'List'.

.EXAMPLE
    .\Search-SlackMessages.ps1 -Query "GitHub Copilot" -Count 5
    Search for "GitHub Copilot" and return top 5 results.

.EXAMPLE
    .\Search-SlackMessages.ps1 -Query "in:#dev-portal after:2024-12-01" -Count 10
    Search in #dev-portal channel for messages after December 1, 2024.

.EXAMPLE
    .\Search-SlackMessages.ps1 -Query "Cortex support ticket" -OutputFormat Table
    Search for Cortex support tickets and display in table format.

.EXAMPLE
    .\Search-SlackMessages.ps1 -Query "from:@fhemmer deployment" -Count 20
    Search for messages from @fhemmer containing "deployment".

.NOTES
    Requires SLACK_USER_TOKEN environment variable to be set.
    Token must have 'search:read' scope.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Query,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$Count = 10,

    [Parameter(Mandatory = $false)]
    [ValidateSet('timestamp', 'score')]
    [string]$SortBy = 'timestamp',

    [Parameter(Mandatory = $false)]
    [ValidateSet('desc', 'asc')]
    [string]$SortDirection = 'desc',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Table', 'List', 'JSON')]
    [string]$OutputFormat = 'List'
)

# Check for user token
if (-not $env:SLACK_USER_TOKEN) {
    Write-Error "SLACK_USER_TOKEN environment variable not set. Please set it with your user token (xoxp-)."
    exit 1
}

# Prepare headers
$headers = @{
    "Authorization" = "Bearer $env:SLACK_USER_TOKEN"
    "Content-Type"  = "application/json"
}

# URL encode the query
Add-Type -AssemblyName System.Web
$encodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)

# Build API URL
$apiUrl = "https://slack.com/api/search.messages?query=$encodedQuery&count=$Count&sort=$SortBy&sort_dir=$SortDirection"

try {
    Write-Verbose "Searching Slack with query: $Query"
    Write-Verbose "API URL: $apiUrl"
    
    # Make API request
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -ErrorAction Stop

    # Check for API errors
    if (-not $response.ok) {
        Write-Error "Slack API error: $($response.error)"
        exit 1
    }

    Write-Host "`n=== Slack Search Results ===" -ForegroundColor Cyan
    Write-Host "Query: $Query" -ForegroundColor Yellow
    Write-Host "Total matches: $($response.messages.total)" -ForegroundColor Green
    Write-Host "Showing: $($response.messages.matches.Count) results`n" -ForegroundColor Green

    if ($response.messages.matches.Count -eq 0) {
        Write-Host "No messages found." -ForegroundColor Yellow
        return
    }

    # Process and display results based on format
    switch ($OutputFormat) {
        'JSON' {
            $response.messages.matches | ConvertTo-Json -Depth 5
        }
        
        'Table' {
            $results = $response.messages.matches | ForEach-Object {
                $timestamp = [DateTimeOffset]::FromUnixTimeSeconds([double]$_.ts.Split('.')[0]).LocalDateTime
                $preview = $_.text.Substring(0, [Math]::Min(80, $_.text.Length))
                
                [PSCustomObject]@{
                    Date     = $timestamp.ToString('yyyy-MM-dd HH:mm')
                    User     = $_.username
                    Channel  = $_.channel.name
                    Preview  = $preview
                }
            }
            $results | Format-Table -AutoSize
        }
        
        'List' {
            Write-Host "Messages:`n" -ForegroundColor Yellow
            
            foreach ($match in $response.messages.matches) {
                $timestamp = [DateTimeOffset]::FromUnixTimeSeconds([double]$match.ts.Split('.')[0]).LocalDateTime
                $dateStr = $timestamp.ToString('yyyy-MM-dd HH:mm:ss')
                
                Write-Host "[$dateStr] @$($match.username) in #$($match.channel.name)" -ForegroundColor Cyan
                Write-Host "$($match.text)" -ForegroundColor White
                
                # Show permalink if available
                if ($match.permalink) {
                    Write-Host "Link: $($match.permalink)" -ForegroundColor Gray
                }
                
                Write-Host "---" -ForegroundColor DarkGray
                Write-Host ""
            }
        }
    }

    # Summary statistics
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Total matches found: $($response.messages.total)" -ForegroundColor White
    Write-Host "Results displayed: $($response.messages.matches.Count)" -ForegroundColor White
    
    if ($response.messages.pagination.page_count -gt 1) {
        Write-Host "Pages available: $($response.messages.pagination.page_count)" -ForegroundColor Yellow
        Write-Host "Note: Use -Count parameter to retrieve more results per page" -ForegroundColor Yellow
    }

} catch {
    Write-Error "Failed to search Slack: $_"
    Write-Error $_.Exception.Message
    exit 1
}
