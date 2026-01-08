<#
.SYNOPSIS
    Monitors system performance in real-time.
.DESCRIPTION
    Displays live CPU, RAM, disk, and optionally GPU metrics with refresh interval.
.PARAMETER Interval
    Refresh interval in seconds (default: 2)
.PARAMETER Duration
    Total monitoring duration in seconds (default: unlimited, Ctrl+C to stop)
.PARAMETER IncludeGPU
    Include NVIDIA GPU metrics
.EXAMPLE
    .\Watch-Performance.ps1
    .\Watch-Performance.ps1 -Interval 1 -IncludeGPU
    .\Watch-Performance.ps1 -Duration 60
#>
[CmdletBinding()]
param(
    [int]$Interval = 2,
    [int]$Duration = 0,
    [switch]$IncludeGPU
)

$InformationPreference = 'Continue'


$ErrorActionPreference = 'SilentlyContinue'

Write-Information "[36m`n=== PERFORMANCE MONITOR ===`e[0m"
Write-Information "Refresh: ${Interval}s | Press Ctrl+C to stop`n"
Write-Information "[90m$(("{0,-8} {1,-12} {2,-12} {3,-12} {4,-15}" -f "TIME", "CPU %", "RAM %", "DISK %", "TOP PROCESS"))`e[0m"
Write-Information ("-" * 65)

$startTime = Get-Date
$iteration = 0

try {
    while ($true) {
        $iteration++
        
        # Check duration limit
        if ($Duration -gt 0) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            if ($elapsed -ge $Duration) {
                Write-Information "[33m`nDuration limit reached ($Duration seconds)`e[0m"
                break
            }
        }
        
        # Collect metrics
        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        
        $os = Get-CimInstance Win32_OperatingSystem
        $ramPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
        
        $disk = (Get-Counter '\PhysicalDisk(_Total)\% Disk Time').CounterSamples[0].CookedValue
        
        # Top CPU process (current snapshot)
        $topProc = Get-Process | Sort-Object CPU -Descending | Select-Object -First 1
        $topName = if ($topProc.Name.Length -gt 12) { $topProc.Name.Substring(0, 12) } else { $topProc.Name }
        
        # Determine colors based on thresholds
        $cpuColor = if ($cpu -gt 90) { "Red" } elseif ($cpu -gt 70) { "Yellow" } else { "Green" }
        $ramColor = if ($ramPct -gt 90) { "Red" } elseif ($ramPct -gt 75) { "Yellow" } else { "Green" }
        $diskColor = if ($disk -gt 90) { "Red" } elseif ($disk -gt 50) { "Yellow" } else { "Green" }
        
        $timeStr = (Get-Date).ToString("HH:mm:ss")
        
        # Build output line
        Write-Information ("{0,-8} " -f $timeStr) -NoNewline
        Write-Information ("{0,-12}" -f "$([math]::Round($cpu, 1))%") -ForegroundColor $cpuColor -NoNewline
        Write-Information ("{0,-12}" -f "$ramPct%") -ForegroundColor $ramColor -NoNewline
        Write-Information ("{0,-12}" -f "$([math]::Round($disk, 1))%") -ForegroundColor $diskColor -NoNewline
        Write-Information ("{0,-15}" -f $topName)
        
        # GPU metrics (if requested)
        if ($IncludeGPU -and ($iteration % 5 -eq 0)) {
            $gpuInfo = nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv,noheader,nounits 2>$null
            if ($gpuInfo) {
                $gpuData = $gpuInfo -split ','
                $gpuColor = if ([int]$gpuData[0] -gt 90) { "Red" } elseif ([int]$gpuData[0] -gt 50) { "Yellow" } else { "Green" }
                Write-Information ("         GPU: {0}% | VRAM: {1} MB | Temp: {2}°C" -f $gpuData[0].Trim(), $gpuData[1].Trim(), $gpuData[2].Trim()) -ForegroundColor $gpuColor
            }
        }
        
        # Alert on anomalies
        if ($cpu -gt 95) {
            Write-Information "[31m  [!] CPU CRITICAL`e[0m"
        }
        if ($ramPct -gt 95) {
            Write-Information "[31m  [!] MEMORY CRITICAL`e[0m"
        }
        if ($disk -gt 95) {
            Write-Information "[31m  [!] DISK I/O CRITICAL`e[0m"
        }
        
        Start-Sleep -Seconds $Interval
    }
} finally {
    Write-Information "[36m`n=== MONITORING STOPPED ===`e[0m"
    Write-Information "Samples collected: $iteration"
    Write-Information "Duration: $([math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)) seconds`n"
}
