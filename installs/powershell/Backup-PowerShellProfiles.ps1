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

Write-Information "[36mBacking up PowerShell profiles...`e[0m"

# PowerShell 7 profiles (CurrentUser)
$profiles = @{
    "Microsoft.PowerShell_profile.ps1" = $PROFILE.CurrentUserCurrentHost
    "profile.ps1" = $PROFILE.CurrentUserAllHosts
}

foreach ($item in $profiles.GetEnumerator()) {
    if (Test-Path $item.Value) {
        Copy-Item $item.Value -Destination (Join-Path $backupDir $item.Key) -Force
        Write-Information "[32m  ✓ $($item.Key)`e[0m"
    }
    else {
        Write-Information "[90m  - $($item.Key) (not found)`e[0m"
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
        Write-Information "[32m  ✓ omp/$($_.Name)`e[0m"
    }
}

Write-Information "[32mPowerShell backup complete!`e[0m"
