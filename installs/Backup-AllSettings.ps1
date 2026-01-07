<#
.SYNOPSIS
    Master backup script for all Windows settings and configurations.
.DESCRIPTION
    Runs all individual backup scripts to keep the windows-install skill current.
    Designed to be run nightly via scheduled task.
.EXAMPLE
    .\Backup-AllSettings.ps1
.EXAMPLE
    .\Backup-AllSettings.ps1 -Verbose
#>
$InformationPreference = 'Continue'

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$skillRoot = $PSScriptRoot
$startTime = Get-Date

Write-Information "`n========================================" -ForegroundColor Cyan
Write-Information " Windows Settings Backup" -ForegroundColor Cyan
Write-Information " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Information "========================================`n" -ForegroundColor Cyan

$results = @()

# Define all backup tasks
$backupTasks = @(
    @{
        Name = "AutoHotkey"
        Script = Join-Path $skillRoot "autohotkey\Backup-AutoHotkey.ps1"
    },
    @{
        Name = "Directory Opus"
        Script = Join-Path $skillRoot "directory-opus\Backup-DOpusConfig.ps1"
        RequiresProcess = "dopus"
    },
    @{
        Name = "Git & SSH"
        Script = Join-Path $skillRoot "git\Backup-GitConfig.ps1"
    },
    @{
        Name = "PowerShell Profiles"
        Script = Join-Path $skillRoot "powershell\Backup-PowerShellProfiles.ps1"
    },
    @{
        Name = "VS Code Insiders"
        Script = Join-Path $skillRoot "vscode-insiders\Backup-VSCodeInsiders.ps1"
    },
    @{
        Name = "Windows Terminal"
        Script = Join-Path $skillRoot "windows-terminal\Backup-WindowsTerminal.ps1"
    },
    @{
        Name = "Hardware Report"
        Script = "D:\github\HemSoft\notes\Franz PC 2026\Get-HardwareReport.ps1"
    }
)

foreach ($task in $backupTasks) {
    Write-Information "[$($task.Name)]" -ForegroundColor Yellow
    
    # Check if process is required and running
    if ($task.RequiresProcess) {
        $proc = Get-Process -Name $task.RequiresProcess -ErrorAction SilentlyContinue
        if (-not $proc) {
            Write-Information "  ⊘ Skipped (requires $($task.RequiresProcess) to be running)" -ForegroundColor DarkGray
            $results += [PSCustomObject]@{ Task = $task.Name; Status = "Skipped"; Duration = "0s" }
            Write-Information ""
            continue
        }
    }
    
    if (Test-Path $task.Script) {
        $taskStart = Get-Date
        try {
            & $task.Script
            $duration = [math]::Round(((Get-Date) - $taskStart).TotalSeconds, 1)
            $results += [PSCustomObject]@{ Task = $task.Name; Status = "Success"; Duration = "${duration}s" }
        }
        catch {
            Write-Information "  ✗ Error: $_" -ForegroundColor Red
            $results += [PSCustomObject]@{ Task = $task.Name; Status = "Failed"; Duration = "0s" }
        }
    }
    else {
        Write-Information "  ✗ Script not found: $($task.Script)" -ForegroundColor Red
        $results += [PSCustomObject]@{ Task = $task.Name; Status = "Not Found"; Duration = "0s" }
    }
    Write-Information ""
}

# Summary
$totalDuration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
Write-Information "========================================" -ForegroundColor Cyan
Write-Information " Backup Summary" -ForegroundColor Cyan
Write-Information "========================================" -ForegroundColor Cyan
$results | Format-Table -AutoSize
Write-Information "Total time: ${totalDuration}s" -ForegroundColor Gray
Write-Information ""
