<#
.SYNOPSIS
    Recycles resource-heavy processes to free up system resources.
.DESCRIPTION
    Stops and restarts NVIDIA Broadcast and SnagitEditor processes to reclaim memory
    and CPU resources. Useful for scheduled maintenance or manual cleanup.
.EXAMPLE
    .\Restart-ResourceHeavyProcesses.ps1
.NOTES
    Process names:
    - NVIDIA Broadcast: NVIDIA Broadcast
    - Snagit Editor: SnagitEditor
#>
[CmdletBinding()]
param()

$InformationPreference = 'Continue'

# Define processes to recycle
$processes = @(
    @{
        Name = "NVIDIA Broadcast"
        Path = "C:\Program Files\NVIDIA Corporation\NVIDIA Broadcast\NVIDIA Broadcast.exe"
    },
    @{
        Name = "SnagitEditor"
        Path = "C:\Program Files\TechSmith\Snagit 2025\SnagitEditor.exe"
    }
)

Write-Information "`e[96mRecycling resource-heavy processes...`e[0m"
Write-Information ""

foreach ($proc in $processes) {
    Write-Information "`e[93mProcessing: $($proc.Name)`e[0m"
    
    # Check if process is running
    $running = Get-Process -Name $proc.Name -ErrorAction SilentlyContinue
    
    if ($running) {
        Write-Information "  `e[33m→`e[0m Stopping process (PID: $($running.Id))..."
        
        try {
            Stop-Process -Name $proc.Name -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
            Write-Information "  `e[32m✓`e[0m Stopped successfully"
        }
        catch {
            Write-Information "  `e[31m✗`e[0m Failed to stop: $_"
            continue
        }
    }
    else {
        Write-Information "  `e[90m○`e[0m Process was not running"
    }
    
    # Start the process if path exists
    if (Test-Path $proc.Path) {
        Write-Information "  `e[33m→`e[0m Starting process..."
        
        try {
            # Start process with redirected output to prevent console spam
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = $proc.Path
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            $startInfo.CreateNoWindow = $false
            [void][System.Diagnostics.Process]::Start($startInfo)
            Start-Sleep -Seconds 1
            
            # Verify it started
            $newProcess = Get-Process -Name $proc.Name -ErrorAction SilentlyContinue
            if ($newProcess) {
                Write-Information "  `e[32m✓`e[0m Started successfully (PID: $($newProcess.Id))"
            }
            else {
                Write-Information "  `e[33m⚠`e[0m Process started but not yet visible"
            }
        }
        catch {
            Write-Information "  `e[31m✗`e[0m Failed to start: $_"
        }
    }
    else {
        Write-Information "  `e[31m✗`e[0m Executable not found: $($proc.Path)"
        Write-Information "  `e[90m  Skipping restart`e[0m"
    }
    
    Write-Information ""
}

Write-Information "`e[92mRecycle complete!`e[0m"
