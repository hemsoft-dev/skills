<#
.SYNOPSIS
    Comprehensive system health check for Windows performance diagnostics.
.DESCRIPTION
    Collects CPU, RAM, disk, GPU, and handle metrics in a single report.
.EXAMPLE
    .\Get-SystemHealth.ps1
    .\Get-SystemHealth.ps1 -Detailed
#>

[CmdletBinding()]
param(
    [switch]$Detailed
)

$InformationPreference = 'Continue'

$ErrorActionPreference = 'SilentlyContinue'

Write-Information "[36m`n=== SYSTEM HEALTH REPORT ===`e[0m"
Write-Information "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# CPU
Write-Information "[33mCPU`e[0m"
$cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1).CounterSamples[0].CookedValue
$cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
Write-Information "  Model: $($cpuInfo.Name)"
Write-Information "  Usage: $([math]::Round($cpu, 1))%"
Write-Information "  Cores: $($cpuInfo.NumberOfCores) physical, $($cpuInfo.NumberOfLogicalProcessors) logical"

# RAM
Write-Information "[33m`nMEMORY`e[0m"
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
Write-Information "[33m`nDISK`e[0m"
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
Write-Information "[33m`nGPU`e[0m"
$nvidiaSmi = nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>$null
if ($nvidiaSmi) {
    $gpuData = $nvidiaSmi -split ','
    Write-Information "  Model: $($gpuData[0].Trim())"
    Write-Information "  Usage: $($gpuData[1].Trim())%"
    Write-Information "  VRAM: $($gpuData[2].Trim()) MB / $($gpuData[3].Trim()) MB"
    Write-Information "  Temp: $($gpuData[4].Trim())°C"
} else {
    Write-Information "[90m  NVIDIA GPU not detected or nvidia-smi unavailable`e[0m"
}

# Handle Leaks
Write-Information "[33m`nHANDLE LEAK CHECK`e[0m"
$highHandles = Get-Process | Where-Object { $_.Handles -gt 3000 } | Sort-Object Handles -Descending | Select-Object -First 5
if ($highHandles) {
    Write-Information "[31m  Processes with high handle counts (>3000):`e[0m"
    $highHandles | ForEach-Object {
        $handleColor = if ($_.Handles -gt 5000) { "Red" } else { "Yellow" }
        Write-Information "    $($_.Name) (PID $($_.Id)): $($_.Handles) handles" -ForegroundColor $handleColor
    }
} else {
    Write-Information "[32m  No handle leaks detected`e[0m"
}

# Top Processes
Write-Information "[33m`nTOP PROCESSES BY MEMORY`e[0m"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object {
    $memMB = [math]::Round($_.WorkingSet64 / 1MB, 0)
    Write-Information "  $($_.Name): $memMB MB"
}

if ($Detailed) {
    Write-Information "[33m`nTOP PROCESSES BY CPU (cumulative)`e[0m"
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Information "  $($_.Name): $([math]::Round($_.CPU, 1))s"
    }

    Write-Information "[33m`nWSL STATUS`e[0m"
    $wslProc = Get-Process vmmemWSL -ErrorAction SilentlyContinue
    if ($wslProc) {
        $wslMem = [math]::Round($wslProc.WorkingSet64 / 1GB, 2)
        Write-Information "  vmmemWSL: $wslMem GB"
        Write-Information "  Running distros:"
        wsl --list --running 2>$null | Where-Object { $_ -and $_ -notmatch 'Windows Subsystem' } | ForEach-Object {
            Write-Information "    $_"
        }
    } else {
        Write-Information "[90m  WSL not running`e[0m"
    }

    Write-Information "[33m`nSTARTUP PROGRAMS`e[0m"
    $startup = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
    $startup.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
        Write-Information "  $($_.Name)"
    }
}

Write-Information "[36m`n=== END REPORT ===`e[0m"
