<#
.SYNOPSIS
    Detects and optionally restarts processes with handle leaks.
.DESCRIPTION
    Scans running processes for high handle counts that indicate memory leaks.
    Can automatically restart known problematic apps.
.PARAMETER Threshold
    Handle count threshold to flag as potential leak (default: 3000)
.PARAMETER AutoFix
    Automatically restart known problematic processes
.EXAMPLE
    .\Find-HandleLeaks.ps1
    .\Find-HandleLeaks.ps1 -Threshold 5000
    .\Find-HandleLeaks.ps1 -AutoFix
#>
[CmdletBinding()]
param(
    [int]$Threshold = 3000,
    [switch]$AutoFix
)

$ErrorActionPreference = 'SilentlyContinue'

# Known problematic apps with their typical executable paths
$KnownLeakers = @{
    'NZXT CAM' = 'C:\Program Files\NZXT CAM\NZXT CAM.exe'
    'RazerCentralService' = $null  # Service, don't auto-restart
    'Razer Synapse 3' = 'C:\Program Files (x86)\Razer\Synapse3\WPFUI\Framework\Razer Synapse 3 Host\Razer Synapse 3.exe'
    'Discord' = "$env:LOCALAPPDATA\Discord\Update.exe --processStart Discord.exe"
    'Slack' = "$env:LOCALAPPDATA\slack\slack.exe"
}

Write-Host "`n=== HANDLE LEAK DETECTION ===" -ForegroundColor Cyan
Write-Host "Threshold: $Threshold handles`n"

$leaks = Get-Process | Where-Object { $_.Handles -gt $Threshold } | Sort-Object Handles -Descending

if (-not $leaks) {
    Write-Host "No processes found with handle count > $Threshold" -ForegroundColor Green
    Write-Host "System handles look healthy!`n"
    exit 0
}

Write-Host "Found $($leaks.Count) process(es) with high handle counts:`n" -ForegroundColor Yellow

$results = @()
foreach ($proc in $leaks) {
    $severity = if ($proc.Handles -gt 10000) { "CRITICAL" }
                elseif ($proc.Handles -gt 5000) { "WARNING" }
                else { "ELEVATED" }
    
    $color = switch ($severity) {
        "CRITICAL" { "Red" }
        "WARNING" { "Yellow" }
        default { "White" }
    }
    
    $memMB = [math]::Round($proc.WorkingSet64 / 1MB, 0)
    
    Write-Host "[$severity] $($proc.Name)" -ForegroundColor $color
    Write-Host "  PID: $($proc.Id) | Handles: $($proc.Handles) | Memory: $memMB MB"
    
    $results += [PSCustomObject]@{
        Name = $proc.Name
        PID = $proc.Id
        Handles = $proc.Handles
        MemoryMB = $memMB
        Severity = $severity
    }
    
    # Auto-fix known leakers
    if ($AutoFix -and $KnownLeakers.ContainsKey($proc.Name)) {
        $exePath = $KnownLeakers[$proc.Name]
        if ($exePath) {
            Write-Host "  -> Auto-restarting $($proc.Name)..." -ForegroundColor Cyan
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                Start-Sleep -Seconds 2
                Start-Process $exePath -ErrorAction Stop
                Write-Host "  -> Restarted successfully" -ForegroundColor Green
            } catch {
                Write-Host "  -> Failed to restart: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "  -> Known leaker but no auto-restart path configured" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
}

Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total processes with leaks: $($leaks.Count)"
Write-Host "Critical (>10000): $(($results | Where-Object Severity -eq 'CRITICAL').Count)"
Write-Host "Warning (>5000): $(($results | Where-Object Severity -eq 'WARNING').Count)"
Write-Host "Elevated (>$Threshold): $(($results | Where-Object Severity -eq 'ELEVATED').Count)"

if (-not $AutoFix) {
    Write-Host "`nTip: Run with -AutoFix to automatically restart known problematic apps" -ForegroundColor Gray
}

Write-Host ""
