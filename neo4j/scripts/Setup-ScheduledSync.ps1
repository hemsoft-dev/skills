[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='User-facing script requires colored output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='Simple tool with default credentials')]
param()
<#
.SYNOPSIS
    Creates a Windows Scheduled Task to sync skills to Neo4j daily.

.DESCRIPTION
    Sets up a scheduled task that runs the Neo4j sync script daily at 9 AM.
    Requires administrator privileges.

.PARAMETER Time
    Time to run the sync (default: 9am)

.EXAMPLE
    .\Setup-ScheduledSync.ps1

.EXAMPLE
    .\Setup-ScheduledSync.ps1 -Time "2pm"
#>

[CmdletBinding()]
param(
    [string]$Time = "9am"
)

$syncScript = "$env:USERPROFILE\.claude\skills\neo4j\scripts\Sync-SkillsToNeo4j.ps1"
$taskName = "Neo4j Skills Sync"

Write-Host "🔧 Setting up scheduled task for Neo4j sync" -ForegroundColor Cyan
Write-Host "Schedule: Daily at $Time" -ForegroundColor Gray

# Check for admin privileges

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "This script requires administrator privileges."
    Write-Host "`nRun PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# Remove existing task if it exists

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create the scheduled task

$action = New-ScheduledTaskAction `
    -Execute 'pwsh.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -File `"$syncScript`""

$trigger = New-ScheduledTaskTrigger -Daily -At $Time

$settings = New-ScheduledTaskSettingsSet `
-AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
-StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
-LogonType S4U `
    -RunLevel Limited

Register-ScheduledTask `
-TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
-Settings $settings `
    -Principal $principal `
    -Description "Automatically sync Claude skills to Neo4j graph database" | Out-Null

Write-Host "✅ Scheduled task created: $taskName" -ForegroundColor Green
Write-Host "`nTask will run daily at $Time" -ForegroundColor Gray
Write-Host "`nManage task:" -ForegroundColor White
Write-Host "  View:    Get-ScheduledTask -TaskName '$taskName'" -ForegroundColor Gray
Write-Host "  Run now: Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor Gray
Write-Host "  Remove:  Unregister-ScheduledTask -TaskName '$taskName'" -ForegroundColor Gray
