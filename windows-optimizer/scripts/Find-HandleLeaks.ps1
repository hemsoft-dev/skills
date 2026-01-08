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

$InformationPreference = 'Continue'

$ErrorActionPreference = 'SilentlyContinue'

# Known problematic apps with their typical executable paths
$KnownLeakers = @{
    'NZXT CAM' = 'C:\Program Files\NZXT CAM\NZXT CAM.exe'
    'RazerCentralService' = $null  # Service, don't auto-restart
    'Razer Synapse 3' = 'C:\Program Files (x86)\Razer\Synapse3\WPFUI\Framework\Razer Synapse 3 Host\Razer Synapse 3.exe'
    'Discord' = "$env:LOCALAPPDATA\Discord\Update.exe --processStart Discord.exe"
    'Slack' = "$env:LOCALAPPDATA\slack\slack.exe"
}

Write-Information "[36m`n=== HANDLE LEAK DETECTION ===`e[0m"
Write-Information "Threshold: $Threshold handles`n"

$leaks = Get-Process | Where-Object { $_.Handles -gt $Threshold } | Sort-Object Handles -Descending

if (-not $leaks) {
    Write-Information "[32mNo processes found with handle count > $Threshold`e[0m"
    Write-Information "System handles look healthy!`n"
    exit 0
}

Write-Information "[33mFound $($leaks.Count) process(es) with high handle counts:`n`e[0m"

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
    
    Write-Information "[$severity] $($proc.Name)" -ForegroundColor $color
    Write-Information "  PID: $($proc.Id) | Handles: $($proc.Handles) | Memory: $memMB MB"
    
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
            Write-Information "[36m  -> Auto-restarting $($proc.Name)...`e[0m"
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                Start-Sleep -Seconds 2
                Start-Process $exePath -ErrorAction Stop
                Write-Information "[32m  -> Restarted successfully`e[0m"
            } catch {
                Write-Information "[31m  -> Failed to restart: $_`e[0m"
            }
        } else {
            Write-Information "[90m  -> Known leaker but no auto-restart path configured`e[0m"
        }
    }
    
    Write-Information ""
}

Write-Information "[36m=== SUMMARY ===`e[0m"
Write-Information "Total processes with leaks: $($leaks.Count)"
Write-Information "Critical (>10000): $(($results | Where-Object Severity -eq 'CRITICAL').Count)"
Write-Information "Warning (>5000): $(($results | Where-Object Severity -eq 'WARNING').Count)"
Write-Information "Elevated (>$Threshold): $(($results | Where-Object Severity -eq 'ELEVATED').Count)"

if (-not $AutoFix) {
    Write-Information "[90m`nTip: Run with -AutoFix to automatically restart known problematic apps`e[0m"
}

Write-Information ""
