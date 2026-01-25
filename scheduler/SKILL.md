---
name: scheduler
description: V1.1 - Expert in managing Windows Scheduled Tasks using PowerShell cmdlets (Get, Register, Unregister, Start, Stop).
---

# Scheduler

Manage Windows Task Scheduler tasks using the `ScheduledTasks` PowerShell module. This skill provides expertise in listing, creating, modifying, and removing scheduled tasks on a Windows system.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Core Cmdlets

- `Get-ScheduledTask`: List all or specific tasks.
- `Get-ScheduledTaskInfo`: Get runtime information (LastRunTime, LastTaskResult).
- `New-ScheduledTaskAction`: Define the executable and arguments.
- `New-ScheduledTaskTrigger`: Define the schedule (Once, Daily, Weekly, AtLogon, etc.).
- `Register-ScheduledTask`: Create or update a task definition.
- `Unregister-ScheduledTask`: Remove a task.
- `Start-ScheduledTask` / `Stop-ScheduledTask`: Manually control task execution.
- `Enable-ScheduledTask` / `Disable-ScheduledTask`: Toggle task state.

## Common Workflows

### Listing Tasks

```powershell
# List all tasks in the root folder
Get-ScheduledTask -TaskPath "\"

# Find a specific task by name
Get-ScheduledTask -TaskName "MyTask"
```

### Creating a Task

```powershell
$Action = New-ScheduledTaskAction -Execute "C:\Path\To\App.exe" -Argument "--scan"
$Trigger = New-ScheduledTaskTrigger -Daily -At 3am
Register-ScheduledTask -TaskName "DailyScan" -Action $Action -Trigger $Trigger -Description "Runs a daily scan"
```

### Removing a Task

```powershell
Unregister-ScheduledTask -TaskName "DailyScan" -Confirm:$false
```

### Checking Task Status

```powershell
Get-ScheduledTaskInfo -TaskName "DailyScan" | Select-Object LastRunTime, LastTaskResult, NextRunTime
```

### Advanced Task Creation (Admin/Settings)

```powershell
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File 'C:\Scripts\Backup.ps1'"
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName "SystemBackup" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings
```

### Modifying an Existing Task (Requires Elevation)

`Set-ScheduledTask` often fails to update triggers due to permission issues. The reliable approach is to **unregister and re-register** in an elevated session:

```powershell
# Run this in an elevated PowerShell session
Start-Process powershell -Verb RunAs -ArgumentList "-Command", @"
`$old = Get-ScheduledTask -TaskName 'MyTask' -TaskPath '\HemSoft\'
`$action = `$old.Actions[0]
`$desc = `$old.Description
Unregister-ScheduledTask -TaskName 'MyTask' -TaskPath '\HemSoft\' -Confirm:`$false
`$newAction = New-ScheduledTaskAction -Execute `$action.Execute -Argument `$action.Arguments
`$newTrigger = New-ScheduledTaskTrigger -Daily -At '6:05 AM'
`$newSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'MyTask' -TaskPath '\HemSoft\' -Action `$newAction -Trigger `$newTrigger -Settings `$newSettings -Description `$desc
Write-Host 'Done - press Enter'; Read-Host
"@
```

**Why this works**: Task Scheduler stores triggers with embedded timestamps. `Set-ScheduledTask` may silently fail to update triggers without admin elevation. The unregister/re-register pattern ensures a clean slate.

## Best Practices

1. **Task Paths**: Use `-TaskPath` to organize tasks. For this user, the default path is `\HemSoft\`. **Always verify the path with the user before creating a task.**
2. **Principals**: Use `New-ScheduledTaskPrincipal` to specify the user account and run level (e.g., `-RunLevel Highest` for admin tasks).
3. **Settings**: Use `New-ScheduledTaskSettingsSet` to configure advanced options like `AllowStartIfOnBatteries` or `ExecutionTimeLimit`.
4. **Validation**: Always check if a task exists before attempting to modify or unregister it to avoid errors.
5. **PowerShell Tasks**: When running PowerShell scripts, use `-Execute "powershell.exe"` and `-Argument "-ExecutionPolicy Bypass -File 'C:\Path\To\Script.ps1'"`. **CRITICAL: `-ExecutionPolicy` MUST come BEFORE `-File`**, otherwise it is ignored and the script may fail silently (error code `4294770688`). Also set `-WorkingDirectory` if the script uses relative paths or git commands.
6. **Error Handling**: Wrap task operations in `try/catch` blocks in scripts to handle permission or "already exists" errors.
7. **Organization**: Avoid placing tasks in the root folder (`\`). Use structured paths to keep the system clean.
8. **Modifying Tasks Requires Elevation**: `Set-ScheduledTask` often silently fails without admin rights. Use `Start-Process powershell -Verb RunAs` to launch an elevated session for modifications.
9. **Trigger Updates**: To reliably change a task's schedule, unregister and re-register the task rather than using `Set-ScheduledTask` on the trigger. The trigger's `StartBoundary` timestamp can be stubborn.
10. **Avoid schtasks.exe**: The legacy `schtasks /change` command requires password input. Prefer PowerShell cmdlets with elevation.
11. **ALWAYS List Schedule After Changes**: After creating, modifying, or deleting any scheduled task, **always** run the schedule listing script to confirm the change and show the user the full schedule:

```powershell
& "c:\Users\User\.claude\skills\scheduler\scripts\Get-HemSoftSchedule.ps1"
```
