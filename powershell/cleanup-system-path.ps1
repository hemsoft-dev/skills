#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Cleans up System PATH by removing duplicates and dead entries.
.DESCRIPTION
    - Removes duplicate entries
    - Removes dead paths that no longer exist
    - Reduces PATH length to stay under the 2048 char limit
.NOTES
    Run this script as Administrator
#>

Write-Host "=== System PATH Cleanup ===" -ForegroundColor Cyan

# Backup first
$backup = [Environment]::GetEnvironmentVariable("Path", "Machine")
$backupFile = "$env:TEMP\system_path_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$backup | Out-File $backupFile
Write-Host "Backed up to: $backupFile" -ForegroundColor Green

# Current state
$paths = $backup -split ";" | Where-Object { $_ }
Write-Host "Current entries: $($paths.Count)"
Write-Host "Current length: $($backup.Length) chars"

# Remove duplicates (keep first occurrence)
$unique = @()
$seen = @{}
foreach ($p in $paths) {
    $normalized = $p.ToLower().TrimEnd('\')
    if (-not $seen.ContainsKey($normalized)) {
        $seen[$normalized] = $true
        $unique += $p
    }
}
$dupeCount = $paths.Count - $unique.Count
Write-Host "Duplicates removed: $dupeCount" -ForegroundColor Yellow

# Remove dead paths
$valid = @()
$dead = @()
foreach ($p in $unique) {
    try {
        if (Test-Path $p -ErrorAction Stop) {
            $valid += $p
        } else {
            $dead += $p
        }
    } catch {
        # Access denied or other error - keep it to be safe
        $valid += $p
    }
}
Write-Host "Dead paths removed: $($dead.Count)" -ForegroundColor Yellow
$dead | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }

# Build new PATH
$newPath = $valid -join ";"
Write-Host "`nNew length: $($newPath.Length) chars (saved $($backup.Length - $newPath.Length) chars)" -ForegroundColor Green

# Confirm and apply
$confirm = Read-Host "`nApply changes? (y/n)"
if ($confirm -eq 'y') {
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Host "System PATH updated successfully!" -ForegroundColor Green
    Write-Host "Please restart your terminals or sign out/in for changes to take effect." -ForegroundColor Yellow
} else {
    Write-Host "Cancelled. No changes made." -ForegroundColor Yellow
}
