---
name: windows-optimizer
description: V1.3 - Expert on Windows performance optimization, diagnostics, and troubleshooting for CPU, memory, disk, GPU, handle leaks, and startup management.
---

# Windows Optimizer

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Diagnose and optimize Windows performance issues including slowdowns, stuttering, memory pressure, disk space, and resource leaks.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Key Takeaways

### Handle Leaks = Silent Killer

- **Symptom**: Mouse stuttering, gradual system slowdown, UI lag
- **Cause**: Apps accumulating OS handles without releasing them
- **Threshold**: >5000 handles is concerning, >10000 is critical
- **Worst Offenders**: NZXT CAM, NordVPN, Snagit, Razer apps, Electron apps
- **Fix**: Restart the offending app (don't need full reboot)

### Startup Bloat

- Most PCs have 15-25+ startup apps; 10-12 is healthier
- Each adds boot time and background resource usage
- Safe to disable: Printer monitors, updaters, chat apps, virtual cams
- Keep: Hardware drivers (Logitech, Razer), VPN, cloud sync

### C: Drive Space Hogs

- **LLM Models** (.ollama, .lmstudio): Often 50-250+ GB, easily forgotten
- **Downloads folder**: Accumulates indefinitely
- **Dev caches** (.nuget, npm-cache, .cache): 10-30+ GB, safe to clear
- **Temp files**: Can reach 10+ GB
- **Videos/Media**: Should live on secondary drives

### User Profile Cache Folders (Safe to Clear)

| Folder | Typical Size | Notes |
|--------|--------------|-------|
| `.cache/huggingface` | 1-10+ GB | ML models, re-downloads when needed |
| `.cache/puppeteer` | 0.5-1 GB | Chromium binaries, re-downloads |
| `.cache/whisper` | 1-7 GB | Speech models - **keep if actively using** |
| `.nuget/packages` | 2-10 GB | NuGet cache, safe to clear |
| `.npm/_cacache` | 1-5 GB | npm cache, safe to clear |
| `.bun/install/cache` | 0.5-2 GB | Bun package cache |

### Quick Wins Checklist

1. Check handle counts → restart leakers
2. Review startup programs → disable unnecessary ones
3. Clean dev caches (npm, nuget)
4. Check for forgotten LLM models
5. Clear temp files and browser caches

## Scripts

Ready-to-run PowerShell scripts in `~/.claude/skills/windows-optimizer/scripts/`:

| Script | Purpose |
|--------|---------|
| `Get-SystemHealth.ps1` | Comprehensive system health report (CPU, RAM, disk, GPU, handles) |
| `Find-HandleLeaks.ps1` | Detect and auto-restart processes with handle leaks |
| `Clear-TempFiles.ps1` | Clean temp files, caches, and Windows Update leftovers |
| `Manage-Startup.ps1` | List, enable, or disable startup programs |
| `Find-LargeFiles.ps1` | Find large files consuming disk space |
| `Find-SpaceHogs.ps1` | Analyze user profile for large moveable/cleanable folders |
| `Get-Sysinternals.ps1` | Download Sysinternals tools on demand |
| `Watch-Performance.ps1` | Real-time performance monitoring |
| `Invoke-QuickTuneup.ps1` | One-command system maintenance |
| `Manage-OllamaModels.ps1` | List and bulk-remove Ollama LLM models |

### Usage Examples

```powershell
# Run from skill directory
$skillPath = "$env:USERPROFILE\.claude\skills\windows-optimizer\scripts"

# Full system health check
& "$skillPath\Get-SystemHealth.ps1" -Detailed

# Find and auto-fix handle leaks
& "$skillPath\Find-HandleLeaks.ps1" -AutoFix

# Clean temp files including browser caches
& "$skillPath\Clear-TempFiles.ps1" -IncludeBrowserCache

# List startup programs
& "$skillPath\Manage-Startup.ps1" -Action List

# Disable a startup program
& "$skillPath\Manage-Startup.ps1" -Action Disable -Name "Discord"

# Find files larger than 500MB
& "$skillPath\Find-LargeFiles.ps1" -MinSizeMB 500

# Download and run Process Explorer
& "$skillPath\Get-Sysinternals.ps1" -Tool ProcessExplorer -Run

# Monitor performance for 60 seconds
& "$skillPath\Watch-Performance.ps1" -Interval 1 -Duration 60 -IncludeGPU

# Quick tune-up (clean temp, check leaks, report status)
& "$skillPath\Invoke-QuickTuneup.ps1" -Full

# Analyze space hogs in user profile
& "$skillPath\Find-SpaceHogs.ps1"

# List Ollama models and their sizes
& "$skillPath\Manage-OllamaModels.ps1" -Action List

# Remove all Ollama models
& "$skillPath\Manage-OllamaModels.ps1" -Action RemoveAll
```

## Quick Diagnostics

### System Overview

```powershell
# One-liner system health check
$cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1).CounterSamples[0].CookedValue
$os = Get-CimInstance Win32_OperatingSystem
$memPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
$memGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
"CPU: $([math]::Round($cpu,1))% | RAM: $memGB GB ($memPct%)"
```

### Top Resource Consumers

```powershell
# Top 10 by CPU (cumulative)
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, Id, CPU, @{N='MemMB';E={[math]::Round($_.WorkingSet64/1MB,1)}}, Handles

# Top 10 by Memory
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id, @{N='MemMB';E={[math]::Round($_.WorkingSet64/1MB,1)}}

# Top 10 by Handle Count (detect leaks)
Get-Process | Sort-Object Handles -Descending | Select-Object -First 10 Name, Id, Handles, @{N='MemMB';E={[math]::Round($_.WorkingSet64/1MB,1)}}
```

### Handle Leak Detection

Handle counts above **5000** indicate potential leaks. Common offenders: NZXT CAM, Razer Synapse, Discord, Electron apps.

```powershell
# Find processes with high handle counts
Get-Process | Where-Object { $_.Handles -gt 3000 } | Sort-Object Handles -Descending | Select-Object Name, Id, Handles
```

### GPU Status (NVIDIA)

```powershell
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu --format=csv,noheader
```

### Disk I/O Check

```powershell
Get-Counter '\PhysicalDisk(*)\% Disk Time' -SampleInterval 1 | ForEach-Object { 
    $_.CounterSamples | Where-Object { $_.InstanceName -ne '_total' -and $_.CookedValue -gt 1 } | 
    Select-Object InstanceName, @{N='DiskTime%';E={[math]::Round($_.CookedValue,1)}} 
}
```

### Memory Commit Charge

```powershell
(Get-Counter '\Memory\Committed Bytes', '\Memory\Commit Limit', '\Memory\Available MBytes').CounterSamples | 
Select-Object Path, @{N='GB';E={[math]::Round($_.CookedValue/1GB,2)}}
```

## Startup Management

### List Startup Programs

```powershell
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" | 
Select-Object * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider
```

### Remove Startup Entry

```powershell
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "{APP_NAME}"
```

### Disable via Task Manager (alternative)

```powershell
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location
```

## Process Management

### Kill Process

```powershell
Stop-Process -Name "{PROCESS_NAME}" -Force
```

### Restart Process (kill and relaunch)

```powershell
Stop-Process -Name "{PROCESS_NAME}" -Force; Start-Process "{EXE_PATH}"
```

## Disk Space Cleanup

### Analyze Disk Usage

```powershell
Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{N='UsedGB';E={[math]::Round($_.Used/1GB,2)}}, @{N='FreeGB';E={[math]::Round($_.Free/1GB,2)}}, @{N='TotalGB';E={[math]::Round(($_.Used+$_.Free)/1GB,2)}}
```

### Large Files Finder

```powershell
Get-ChildItem -Path C:\ -Recurse -File -ErrorAction SilentlyContinue | 
Where-Object { $_.Length -gt 500MB } | 
Sort-Object Length -Descending | 
Select-Object -First 20 @{N='SizeMB';E={[math]::Round($_.Length/1MB,0)}}, FullName
```

### Folder Size Analysis (like `du` or `tree`)

```powershell
# Recursive folder sizes (1 GB+ only, sorted)
Get-ChildItem -Directory "C:\Users\$env:USERNAME" | ForEach-Object { 
    $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    [PSCustomObject]@{
        Folder = $_.Name
        SizeGB = [math]::Round($size / 1GB, 2)
        Bytes = $size
    }
} | Where-Object { $_.SizeGB -ge 1 } | Sort-Object Bytes -Descending | Select-Object Folder, SizeGB | Format-Table -AutoSize

# Reusable function with configurable threshold
function Get-FolderSize {
    param([string]$Path = ".", [decimal]$MinGB = 0)
    Get-ChildItem $Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                 Measure-Object Length -Sum).Sum
        [PSCustomObject]@{
            Folder = $_.Name
            SizeGB = [math]::Round($size / 1GB, 2)
            Bytes = $size
        }
    } | Where-Object { $_.SizeGB -ge $MinGB } | Sort-Object Bytes -Descending | Select-Object Folder, SizeGB
}
# Usage: Get-FolderSize "C:\Users\franz" -MinGB 1
```

### Selective Cache Cleanup

```powershell
# Preview .cache subfolder sizes
Get-ChildItem "$env:USERPROFILE\.cache" -Directory | ForEach-Object { 
    $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    [PSCustomObject]@{ Folder = $_.Name; SizeGB = [math]::Round($size / 1GB, 2) }
} | Where-Object { $_.SizeGB -ge 0.1 } | Sort-Object SizeGB -Descending | Format-Table -AutoSize

# Clear specific cache folders (safe - will re-download when needed)
Remove-Item "$env:USERPROFILE\.cache\huggingface" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.cache\puppeteer" -Recurse -Force -ErrorAction SilentlyContinue
# Keep whisper if you use speech-to-text frequently
```

### Temp Files Cleanup

```powershell
# Preview temp files
Get-ChildItem -Path $env:TEMP -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum | 
Select-Object @{N='TempSizeMB';E={[math]::Round($_.Sum/1MB,2)}}

# Clean temp files (careful!)
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
```

### Windows Update Cleanup

```powershell
# Analyze component store
Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore

# Clean component store (requires elevation)
Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
```

### Clear Windows Delivery Optimization Cache

```powershell
Delete-DeliveryOptimizationCache -Force
```

### Browser Cache Locations

```powershell
# Edge cache size
(Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB

# Chrome cache size
(Get-ChildItem "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
```

## Memory Optimization

### Clear Standby Memory (requires elevation)

```powershell
# Requires RAMMap from Sysinternals or use Empty Standby List utility
# Download: https://www.wagnardsoft.com/forums/viewtopic.php?t=1256
```

### WSL Memory Management

```powershell
# Check WSL memory usage
Get-Process vmmemWSL -ErrorAction SilentlyContinue | Select-Object Name, @{N='MemGB';E={[math]::Round($_.WorkingSet64/1GB,2)}}

# List running WSL distros
wsl --list --running

# Shutdown all WSL instances
wsl --shutdown

# Configure WSL memory limit (~/.wslconfig)
# [wsl2]
# memory=4GB
# processors=4
```

## Service Management

### High-Impact Services to Review

```powershell
# Services using significant memory
Get-Process -IncludeUserName | Where-Object { $_.WorkingSet64 -gt 200MB } | 
Select-Object Name, @{N='MemMB';E={[math]::Round($_.WorkingSet64/1MB,0)}}, Id

# List non-Microsoft services
Get-Service | Where-Object { $_.Status -eq 'Running' } | 
Get-CimInstance -ClassName Win32_Service | 
Where-Object { $_.PathName -notlike '*Microsoft*' -and $_.PathName -notlike '*Windows*' } |
Select-Object Name, State, PathName
```

### Disable Service

```powershell
Stop-Service -Name "{SERVICE_NAME}" -Force
Set-Service -Name "{SERVICE_NAME}" -StartupType Disabled
```

## Advanced Tools

### Sysinternals (download on demand)

```powershell
# Process Explorer - GUI process manager with handle/DLL view
Invoke-WebRequest -Uri "https://live.sysinternals.com/procexp.exe" -OutFile "$env:TEMP\procexp.exe"; & "$env:TEMP\procexp.exe"

# Handle - CLI handle viewer
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Handle.zip" -OutFile "$env:TEMP\Handle.zip"
Expand-Archive "$env:TEMP\Handle.zip" -DestinationPath "$env:TEMP\Handle" -Force

# Process Monitor - real-time file/registry/process activity
Invoke-WebRequest -Uri "https://live.sysinternals.com/Procmon.exe" -OutFile "$env:TEMP\Procmon.exe"; & "$env:TEMP\Procmon.exe"

# Autoruns - comprehensive startup manager
Invoke-WebRequest -Uri "https://live.sysinternals.com/autoruns.exe" -OutFile "$env:TEMP\autoruns.exe"; & "$env:TEMP\autoruns.exe"

# RAMMap - detailed memory analysis
Invoke-WebRequest -Uri "https://live.sysinternals.com/RAMMap.exe" -OutFile "$env:TEMP\RAMMap.exe"; & "$env:TEMP\RAMMap.exe"

# DiskMon - disk activity monitor
Invoke-WebRequest -Uri "https://live.sysinternals.com/Diskmon.exe" -OutFile "$env:TEMP\Diskmon.exe"; & "$env:TEMP\Diskmon.exe"
```

### Third-Party Utilities

**Chris Titus Windows Utility** - Safe debloating and tweaks:

```powershell
irm christitus.com/win | iex
```

**Sophia Script** - Most comprehensive Windows fine-tuning:

```powershell
iwr script.sophia.team -useb | iex
```

## Common Problem Patterns

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| Mouse stuttering | Handle leak, GPU driver, high DPC latency | Handle count, nvidia-smi |
| Gradual slowdown | Handle/memory leak | Handle count over time |
| High memory, low usage % | WSL, SQL Server, Electron apps | vmmemWSL, specific processes |
| Disk thrashing | Windows Search, Antivirus, low RAM | Disk I/O, indexing status |
| Boot slowdown | Too many startup apps | Startup registry |

## Known Problematic Apps

| App | Issue | Solution |
|-----|-------|----------|
| NZXT CAM | Handle leak (10k+) | Restart periodically |
| Razer Synapse | High CPU/handles | Restart or disable |
| Discord | Memory bloat | Restart weekly |
| Electron apps | Memory per window | Close unused windows |
| OneDrive | Sync CPU spikes | Pause during heavy work |
| Windows Defender | Scan I/O | Exclude dev folders |

## Scheduled Maintenance Script

Create a scheduled task to run weekly:

```powershell
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command "Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue; Clear-RecycleBin -Force -ErrorAction SilentlyContinue"'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
Register-ScheduledTask -TaskName "WeeklyCleanup" -Action $action -Trigger $trigger -Principal $principal
```

## Performance Counters Reference

```powershell
# Available performance counters (filter by keyword)
Get-Counter -ListSet * | Where-Object { $_.CounterSetName -match 'Memory|Processor|Disk|GPU' } | Select-Object CounterSetName

# Continuous monitoring (Ctrl+C to stop)
Get-Counter '\Processor(_Total)\% Processor Time', '\Memory\Available MBytes', '\PhysicalDisk(_Total)\% Disk Time' -Continuous -SampleInterval 2
```
