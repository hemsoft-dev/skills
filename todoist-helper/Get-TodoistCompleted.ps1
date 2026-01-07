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
    # Use Sync API to get completed tasks
    $body = @{
        since = $Date.ToString('yyyy-MM-ddT00:00:00')
        limit = 200
    } | ConvertTo-Json

    $response = Invoke-RestMethod `
        -Uri "https://api.todoist.com/sync/v9/completed/get_all" `
        -Headers $headers `
        -Method Post `
        -Body $body `
        -ContentType "application/json"

    # Filter to only tasks completed on the specified date
    $completed = $response.items | Where-Object {
        if ($_.completed_at) {
            $completedDate = [DateTime]::Parse($_.completed_at)
            $completedDate.Date -eq $Date.Date
        }
    }

    if (-not $completed) {
        Write-Host "No tasks completed on $($Date.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
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
                Write-Host "✓ $($_.content)" -ForegroundColor Green
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
