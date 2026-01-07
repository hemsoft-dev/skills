<#
.SYNOPSIS
    Comprehensive system health check for Windows performance diagnostics.
.DESCRIPTION
    Collects CPU, RAM, disk, GPU, and handle metrics in a single report.
.EXAMPLE
    .\Get-SystemHealth.ps1
    .\Get-SystemHealth.ps1 -Detailed
#>
$InformationPreference = 'Continue'

[CmdletBinding()]
param(
    [switch]$Detailed
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Information "`n=== SYSTEM HEALTH REPORT ===" -ForegroundColor Cyan
Write-Information "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# CPU
Write-Information "CPU" -ForegroundColor Yellow
$cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1).CounterSamples[0].CookedValue
$cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
Write-Information "  Model: $($cpuInfo.Name)"
Write-Information "  Usage: $([math]::Round($cpu, 1))%"
Write-Information "  Cores: $($cpuInfo.NumberOfCores) physical, $($cpuInfo.NumberOfLogicalProcessors) logical"

# RAM
Write-Information "`nMEMORY" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$usedGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
$pct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
$status = if ($pct -gt 90) { "CRITICAL" } elseif ($pct -gt 75) { "WARNING" } else { "OK" }
$color = if ($pct -gt 90) { "Red" } elseif ($pct -gt 75) { "Yellow" } else { "Green" }
Write-Information "  Used: $usedGB GB / $totalGB GB ($pct%)" -ForegroundColor $color
Write-Information "  Status: $status" -ForegroundColor $color

# Commit Charge
$commit = (Get-Counter '\Memory\Committed Bytes').CounterSamples[0].CookedValue / 1GB
$commitLimit = (Get-Counter '\Memory\Commit Limit').CounterSamples[0].CookedValue / 1GB
Write-Information "  Commit: $([math]::Round($commit, 1)) GB / $([math]::Round($commitLimit, 1)) GB"

# Disk
Write-Information "`nDISK" -ForegroundColor Yellow
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $usedDiskGB = [math]::Round($_.Used / 1GB, 1)
    $freeDiskGB = [math]::Round($_.Free / 1GB, 1)
    $totalDiskGB = $usedDiskGB + $freeDiskGB
    if ($totalDiskGB -gt 0) {
        $diskPct = [math]::Round(($usedDiskGB / $totalDiskGB) * 100, 1)
        $diskColor = if ($diskPct -gt 90) { "Red" } elseif ($diskPct -gt 75) { "Yellow" } else { "Green" }
        Write-Information "  $($_.Name): $usedDiskGB GB / $totalDiskGB GB ($diskPct% used)" -ForegroundColor $diskColor
    }
}

# GPU (NVIDIA)
Write-Information "`nGPU" -ForegroundColor Yellow
$nvidiaSmi = nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>$null
if ($nvidiaSmi) {
    $gpuData = $nvidiaSmi -split ','
    Write-Information "  Model: $($gpuData[0].Trim())"
    Write-Information "  Usage: $($gpuData[1].Trim())%"
    Write-Information "  VRAM: $($gpuData[2].Trim()) MB / $($gpuData[3].Trim()) MB"
    Write-Information "  Temp: $($gpuData[4].Trim())°C"
} else {
    Write-Information "  NVIDIA GPU not detected or nvidia-smi unavailable" -ForegroundColor Gray
}

# Handle Leaks
Write-Information "`nHANDLE LEAK CHECK" -ForegroundColor Yellow
$highHandles = Get-Process | Where-Object { $_.Handles -gt 3000 } | Sort-Object Handles -Descending | Select-Object -First 5
if ($highHandles) {
    Write-Information "  Processes with high handle counts (>3000):" -ForegroundColor Red
    $highHandles | ForEach-Object {
        $handleColor = if ($_.Handles -gt 5000) { "Red" } else { "Yellow" }
        Write-Information "    $($_.Name) (PID $($_.Id)): $($_.Handles) handles" -ForegroundColor $handleColor
    }
} else {
    Write-Information "  No handle leaks detected" -ForegroundColor Green
}

# Top Processes
Write-Information "`nTOP PROCESSES BY MEMORY" -ForegroundColor Yellow
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object {
    $memMB = [math]::Round($_.WorkingSet64 / 1MB, 0)
    Write-Information "  $($_.Name): $memMB MB"
}

if ($Detailed) {
    Write-Information "`nTOP PROCESSES BY CPU (cumulative)" -ForegroundColor Yellow
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Information "  $($_.Name): $([math]::Round($_.CPU, 1))s"
    }

    Write-Information "`nWSL STATUS" -ForegroundColor Yellow
    $wslProc = Get-Process vmmemWSL -ErrorAction SilentlyContinue
    if ($wslProc) {
        $wslMem = [math]::Round($wslProc.WorkingSet64 / 1GB, 2)
        Write-Information "  vmmemWSL: $wslMem GB"
        Write-Information "  Running distros:"
        wsl --list --running 2>$null | Where-Object { $_ -and $_ -notmatch 'Windows Subsystem' } | ForEach-Object {
            Write-Information "    $_"
        }
    } else {
        Write-Information "  WSL not running" -ForegroundColor Gray
    }

    Write-Information "`nSTARTUP PROGRAMS" -ForegroundColor Yellow
    $startup = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
    $startup.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
        Write-Information "  $($_.Name)"
    }
}

Write-Information "`n=== END REPORT ===" -ForegroundColor Cyan
