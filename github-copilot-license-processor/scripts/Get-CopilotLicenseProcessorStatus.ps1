<#
.SYNOPSIS
    Shows processor mode, queue state, and scheduled-task status.
#>

[CmdletBinding()]
param(
    [string]$TaskName = 'GitHub Copilot License Processor',

    [string]$TaskPath = '\HemSoft\'
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$skillRoot = Split-Path -Parent $PSScriptRoot
$config = Get-Content -LiteralPath (Join-Path $skillRoot 'config.json') -Raw | ConvertFrom-Json
$statePath = Join-Path $skillRoot 'state\processor-state.json'
$state = if (Test-Path -LiteralPath $statePath) {
    Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}
else {
    [pscustomobject]@{
        LastScannedTs = $null
        LastRunAt     = $null
        Pending       = @()
        Completed     = @()
    }
}

$task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
$taskInfo = if ($task) {
    Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath $TaskPath
}
else {
    $null
}

[pscustomobject]@{
    Mode           = $config.Mode
    Organization   = $config.Organization
    SlackChannelId = $config.SlackChannelId
    Pending        = @($state.Pending).Count
    Completed      = @($state.Completed).Count
    LastRunAt      = $state.LastRunAt
    LastScannedTs  = $state.LastScannedTs
    TaskInstalled  = [bool]$task
    TaskState      = if ($task) { $task.State } else { 'NotInstalled' }
    LastTaskRun    = if ($taskInfo) { $taskInfo.LastRunTime } else { $null }
    LastTaskResult = if ($taskInfo) { $taskInfo.LastTaskResult } else { $null }
    NextTaskRun    = if ($taskInfo) { $taskInfo.NextRunTime } else { $null }
} | Format-List

if (@($state.Pending).Count -gt 0) {
    Write-Information 'Pending requests:'
    @($state.Pending) |
        Select-Object Ts, Username, Email, Attempts, LastError |
        Format-Table -AutoSize
}
