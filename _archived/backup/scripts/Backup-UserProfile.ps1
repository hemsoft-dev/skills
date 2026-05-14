<#
.SYNOPSIS
    Backs up user profile folders to OneDrive backup location.
.DESCRIPTION
    Creates timestamped backups of important user folders with support for
    incremental backups, exclusions, and dry-run mode.
.PARAMETER Folders
    Specific folders to back up (relative to user profile). If not specified, uses defaults.
.PARAMETER BackupRoot
    Destination root folder. Default: F:\OneDrive\User-Backup
.PARAMETER WhatIf
    Show what would be backed up without copying files.
.PARAMETER Full
    Include all default folders (dev config, IDE settings, shell config, important data).
.PARAMETER Incremental
    Only copy files newer than last backup (default behavior).
.EXAMPLE
    .\Backup-UserProfile.ps1
    .\Backup-UserProfile.ps1 -Folders ".claude",".ssh"
    .\Backup-UserProfile.ps1 -WhatIf
#>


param(
    [string[]]$Folders,
    [string]$BackupRoot = "F:\OneDrive\User-Backup",
    [switch]$WhatIf,
    [switch]$Full,
    [switch]$Incremental = $true
)

$InformationPreference = 'Continue'

$ErrorActionPreference = "SilentlyContinue"
$UserProfile = $env:USERPROFILE
$Date = Get-Date -Format "yyyy-MM-dd"
$Time = Get-Date -Format "HHmmss"
$BackupPath = Join-Path $BackupRoot $Date

# Default folders to back up
$DefaultFolders = @(
    # Dev Config
    ".claude"
    ".ssh"
    ".gitconfig"
    ".npmrc"
    ".cargo\config.toml"
    ".config"
    
    # IDE Settings
    ".vscode\extensions.json"
    ".vscode-insiders\extensions.json"
    "AppData\Roaming\Code - Insiders\User\settings.json"
    "AppData\Roaming\Code - Insiders\User\keybindings.json"
    "AppData\Roaming\Code\User\settings.json"
    "AppData\Roaming\Code\User\keybindings.json"
    
    # Shell Config
    "Documents\PowerShell"
    
    # Important Data
    "Documents"
    "Desktop"
    "Pictures"
)

# Folders to always exclude
$Exclusions = @(
    "node_modules"
    ".git"
    "bin"
    "obj"
    "__pycache__"
    ".next"
    "dist"
    "build"
    "*.log"
    "Thumbs.db"
    ".DS_Store"
)

# Use provided folders or defaults
if ($Folders) {
    $TargetFolders = $Folders
} else {
    $TargetFolders = $DefaultFolders
}

Write-Information "[36m`n=== User Profile Backup ===`e[0m"
Write-Information "[90mSource: $UserProfile`e[0m"
Write-Information "[90mDestination: $BackupPath`e[0m"
Write-Information "[90mDate: $Date $Time`n`e[0m"

if (-not $WhatIf) {
    # Create backup directory
    if (-not (Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        Write-Information "[32mCreated backup folder: $BackupPath`e[0m"
    }
}

$TotalSize = 0
$TotalFiles = 0
$BackedUp = @()

foreach ($folder in $TargetFolders) {
    $sourcePath = Join-Path $UserProfile $folder
    
    if (-not (Test-Path $sourcePath)) {
        Write-Information "[90m  [SKIP] $folder (not found)`e[0m"
        continue
    }
    
    $isFile = (Get-Item $sourcePath).PSIsContainer -eq $false
    
    if ($isFile) {
        # Single file backup
        $destPath = Join-Path $BackupPath $folder
        $destDir = Split-Path $destPath -Parent
        $size = (Get-Item $sourcePath).Length
        $TotalSize += $size
        $TotalFiles++
        
        if ($WhatIf) {
            Write-Information "[33m  [FILE] $folder ($([math]::Round($size/1KB,1)) KB)`e[0m"
        } else {
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item $sourcePath -Destination $destPath -Force
            Write-Information "[32m  [OK] $folder`e[0m"
            $BackedUp += $folder
        }
    } else {
        # Folder backup with exclusions
        $files = Get-ChildItem $sourcePath -Recurse -File -ErrorAction SilentlyContinue | 
            Where-Object { 
                $path = $_.FullName
                -not ($Exclusions | Where-Object { $path -like "*\$_*" -or $path -like "*$_" })
            }
        
        $folderSize = ($files | Measure-Object Length -Sum).Sum
        $fileCount = $files.Count
        $TotalSize += $folderSize
        $TotalFiles += $fileCount
        
        $sizeStr = if ($folderSize -gt 1GB) { "$([math]::Round($folderSize/1GB,2)) GB" }
                   elseif ($folderSize -gt 1MB) { "$([math]::Round($folderSize/1MB,1)) MB" }
                   else { "$([math]::Round($folderSize/1KB,1)) KB" }
        
        if ($WhatIf) {
            Write-Information "[33m  [DIR] $folder ($fileCount files, $sizeStr)`e[0m"
        } else {
            $destPath = Join-Path $BackupPath $folder
            
            # Use robocopy for efficient copying with exclusions
            $robocopyArgs = @(
                $sourcePath
                $destPath
                "/E"           # Recurse
                "/XO"          # Exclude older files (incremental)
                "/NFL"         # No file list
                "/NDL"         # No directory list
                "/NJH"         # No job header
                "/NJS"         # No job summary
                "/R:1"         # 1 retry
                "/W:1"         # 1 second wait
            )
            
            # Add exclusions
            foreach ($ex in $Exclusions) {
                $robocopyArgs += "/XD"
                $robocopyArgs += $ex
            }
            $robocopyArgs += "/XF"
            $robocopyArgs += "*.log"
            $robocopyArgs += "Thumbs.db"
            $robocopyArgs += ".DS_Store"
            
            $null = robocopy @robocopyArgs 2>$null
            
            Write-Information "[32m  [OK] $folder ($fileCount files, $sizeStr)`e[0m"
            $BackedUp += $folder
        }
    }
}

# Summary
$totalStr = if ($TotalSize -gt 1GB) { "$([math]::Round($TotalSize/1GB,2)) GB" }
            elseif ($TotalSize -gt 1MB) { "$([math]::Round($TotalSize/1MB,1)) MB" }
            else { "$([math]::Round($TotalSize/1KB,1)) KB" }

Write-Information "[36m`n--- Summary ---`e[0m"
Write-Information "[97mTotal: $TotalFiles files, $totalStr`e[0m"

if ($WhatIf) {
    Write-Information "[33m`n[DRY RUN] No files were copied. Remove -WhatIf to perform backup.`e[0m"
} else {
    Write-Information "[32mBackup complete: $BackupPath`e[0m"
    
    # Create manifest
    $manifest = @{
        Date = $Date
        Time = $Time
        Source = $UserProfile
        Destination = $BackupPath
        Folders = $BackedUp
        TotalFiles = $TotalFiles
        TotalSizeBytes = $TotalSize
    }
    $manifest | ConvertTo-Json | Out-File (Join-Path $BackupPath "backup-manifest.json")
}
