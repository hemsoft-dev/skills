#Requires -Version 7.0

<#
.SYNOPSIS
    Get comments/activity for Todoist tasks.

.PARAMETER TaskId
    Specific task ID to get comments for.

.PARAMETER ProjectId
    Get comments for all tasks in a project.

.PARAMETER Format
    Output format: Table, List, JSON, or Raw (default: List)

.EXAMPLE
    .\Get-TodoistComments.ps1 -TaskId 1234567890
    .\Get-TodoistComments.ps1 -ProjectId 2221463722 -Format Table
#>

param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ByTask')]
    [string]$TaskId,
    
    [Parameter(Mandatory = $true, ParameterSetName = 'ByProject')]
    [string]$ProjectId,
    
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
    if ($TaskId) {
        $uri = "https://api.todoist.com/rest/v2/comments?task_id=$TaskId"
        $comments = Invoke-RestMethod -Uri $uri -Headers $headers
        
        if (-not $comments -or $comments.Count -eq 0) {
            Write-Information "[33mNo comments found for task $TaskId`e[0m"
            exit 0
        }
        
        switch ($Format) {
            'Table' {
                $comments | Select-Object `
                    @{N='Date';E={([DateTime]$_.posted_at).ToString('yyyy-MM-dd HH:mm')}}, `
                    @{N='Content';E={$_.content}} `
                    | Format-Table -AutoSize -Wrap
            }
            'List' {
                $comments | ForEach-Object {
                    $date = ([DateTime]$_.posted_at).ToString('yyyy-MM-dd HH:mm')
                    Write-Information "[90m$("[$date] " -NoNewline)`e[0m"
                    Write-Information $_.content
                }
            }
            'JSON' {
                $comments | ConvertTo-Json -Depth 5
            }
            'Raw' {
                $comments
            }
        }
    }
    elseif ($ProjectId) {
        $uri = "https://api.todoist.com/rest/v2/comments?project_id=$ProjectId"
        $comments = Invoke-RestMethod -Uri $uri -Headers $headers
        
        if (-not $comments -or $comments.Count -eq 0) {
            Write-Information "[33mNo comments found for project $ProjectId`e[0m"
            exit 0
        }
        
        # Group by task
        $grouped = $comments | Group-Object -Property task_id
        
        foreach ($group in $grouped) {
            Write-Information "[36m`nTask ID: $($group.Name)`e[0m"
            $group.Group | ForEach-Object {
                $date = ([DateTime]$_.posted_at).ToString('yyyy-MM-dd HH:mm')
                Write-Information "  [$date] $($_.content)"
            }
        }
    }
    
} catch {
    Write-Error "Failed to fetch comments: $_"
    exit 1
}
