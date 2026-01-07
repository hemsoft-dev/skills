#Requires -Version 7.0
$InformationPreference = 'Continue'

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

$ErrorActionPreference = 'Stop'

if (-not $env:TODOIST_API_TOKEN) {
    Write-Error "TODOIST_API_TOKEN environment variable not set."
    exit 1
}

$headers = @{
    Authorization = "Bearer $env:TODOIST_API_TOKEN"
}

try {
    # Get all active tasks
    $tasks = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/tasks" -Headers $headers
    
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
        Write-Information "No updated tasks found for $($Date.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
        exit 0
    }
    
    switch ($Format) {
        'List' {
            Write-Information "`n=== UPDATED TASKS ($($Date.ToString('yyyy-MM-dd'))) ===" -ForegroundColor Cyan
            foreach ($task in $updatedTasks) {
                Write-Information "`n• " -NoNewline -ForegroundColor Green
                Write-Information "$($task.Content)" -ForegroundColor White
                foreach ($log in $task.LogEntries) {
                    Write-Information "  $log" -ForegroundColor Gray
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
