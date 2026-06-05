<#
.SYNOPSIS
    Lists all HemSoft scheduled tasks in chronological order.
.DESCRIPTION
    Compatibility wrapper for Get-ScheduledTaskStatus.ps1.
.EXAMPLE
    .\Get-HemSoftSchedule.ps1
#>
[CmdletBinding()]
param()

& (Join-Path $PSScriptRoot 'Get-ScheduledTaskStatus.ps1') -TaskPath "\HemSoft\"
