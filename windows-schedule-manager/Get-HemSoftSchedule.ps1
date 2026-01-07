<#
.SYNOPSIS
    Lists all HemSoft scheduled tasks in chronological order.
.DESCRIPTION
    Displays task name, state, next run time, last run time, and last result
    for all tasks in the \HemSoft\ task path, sorted by next run time.
.EXAMPLE
    .\Get-HemSoftSchedule.ps1
#>
[CmdletBinding()]
param()

Get-ScheduledTask -TaskPath "\HemSoft\" -ErrorAction SilentlyContinue | ForEach-Object {
    $info = Get-ScheduledTaskInfo -TaskName $_.TaskName -TaskPath $_.TaskPath
    [PSCustomObject]@{
        TaskName   = $_.TaskName
        State      = $_.State
        NextRun    = $info.NextRunTime
        LastRun    = $info.LastRunTime
        LastResult = switch ($info.LastTaskResult) {
            0 { "Success" }
            267011 { "Never Run" }
            default { $info.LastTaskResult }
        }
    }
} | Sort-Object NextRun | Format-Table -AutoSize
