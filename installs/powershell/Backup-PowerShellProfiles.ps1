<#
.SYNOPSIS
    Backs up PowerShell profile files to this folder.
.DESCRIPTION
    Copies all PowerShell 7 profile files that exist.
#>
$InformationPreference = 'Continue'

[CmdletBinding()]
param()

$backupDir = $PSScriptRoot

Write-Information "Backing up PowerShell profiles..." -ForegroundColor Cyan

# PowerShell 7 profiles (CurrentUser)
$profiles = @{
    "Microsoft.PowerShell_profile.ps1" = $PROFILE.CurrentUserCurrentHost
    "profile.ps1" = $PROFILE.CurrentUserAllHosts
}

foreach ($item in $profiles.GetEnumerator()) {
    if (Test-Path $item.Value) {
        Copy-Item $item.Value -Destination (Join-Path $backupDir $item.Key) -Force
        Write-Information "  ✓ $($item.Key)" -ForegroundColor Green
    }
    else {
        Write-Information "  - $($item.Key) (not found)" -ForegroundColor Gray
    }
}

# Also backup Oh-My-Posh theme if it exists
$ompConfig = "$env:USERPROFILE\.config\omp"
if (Test-Path $ompConfig) {
    $ompBackupDir = Join-Path $backupDir "omp"
    if (-not (Test-Path $ompBackupDir)) {
        New-Item -Path $ompBackupDir -ItemType Directory -Force | Out-Null
    }
    Get-ChildItem "$ompConfig\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName -Destination $ompBackupDir -Force
        Write-Information "  ✓ omp/$($_.Name)" -ForegroundColor Green
    }
}

Write-Information "PowerShell backup complete!" -ForegroundColor Green
