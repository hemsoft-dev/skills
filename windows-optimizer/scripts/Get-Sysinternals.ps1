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

$InformationPreference = 'Continue'

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

function Get-Tool {
    param(
        [string]$Name,
        [hashtable]$Info
    )
    
    $toolPath = Join-Path $DownloadPath $Name
    $exePath = Join-Path $toolPath $Info.Exe
    $zipPath = Join-Path $env:TEMP "$Name.zip"
    
    Write-Information "[33m`n[$Name] $($Info.Description)`e[0m"
    
    if (Test-Path $exePath) {
        Write-Information "[90m  Already downloaded at: $exePath`e[0m"
    } else {
        Write-Information "[90m  Downloading...`e[0m"
        
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
            
            Write-Information "[32m  Downloaded to: $toolPath`e[0m"
        } catch {
            Write-Information "[31m  Failed to download: $_`e[0m"
            return $null
        }
    }
    
    return $exePath
}

Write-Information "[36m`n=== SYSINTERNALS DOWNLOADER ===`e[0m"

# Ensure download directory exists
if (-not (Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

if ($Tool -eq 'All') {
    foreach ($toolName in $tools.Keys) {
        $exePath = Get-Tool -Name $toolName -Info $tools[$toolName]
    }
    Write-Information "[32m`nAll tools downloaded to: $DownloadPath`e[0m"
} else {
    $exePath = Get-Tool -Name $Tool -Info $tools[$Tool]
    
    if ($Run -and $exePath -and (Test-Path $exePath)) {
        Write-Information "[36m`nLaunching $Tool...`e[0m"
        Start-Process $exePath
    }
}

Write-Information ""
