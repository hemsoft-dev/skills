<#
.SYNOPSIS
    Downloads and launches Sysinternals tools on demand.
.DESCRIPTION
    Downloads specified Sysinternals tools directly from Microsoft and optionally runs them.
.PARAMETER Tool
    The tool to download: ProcessExplorer, ProcessMonitor, Autoruns, RAMMap, Handle, DiskMon, TCPView
.PARAMETER Run
    Launch the tool after downloading
.PARAMETER DownloadPath
    Where to save tools (default: $env:TEMP\Sysinternals)
.EXAMPLE
    .\Get-Sysinternals.ps1 -Tool ProcessExplorer -Run
    .\Get-Sysinternals.ps1 -Tool Handle
    .\Get-Sysinternals.ps1 -Tool Autoruns -Run
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('ProcessExplorer', 'ProcessMonitor', 'Autoruns', 'RAMMap', 'Handle', 'DiskMon', 'TCPView', 'All')]
    [string]$Tool,
    
    [switch]$Run,
    
    [string]$DownloadPath = "$env:TEMP\Sysinternals"
)

$ErrorActionPreference = 'Stop'

$tools = @{
    ProcessExplorer = @{
        Url = "https://download.sysinternals.com/files/ProcessExplorer.zip"
        Exe = "procexp64.exe"
        Description = "Advanced process manager with handle/DLL view"
    }
    ProcessMonitor = @{
        Url = "https://download.sysinternals.com/files/ProcessMonitor.zip"
        Exe = "Procmon64.exe"
        Description = "Real-time file, registry, and process activity monitor"
    }
    Autoruns = @{
        Url = "https://download.sysinternals.com/files/Autoruns.zip"
        Exe = "Autoruns64.exe"
        Description = "Comprehensive startup manager"
    }
    RAMMap = @{
        Url = "https://download.sysinternals.com/files/RAMMap.zip"
        Exe = "RAMMap64.exe"
        Description = "Detailed physical memory analysis"
    }
    Handle = @{
        Url = "https://download.sysinternals.com/files/Handle.zip"
        Exe = "handle64.exe"
        Description = "Command-line handle viewer"
    }
    DiskMon = @{
        Url = "https://download.sysinternals.com/files/DiskMon.zip"
        Exe = "Diskmon.exe"
        Description = "Disk activity monitor"
    }
    TCPView = @{
        Url = "https://download.sysinternals.com/files/TCPView.zip"
        Exe = "tcpview64.exe"
        Description = "Network connection viewer"
    }
}

function Download-Tool {
    param(
        [string]$Name,
        [hashtable]$Info
    )
    
    $toolPath = Join-Path $DownloadPath $Name
    $exePath = Join-Path $toolPath $Info.Exe
    $zipPath = Join-Path $env:TEMP "$Name.zip"
    
    Write-Host "`n[$Name] $($Info.Description)" -ForegroundColor Yellow
    
    if (Test-Path $exePath) {
        Write-Host "  Already downloaded at: $exePath" -ForegroundColor Gray
    } else {
        Write-Host "  Downloading..." -ForegroundColor Gray
        
        try {
            # Create directory
            if (-not (Test-Path $toolPath)) {
                New-Item -ItemType Directory -Path $toolPath -Force | Out-Null
            }
            
            # Download
            Invoke-WebRequest -Uri $Info.Url -OutFile $zipPath -UseBasicParsing
            
            # Extract
            Expand-Archive -Path $zipPath -DestinationPath $toolPath -Force
            Remove-Item $zipPath -Force
            
            Write-Host "  Downloaded to: $toolPath" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to download: $_" -ForegroundColor Red
            return $null
        }
    }
    
    return $exePath
}

Write-Host "`n=== SYSINTERNALS DOWNLOADER ===" -ForegroundColor Cyan

# Ensure download directory exists
if (-not (Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

if ($Tool -eq 'All') {
    foreach ($toolName in $tools.Keys) {
        $exePath = Download-Tool -Name $toolName -Info $tools[$toolName]
    }
    Write-Host "`nAll tools downloaded to: $DownloadPath" -ForegroundColor Green
} else {
    $exePath = Download-Tool -Name $Tool -Info $tools[$Tool]
    
    if ($Run -and $exePath -and (Test-Path $exePath)) {
        Write-Host "`nLaunching $Tool..." -ForegroundColor Cyan
        Start-Process $exePath
    }
}

Write-Host ""
