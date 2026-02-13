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
    $baseUri = "https://api.todoist.com/api/v1/tasks/filter"

    # Fetch tasks with cursor-based pagination
    $tasks = @()
    $cursor = $null
    do {
        $uri = "${baseUri}?query=$([uri]::EscapeDataString($Filter))&limit=200"
        if ($cursor) { $uri += "&cursor=$([uri]::EscapeDataString($cursor))" }

        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        if ($response.results) { $tasks += @($response.results) }
        $cursor = $response.next_cursor
    } while ($cursor)

    if (-not $tasks -or $tasks.Count -eq 0) {
        Write-Information "[33mNo tasks found for filter: $Filter`e[0m"
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
                Write-Information "• $priority $($_.content)$due"
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
