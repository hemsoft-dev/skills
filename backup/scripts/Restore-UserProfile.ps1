<#
.SYNOPSIS
    Restores user profile folders from backup.
.DESCRIPTION
    Restores folders from a previous backup to the user profile.
.PARAMETER BackupDate
    Date of backup to restore (format: yyyy-MM-dd). Lists available if not specified.
.PARAMETER Folders
    Specific folders to restore. If not specified, restores all.
.PARAMETER BackupRoot
    Backup root folder. Default: F:\OneDrive\User-Backup
.PARAMETER WhatIf
    Show what would be restored without copying files.
.EXAMPLE
    .\Restore-UserProfile.ps1 -BackupDate "2025-12-25"
    .\Restore-UserProfile.ps1 -BackupDate "2025-12-25" -Folders ".claude",".ssh"
#>

param(
    [string]$BackupDate,
    [string[]]$Folders,
    [string]$BackupRoot = "F:\OneDrive\User-Backup",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$UserProfile = $env:USERPROFILE

# List available backups if no date specified
if (-not $BackupDate) {
    Write-Host "`n=== Available Backups ===" -ForegroundColor Cyan
    $backups = Get-ChildItem $BackupRoot -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } |
        Sort-Object Name -Descending
    
    if (-not $backups) {
        Write-Host "No backups found in $BackupRoot" -ForegroundColor Red
        exit 1
    }
    
    foreach ($backup in $backups) {
        $manifest = Join-Path $backup.FullName "backup-manifest.json"
        if (Test-Path $manifest) {
            $meta = Get-Content $manifest | ConvertFrom-Json
            $sizeStr = if ($meta.TotalSizeBytes -gt 1GB) { "$([math]::Round($meta.TotalSizeBytes/1GB,2)) GB" }
                       else { "$([math]::Round($meta.TotalSizeBytes/1MB,1)) MB" }
            Write-Host "  $($backup.Name) - $($meta.TotalFiles) files, $sizeStr" -ForegroundColor White
        } else {
            Write-Host "  $($backup.Name)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`nUsage: .\Restore-UserProfile.ps1 -BackupDate `"yyyy-MM-dd`"" -ForegroundColor Yellow
    exit 0
}

$BackupPath = Join-Path $BackupRoot $BackupDate

if (-not (Test-Path $BackupPath)) {
    Write-Host "Backup not found: $BackupPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== User Profile Restore ===" -ForegroundColor Cyan
Write-Host "Source: $BackupPath" -ForegroundColor Gray
Write-Host "Destination: $UserProfile" -ForegroundColor Gray

# Read manifest
$manifestPath = Join-Path $BackupPath "backup-manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    Write-Host "Backup Date: $($manifest.Date) $($manifest.Time)" -ForegroundColor Gray
}

# Get folders to restore
if ($Folders) {
    $TargetFolders = $Folders
} elseif ($manifest -and $manifest.Folders) {
    $TargetFolders = $manifest.Folders
} else {
    $TargetFolders = Get-ChildItem $BackupPath -Directory | Select-Object -ExpandProperty Name
}

Write-Host ""

foreach ($folder in $TargetFolders) {
    $sourcePath = Join-Path $BackupPath $folder
    $destPath = Join-Path $UserProfile $folder
    
    if (-not (Test-Path $sourcePath)) {
        Write-Host "  [SKIP] $folder (not in backup)" -ForegroundColor DarkGray
        continue
    }
    
    $isFile = (Get-Item $sourcePath -ErrorAction SilentlyContinue).PSIsContainer -eq $false
    
    if ($isFile) {
        if ($WhatIf) {
            Write-Host "  [FILE] $folder" -ForegroundColor Yellow
        } else {
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item $sourcePath -Destination $destPath -Force
            Write-Host "  [OK] $folder" -ForegroundColor Green
        }
    } else {
        $fileCount = (Get-ChildItem $sourcePath -Recurse -File -ErrorAction SilentlyContinue).Count
        
        if ($WhatIf) {
            Write-Host "  [DIR] $folder ($fileCount files)" -ForegroundColor Yellow
        } else {
            # Use robocopy for restore
            $null = robocopy $sourcePath $destPath /E /NFL /NDL /NJH /NJS /R:1 /W:1 2>$null
            Write-Host "  [OK] $folder ($fileCount files)" -ForegroundColor Green
        }
    }
}

if ($WhatIf) {
    Write-Host "`n[DRY RUN] No files were restored. Remove -WhatIf to perform restore." -ForegroundColor Yellow
} else {
    Write-Host "`nRestore complete!" -ForegroundColor Green
}
