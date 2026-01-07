#Requires -Version 7.0
<#
.SYNOPSIS
    Get active Todoist tasks with various filters.

.PARAMETER Filter
    Todoist filter query (today, overdue, p1, p2, etc.)

.PARAMETER Format
    Output format: Table, List, JSON, or Raw (default: Table)

.EXAMPLE
    .\Get-TodoistTasks.ps1 -Filter "today"
    .\Get-TodoistTasks.ps1 -Filter "p1 | p2"
    .\Get-TodoistTasks.ps1 -Filter "overdue" -Format List
#>

param(
    [Parameter(Position = 0)]
    [string]$Filter = 'today',
    
    [Parameter()]
    [ValidateSet('Table', 'List', 'JSON', 'Raw')]
    [string]$Format = 'Table'
)

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
    $uri = "https://api.todoist.com/rest/v2/tasks?filter=$([uri]::EscapeDataString($Filter))"
    $tasks = Invoke-RestMethod -Uri $uri -Headers $headers

    if (-not $tasks -or $tasks.Count -eq 0) {
        Write-Host "No tasks found for filter: $Filter" -ForegroundColor Yellow
        exit 0
    }

    switch ($Format) {
        'Table' {
            $tasks | Select-Object `
                @{N='Task';E={$_.content}}, `
                @{N='Priority';E={"P$($_.priority)"}}, `
                @{N='Due';E={if ($_.due) { $_.due.date } else { '-' }}}, `
                @{N='Project';E={$_.project_id}} `
                | Format-Table -AutoSize
        }
        'List' {
            $tasks | ForEach-Object {
                $priority = if ($_.priority -eq 4) { "[P1]" } elseif ($_.priority -eq 3) { "[P2]" } else { "" }
                $due = if ($_.due) { " (Due: $($_.due.date))" } else { "" }
                Write-Host "• $priority $($_.content)$due"
            }
        }
        'JSON' {
            $tasks | ConvertTo-Json -Depth 5
        }
        'Raw' {
            $tasks
        }
    }

    Write-Verbose "Total tasks: $($tasks.Count)"
    
} catch {
    Write-Error "Failed to fetch tasks: $_"
    exit 1
}
