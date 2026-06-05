<#
.SYNOPSIS
    Lists scheduled tasks with last-run status in chronological order.
.DESCRIPTION
    Displays task name, state, next run time, last run time, and last result for
    scheduled tasks. By default this lists the user's HemSoft scheduled tasks.
    Tasks are sorted chronologically by next run time; tasks with no next run are
    shown after scheduled tasks.
.EXAMPLE
    .\Get-ScheduledTaskStatus.ps1
.EXAMPLE
    .\Get-ScheduledTaskStatus.ps1 -TaskPath "\"
#>
[CmdletBinding()]
param(
    [string]$TaskPath = "\HemSoft\"
)

function Format-ScheduledTaskDate {
    param([datetime]$Value)

    if ($Value -le [datetime]'1900-01-01') {
        return ''
    }

    return $Value.ToString('M/d/yyyy h:mm:ss tt')
}

function Format-ScheduledTaskResult {
    param([long]$Result)

    switch ($Result) {
        0 { 'Success' }
        267009 { 'Running' }
        267010 { 'Ready' }
        267011 { 'Never Run' }
        267012 { 'Queued' }
        267013 { 'Terminated' }
        267014 { 'Disabled' }
        default { '{0} (0x{0:X8})' -f $Result }
    }
}

$tasks = Get-ScheduledTask -TaskPath $TaskPath -ErrorAction SilentlyContinue

if (-not $tasks) {
    Write-Warning "No scheduled tasks found at task path '$TaskPath'."
    return
}

$rows = foreach ($task in $tasks) {
    try {
        $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop
        $hasNextRun = $info.NextRunTime -gt [datetime]'1900-01-01'

        [PSCustomObject]@{
            TaskName    = $task.TaskName
            State       = $task.State
            NextRun     = Format-ScheduledTaskDate -Value $info.NextRunTime
            LastRun     = Format-ScheduledTaskDate -Value $info.LastRunTime
            LastResult  = Format-ScheduledTaskResult -Result $info.LastTaskResult
            NextRunSort = if ($hasNextRun) { $info.NextRunTime } else { [datetime]::MaxValue }
        }
    }
    catch {
        [PSCustomObject]@{
            TaskName    = $task.TaskName
            State       = $task.State
            NextRun     = ''
            LastRun     = ''
            LastResult  = "Info unavailable: $($_.Exception.Message)"
            NextRunSort = [datetime]::MaxValue
        }
    }
}

$rows |
    Sort-Object -Property NextRunSort, TaskName |
    Select-Object TaskName, State, NextRun, LastRun, LastResult |
    Format-Table -AutoSize

