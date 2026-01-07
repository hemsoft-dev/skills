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
$InformationPreference = 'Continue'

[CmdletBinding()]
param(
    [string]$Name = "dopus-config",
    [switch]$IncludeLocalState
)

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

Write-Information "Backing up Directory Opus configuration..." -ForegroundColor Cyan
Write-Information "  Options: $backupOptions" -ForegroundColor Gray
Write-Information "  Output:  $backupPath" -ForegroundColor Gray

# Run the backup command silently
& $dopusrt /cmd Prefs BACKUP=$backupOptions QUIET TO="$backupPath"

# Wait briefly for file to be written
Start-Sleep -Milliseconds 500

if ($LASTEXITCODE -eq 0) {
    if (Test-Path $backupPath) {
        $file = Get-Item $backupPath
        Write-Information "`nBackup complete!" -ForegroundColor Green
        Write-Information "  File: $backupPath" -ForegroundColor Gray
        Write-Information "  Size: $([math]::Round($file.Length / 1KB, 1)) KB" -ForegroundColor Gray
    }
    else {
        Write-Warning "Backup command completed but file not found. Check if Directory Opus is running."
    }
}
else {
    Write-Error "Backup failed with exit code: $LASTEXITCODE"
}
