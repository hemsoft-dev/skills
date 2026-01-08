<#
.SYNOPSIS
    Backs up Directory Opus configuration to this folder.

.DESCRIPTION
    Creates a full configuration backup (.ocb file) using dopusrt.exe command line.
    The backup includes all settings, toolbars, images, sounds, and miscellaneous data.
    Local state data (window positions) is excluded for portability.
    
    Directory Opus must be running for the backup to work.

.EXAMPLE
    .\Backup-DOpusConfig.ps1
    Creates a backup with default naming (dopus-config.ocb)

.EXAMPLE
    .\Backup-DOpusConfig.ps1 -Name "my-backup"
    Creates a backup named my-backup.ocb

.EXAMPLE
    .\Backup-DOpusConfig.ps1 -IncludeLocalState
    Includes window positions and other machine-specific data
#>

[CmdletBinding()]
param(
    [string]$Name = "dopus-config",
    [switch]$IncludeLocalState
)

$InformationPreference = 'Continue'

$dopusrt = "C:\Program Files\GPSoftware\Directory Opus\dopusrt.exe"
$backupDir = $PSScriptRoot
$backupPath = Join-Path $backupDir "$Name.ocb"

if (-not (Test-Path $dopusrt)) {
    Write-Error "Directory Opus not found at: $dopusrt"
    exit 1
}

# Build backup options
$backupOptions = "images,sounds,data"
if ($IncludeLocalState) {
    $backupOptions = "all"
}

Write-Information "[36mBacking up Directory Opus configuration...`e[0m"
Write-Information "[90m  Options: $backupOptions`e[0m"
Write-Information "[90m  Output:  $backupPath`e[0m"

# Run the backup command silently
& $dopusrt /cmd Prefs BACKUP=$backupOptions QUIET TO="$backupPath"

# Wait briefly for file to be written
Start-Sleep -Milliseconds 500

if ($LASTEXITCODE -eq 0) {
    if (Test-Path $backupPath) {
        $file = Get-Item $backupPath
        Write-Information "[32m`nBackup complete!`e[0m"
        Write-Information "[90m  File: $backupPath`e[0m"
        Write-Information "[90m  Size: $([math]::Round($file.Length / 1KB, 1)) KB`e[0m"
    }
    else {
        Write-Warning "Backup command completed but file not found. Check if Directory Opus is running."
    }
}
else {
    Write-Error "Backup failed with exit code: $LASTEXITCODE"
}
