#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Windows Service Worker for HemSoft Conductor Server
    
.DESCRIPTION
    Runs as a Windows Service and monitors the hs-conductor backend services:
    - Backend server (port 2900)
    - Inngest dev server (port 2901)
    
    Checks every 60 seconds and auto-restarts if services crash.
    Logs all events to ~/.claude/skills/logs/hs-conductor/
#>

$ErrorActionPreference = "Continue"

# Configuration
$rootDir = "d:\github\HemSoft\hs-conductor"
$logsDir = "c:\Users\User\.claude\skills\logs\hs-conductor"
$portsToMonitor = @(2900, 2901)
$checkIntervalSeconds = 60

# Colors (for console output)
$InfoColor = "Cyan"
$SuccessColor = "Green"
$ErrorColor = "Red"
$WarningColor = "Yellow"

# Ensure logs directory exists
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Level,
        [string]$Event,
        [string]$Details,
        [int]$ExitCode = $null
    )
    
    $timestamp = Get-Date -Format "o"
    $today = Get-Date -Format "yyyy-MM-dd"
    $logFile = Join-Path $logsDir "$today.json"
    
    $entry = @{
        timestamp = $timestamp
        level = $Level.ToLower()
        event = $Event
        details = $Details
        exitCode = $ExitCode
    }
    
    $logArray = @()
    
    # Read existing log file if it exists
    if (Test-Path $logFile) {
        try {
            $existing = Get-Content $logFile -Raw | ConvertFrom-Json
            if ($existing -is [array]) {
                $logArray = $existing
            } else {
                $logArray = @($existing)
            }
        } catch {
            # If parsing fails, start fresh
            $logArray = @()
        }
    }
    
    # Append new entry
    $logArray += $entry
    
    # Write back to file
    try {
        $logArray | ConvertTo-Json -AsArray | Set-Content $logFile -Encoding UTF8
    } catch {
        "Failed to write log: $_" | Out-Host
    }
}

function Test-PortListening {
    param([int]$Port)
    
    try {
        $netstat = netstat -ano 2>$null | Select-String ":$Port.*LISTENING"
        return $null -ne $netstat
    } catch {
        return $false
    }
}

function Start-BackendServer {
    try {
        Write-Log "info" "starting_backend_server" "Launching backend server via 'bun run --watch src/index.ts'"
        
        $proc = Start-Process -FilePath "bun" `
            -ArgumentList "run", "--watch", "src/index.ts" `
            -WorkingDirectory $rootDir `
            -PassThru `
            -NoNewWindow `
            -ErrorAction Stop
        
        if ($proc -and -not $proc.HasExited) {
            # Wait a bit for it to start
            Start-Sleep -Seconds 2
            
            if (Test-PortListening 2900) {
                Write-Log "info" "backend_server_started" "Backend server started successfully on port 2900"
                return $true
            } else {
                Write-Log "warn" "backend_server_slow_start" "Backend server process started but port 2900 not responding yet"
                return $true  # Process is running, give it more time
            }
        } else {
            Write-Log "error" "backend_server_failed" "Failed to start backend server process" 1
            return $false
        }
    } catch {
        Write-Log "error" "backend_server_exception" "Exception starting backend server: $_" 1
        return $false
    }
}

function Start-InngestServer {
    try {
        Write-Log "info" "starting_inngest_server" "Launching Inngest dev server via 'npx inngest-cli@latest dev'"
        
        $proc = Start-Process -FilePath "cmd.exe" `
            -ArgumentList "/c", "npx inngest-cli@latest dev --port 2901 --host 127.0.0.1 -u http://localhost:2900/api/inngest --no-discovery" `
            -WorkingDirectory $rootDir `
            -PassThru `
            -NoNewWindow `
            -ErrorAction Stop
        
        if ($proc -and -not $proc.HasExited) {
            # Wait a bit for it to start
            Start-Sleep -Seconds 3
            
            if (Test-PortListening 2901) {
                Write-Log "info" "inngest_server_started" "Inngest dev server started successfully on port 2901"
                return $true
            } else {
                Write-Log "warn" "inngest_server_slow_start" "Inngest dev server process started but port 2901 not responding yet"
                return $true  # Process is running, give it more time
            }
        } else {
            Write-Log "error" "inngest_server_failed" "Failed to start Inngest dev server process" 1
            return $false
        }
    } catch {
        Write-Log "error" "inngest_server_exception" "Exception starting Inngest dev server: $_" 1
        return $false
    }
}

function Restart-ProcessOnPort {
    param([int]$Port)
    
    try {
        $netstat = netstat -ano 2>$null | Select-String ":$Port.*LISTENING"
        if ($netstat) {
            $procId = ($netstat[0] -split '\s+')[-1]
            if ($procId -match '^\d+$') {
                Stop-Process -Id ([int]$procId) -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500
            }
        }
    } catch {
        # Silently continue
    }
}

# Main monitoring loop
Write-Log "info" "service_started" "HemSoft Conductor Server monitoring service started"

$backendServerFails = 0
$inngestFails = 0

while ($true) {
    try {
        $backendRunning = Test-PortListening 2900
        $inngestRunning = Test-PortListening 2901
        
        # Check backend server
        if (-not $backendRunning) {
            $backendServerFails++
            Write-Log "warn" "backend_server_check_failed" "Backend server not responding on port 2900 (failure $backendServerFails)"
            
            if ($backendServerFails -ge 2) {
                Write-Log "error" "backend_server_restarting" "Backend server failed $backendServerFails checks, attempting restart"
                Restart-ProcessOnPort 2900
                Start-BackendServer
                $backendServerFails = 0
            }
        } else {
            if ($backendServerFails -gt 0) {
                Write-Log "info" "backend_server_recovered" "Backend server recovered on port 2900"
                $backendServerFails = 0
            }
        }
        
        # Check Inngest server
        if (-not $inngestRunning) {
            $inngestFails++
            Write-Log "warn" "inngest_server_check_failed" "Inngest dev server not responding on port 2901 (failure $inngestFails)"
            
            if ($inngestFails -ge 2) {
                Write-Log "error" "inngest_server_restarting" "Inngest dev server failed $inngestFails checks, attempting restart"
                Restart-ProcessOnPort 2901
                Start-InngestServer
                $inngestFails = 0
            }
        } else {
            if ($inngestFails -gt 0) {
                Write-Log "info" "inngest_server_recovered" "Inngest dev server recovered on port 2901"
                $inngestFails = 0
            }
        }
        
        # Wait before next check
        Start-Sleep -Seconds $checkIntervalSeconds
        
    } catch {
        Write-Log "error" "monitoring_loop_exception" "Exception in monitoring loop: $_" 1
        Start-Sleep -Seconds $checkIntervalSeconds
    }
}
