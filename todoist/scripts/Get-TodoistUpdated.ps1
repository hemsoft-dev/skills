#Requires -Version 7.0

<#
.SYNOPSIS
    Get Todoist tasks updated today (based on description field date logs).

.DESCRIPTION
    Finds tasks where the description contains today's date in the format:
    "YYYY-MM-DD - DayOfWeek - [log entry]"

.PARAMETER Date
    Date to check for updates (defaults to today).

.PARAMETER Format
    Output format: Table, List, JSON, or Raw (default: List)

.EXAMPLE
    .\Get-TodoistUpdated.ps1
    .\Get-TodoistUpdated.ps1 -Date "2026-01-05"
#>

param(
    [Parameter()]
    [datetime]$Date = (Get-Date),
    
    [Parameter()]
    [ValidateSet('Table', 'List', 'JSON', 'Raw')]
    [string]$Format = 'List'
)

$InformationPreference = 'Continue'

$ErrorActionPreference = 'Stop'

if (-not $env:TODOIST_API_TOKEN) {
    Write-Error "TODOIST_API_TOKEN environment variable not set."
    exit 1
}

$headers = @{
    Authorization = "Bearer $env:TODOIST_API_TOKEN"
}

try {
    # Get all active tasks with cursor-based pagination
    $tasks = @()
    $cursor = $null
    $baseUri = "https://api.todoist.com/api/v1/tasks"
    do {
        $uri = "${baseUri}?limit=200"
        if ($cursor) { $uri += "&cursor=$([uri]::EscapeDataString($cursor))" }

        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        if ($response.results) { $tasks += @($response.results) }
        $cursor = $response.next_cursor
    } while ($cursor)
    
    # Date pattern to search for: "2026-01-06 - Tuesday - "
    $dateStr = $Date.ToString('yyyy-MM-dd')
    
    $updatedTasks = @()
    
    foreach ($task in $tasks) {
        # Check if description contains today's date pattern
        if ($task.description -and $task.description -match [regex]::Escape($dateStr)) {
            # Extract the log entry for today
            $lines = $task.description -split "`n"
            $todayLogs = $lines | Where-Object { $_ -match [regex]::Escape($dateStr) }
            
            $updatedTasks += [PSCustomObject]@{
                TaskId = $task.id
                Content = $task.content
                Project = $task.project_id
                Priority = $task.priority
                LogEntries = $todayLogs
            }
        }
    }
    
    if ($updatedTasks.Count -eq 0) {
        Write-Information "[33mNo updated tasks found for $($Date.ToString('yyyy-MM-dd'))`e[0m"
        exit 0
    }
    
    switch ($Format) {
        'List' {
            Write-Information "[36m`n=== UPDATED TASKS ($($Date.ToString('yyyy-MM-dd'))) ===`e[0m"
            foreach ($task in $updatedTasks) {
                Write-Information "`e[32m`n• `e[97m$($task.Content)`e[0m"
                foreach ($log in $task.LogEntries) {
                    Write-Information "[90m  $log`e[0m"
                }
            }
        }
        'Table' {
            $updatedTasks | Select-Object Content, @{N='Updates';E={$_.LogEntries.Count}}, Project | Format-Table -AutoSize
        }
        'JSON' {
            $updatedTasks | ConvertTo-Json -Depth 5
        }
        'Raw' {
            $updatedTasks
        }
    }
    
    Write-Verbose "Total updated tasks: $($updatedTasks.Count)"
    
} catch {
    Write-Error "Failed to fetch updated tasks: $_"
    exit 1
}
