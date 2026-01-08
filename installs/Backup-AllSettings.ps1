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

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$skillRoot = $PSScriptRoot
$startTime = Get-Date

Write-Information "[36m`n========================================`e[0m"
Write-Information "[36m Windows Settings Backup`e[0m"
Write-Information "[90m $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`e[0m"
Write-Information "[36m========================================`n`e[0m"

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

$InformationPreference = 'Continue'

foreach ($task in $backupTasks) {
    Write-Information "[33m[$($task.Name)]`e[0m"
    
    # Check if process is required and running
    if ($task.RequiresProcess) {
        $proc = Get-Process -Name $task.RequiresProcess -ErrorAction SilentlyContinue
        if (-not $proc) {
            Write-Information "[90m  ⊘ Skipped (requires $($task.RequiresProcess) to be running)`e[0m"
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
            Write-Information "[31m  ✗ Error: $_`e[0m"
            $results += [PSCustomObject]@{ Task = $task.Name; Status = "Failed"; Duration = "0s" }
        }
    }
    else {
        Write-Information "[31m  ✗ Script not found: $($task.Script)`e[0m"
        $results += [PSCustomObject]@{ Task = $task.Name; Status = "Not Found"; Duration = "0s" }
    }
    Write-Information ""
}

# Summary
$totalDuration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
Write-Information "[36m========================================`e[0m"
Write-Information "[36m Backup Summary`e[0m"
Write-Information "[36m========================================`e[0m"
$results | Format-Table -AutoSize
Write-Information "[90mTotal time: ${totalDuration}s`e[0m"
Write-Information ""
