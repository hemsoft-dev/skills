#Requires -Version 7.0

<#
.SYNOPSIS
    Get completed Todoist tasks for a specific date.

.PARAMETER Date
    Date to fetch completed tasks for (defaults to today).

.PARAMETER Format
    Output format: Table, List, JSON, or Raw (default: Table)

.EXAMPLE
    .\Get-TodoistCompleted.ps1
    .\Get-TodoistCompleted.ps1 -Date "2026-01-05"
    .\Get-TodoistCompleted.ps1 -Format JSON
#>

param(
    [Parameter(Position = 0)]
    [datetime]$Date = (Get-Date),
    
    [Parameter()]
    [ValidateSet('Table', 'List', 'JSON', 'Raw')]
    [string]$Format = 'Table'
)

$InformationPreference = 'Continue'

$ErrorActionPreference = 'Stop'

# Check for API token
if (-not $env:TODOIST_API_TOKEN) {
    Write-Error "TODOIST_API_TOKEN environment variable not set. Get your token from https://todoist.com/app/settings/integrations/developer"
    exit 1
}

$headers = @{
    Authorization = "Bearer $env:TODOIST_API_TOKEN"
}

try {
    $since = $Date.ToString('yyyy-MM-ddT00:00:00Z')
    $until = $Date.AddDays(1).ToString('yyyy-MM-ddT00:00:00Z')
    $baseUri = "https://api.todoist.com/api/v1/tasks/completed/by_completion_date"

    # Fetch all completed tasks with cursor-based pagination
    $completedItems = @()
    $cursor = $null
    do {
        $uri = "${baseUri}?since=$([uri]::EscapeDataString($since))&until=$([uri]::EscapeDataString($until))&limit=200"
        if ($cursor) { $uri += "&cursor=$([uri]::EscapeDataString($cursor))" }

        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        if ($response.items) { $completedItems += @($response.items) }
        $cursor = $response.next_cursor
    } while ($cursor)
    # The API already filters by completion date range, but double-check
    $completed = $completedItems | Where-Object {
        if ($_.completed_at) {
            $completedDate = [DateTime]::Parse($_.completed_at)
            $completedDate.Date -eq $Date.Date
        }
    }

    if (-not $completed) {
        Write-Information "[33mNo tasks completed on $($Date.ToString('yyyy-MM-dd'))`e[0m"
        exit 0
    }

    switch ($Format) {
        'Table' {
            $completed | Select-Object `
                @{N='Task';E={$_.content}}, `
                @{N='Completed';E={([DateTime]::Parse($_.completed_at)).ToString('HH:mm')}}, `
                @{N='Project';E={$_.project_id}} `
                | Format-Table -AutoSize
        }
        'List' {
            $completed | ForEach-Object {
                Write-Information "[32m✓ $($_.content)`e[0m"
            }
        }
        'JSON' {
            $completed | ConvertTo-Json -Depth 5
        }
        'Raw' {
            $completed
        }
    }

    # Return count for scripting
    Write-Verbose "Total completed: $($completed.Count)"
    
} catch {
    Write-Error "Failed to fetch completed tasks: $_"
    exit 1
}
