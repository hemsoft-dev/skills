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

$InformationPreference = 'Continue'

$ErrorActionPreference = "Stop"
$UserProfile = $env:USERPROFILE

# List available backups if no date specified
if (-not $BackupDate) {
    Write-Information "[36m`n=== Available Backups ===`e[0m"
    $backups = Get-ChildItem $BackupRoot -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } |
        Sort-Object Name -Descending
    
    if (-not $backups) {
        Write-Information "[31mNo backups found in $BackupRoot`e[0m"
        exit 1
    }
    
    foreach ($backup in $backups) {
        $manifest = Join-Path $backup.FullName "backup-manifest.json"
        if (Test-Path $manifest) {
            $meta = Get-Content $manifest | ConvertFrom-Json
            $sizeStr = if ($meta.TotalSizeBytes -gt 1GB) { "$([math]::Round($meta.TotalSizeBytes/1GB,2)) GB" }
                       else { "$([math]::Round($meta.TotalSizeBytes/1MB,1)) MB" }
            Write-Information "[97m  $($backup.Name) - $($meta.TotalFiles) files, $sizeStr`e[0m"
        } else {
            Write-Information "[90m  $($backup.Name)`e[0m"
        }
    }
    
    Write-Information "[33m$("`nUsage: .\Restore-UserProfile.ps1 -BackupDate `"yyyy-MM-dd`"")`e[0m"
    exit 0
}

$BackupPath = Join-Path $BackupRoot $BackupDate

if (-not (Test-Path $BackupPath)) {
    Write-Information "[31mBackup not found: $BackupPath`e[0m"
    exit 1
}

Write-Information "[36m`n=== User Profile Restore ===`e[0m"
Write-Information "[90mSource: $BackupPath`e[0m"
Write-Information "[90mDestination: $UserProfile`e[0m"

# Read manifest
$manifestPath = Join-Path $BackupPath "backup-manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    Write-Information "[90mBackup Date: $($manifest.Date) $($manifest.Time)`e[0m"
}

# Get folders to restore
if ($Folders) {
    $TargetFolders = $Folders
} elseif ($manifest -and $manifest.Folders) {
    $TargetFolders = $manifest.Folders
} else {
    $TargetFolders = Get-ChildItem $BackupPath -Directory | Select-Object -ExpandProperty Name
}

Write-Information ""

foreach ($folder in $TargetFolders) {
    $sourcePath = Join-Path $BackupPath $folder
    $destPath = Join-Path $UserProfile $folder
    
    if (-not (Test-Path $sourcePath)) {
        Write-Information "[90m  [SKIP] $folder (not in backup)`e[0m"
        continue
    }
    
    $isFile = (Get-Item $sourcePath -ErrorAction SilentlyContinue).PSIsContainer -eq $false
    
    if ($isFile) {
        if ($WhatIf) {
            Write-Information "[33m  [FILE] $folder`e[0m"
        } else {
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item $sourcePath -Destination $destPath -Force
            Write-Information "[32m  [OK] $folder`e[0m"
        }
    } else {
        $fileCount = (Get-ChildItem $sourcePath -Recurse -File -ErrorAction SilentlyContinue).Count
        
        if ($WhatIf) {
            Write-Information "[33m  [DIR] $folder ($fileCount files)`e[0m"
        } else {
            # Use robocopy for restore
            $null = robocopy $sourcePath $destPath /E /NFL /NDL /NJH /NJS /R:1 /W:1 2>$null
            Write-Information "[32m  [OK] $folder ($fileCount files)`e[0m"
        }
    }
}

if ($WhatIf) {
    Write-Information "[33m`n[DRY RUN] No files were restored. Remove -WhatIf to perform restore.`e[0m"
} else {
    Write-Information "[32m`nRestore complete!`e[0m"
}
