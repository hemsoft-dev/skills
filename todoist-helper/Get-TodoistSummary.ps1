#Requires -Version 7.0

<#
.SYNOPSIS
    Get a comprehensive summary of Todoist tasks.

.PARAMETER Date
    Date to check completed tasks for (defaults to today).

.PARAMETER IncludeCompleted
    Include completed tasks in the summary.

.EXAMPLE
    .\Get-TodoistSummary.ps1
    .\Get-TodoistSummary.ps1 -IncludeCompleted
    .\Get-TodoistSummary.ps1 -Date "2026-01-05"
#>

param(
    [Parameter()]
    [datetime]$Date = (Get-Date),
    
    [Parameter()]
    [switch]$IncludeCompleted
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

# Helper function to get tasks
function Get-Task {
    param([string]$Filter)
    try {
        $uri = "https://api.todoist.com/rest/v2/tasks?filter=$([uri]::EscapeDataString($Filter))"
        return @(Invoke-RestMethod -Uri $uri -Headers $headers)
    } catch {
        return @()
    }
}

# Helper function to get completed tasks
function Get-CompletedTask {
    param([datetime]$TargetDate)
    try {
        $body = @{
            since = $TargetDate.ToString('yyyy-MM-ddT00:00:00')
            limit = 200
        } | ConvertTo-Json

        $response = Invoke-RestMethod `
            -Uri "https://api.todoist.com/sync/v9/completed/get_all" `
            -Headers $headers `
            -Method Post `
            -Body $body `
            -ContentType "application/json"

        return @($response.items | Where-Object {
            if ($_.completed_at) {
                $completedDate = [DateTime]::Parse($_.completed_at)
                $completedDate.Date -eq $TargetDate.Date
            }
        })
    } catch {
        return @()
    }
}

try {
    Write-Information "[36m`n╔════════════════════════════════════════════════════════════════╗`e[0m"
    Write-Information "[36m║         TODOIST SUMMARY - $($Date.ToString('yyyy-MM-dd'))                 ║`e[0m"
    Write-Information "[36m╚════════════════════════════════════════════════════════════════╝`n`e[0m"

    # Get completed tasks if requested
    if ($IncludeCompleted) {
        $completed = Get-CompletedTasks -TargetDate $Date
        Write-Information "[32m$("✓ Completed Today: " -NoNewline)`e[0m"
        Write-Information "[97m$($completed.Count) tasks`e[0m"
        if ($completed.Count -gt 0) {
            $completed | ForEach-Object {
                $time = ([DateTime]::Parse($_.completed_at)).ToString('HH:mm')
                Write-Information "[90m  [$time] $($_.content)`e[0m"
            }
        }
        Write-Information ""
    }

    # Get active tasks
    $today = Get-Tasks -Filter "today"
    Write-Information "[33m$("📅 Due Today: " -NoNewline)`e[0m"
    Write-Information "[97m$($today.Count) tasks`e[0m"
    if ($today.Count -gt 0) {
        $today | ForEach-Object {
            $priority = switch ($_.priority) {
                4 { "[P1]" }
                3 { "[P2]" }
                2 { "[P3]" }
                default { "    " }
            }
            Write-Information "[90m  $priority $($_.content)`e[0m"
        }
    }
    Write-Information ""

    # Get overdue tasks
    $overdue = Get-Tasks -Filter "overdue"
    Write-Information "[31m$("⚠️  Overdue: " -NoNewline)`e[0m"
    Write-Information "[97m$($overdue.Count) tasks`e[0m"
    if ($overdue.Count -gt 0) {
        $overdue | ForEach-Object {
            $dueDate = if ($_.due) { $_.due.date } else { "?" }
            Write-Information "[90m  [Due: $dueDate] $($_.content)`e[0m"
        }
    }
    Write-Information ""

    # Get priority tasks
    $p1 = Get-Tasks -Filter "p1"
    $p2 = Get-Tasks -Filter "p2"
    $totalPriority = $p1.Count + $p2.Count
    
    Write-Information "[35m$("🔥 High Priority: " -NoNewline)`e[0m"
    Write-Information "[97m$totalPriority tasks (P1: $($p1.Count), P2: $($p2.Count))`e[0m"
    if ($p1.Count -gt 0) {
        Write-Information "[35m  P1 Tasks:`e[0m"
        $p1 | ForEach-Object {
            Write-Information "[90m    • $($_.content)`e[0m"
        }
    }
    if ($p2.Count -gt 0) {
        Write-Information "[35m  P2 Tasks:`e[0m"
        $p2 | ForEach-Object {
            Write-Information "[90m    • $($_.content)`e[0m"
        }
    }
    Write-Information ""

    # Summary object for scripting
    $summary = [PSCustomObject]@{
        Date = $Date.ToString('yyyy-MM-dd')
        Completed = if ($IncludeCompleted) { $completed.Count } else { $null }
        Today = $today.Count
        Overdue = $overdue.Count
        P1 = $p1.Count
        P2 = $p2.Count
        TotalPriority = $totalPriority
    }

    return $summary

} catch {
    Write-Error "Failed to generate summary: $_"
    exit 1
}
