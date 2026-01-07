<#
.SYNOPSIS
    Cleans up User PATH by removing duplicates and dead entries.
.DESCRIPTION
    - Removes duplicate entries
    - Removes dead paths that no longer exist
    - Does NOT require administrator privileges
#>

Write-Host "=== User PATH Cleanup ===" -ForegroundColor Cyan

# Backup first
$backup = [Environment]::GetEnvironmentVariable("Path", "User")
$backupFile = "$env:TEMP\user_path_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
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
    if (Test-Path $p -ErrorAction SilentlyContinue) {
        $valid += $p
    } else {
        $dead += $p
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
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "User PATH updated successfully!" -ForegroundColor Green
    Write-Host "Run: `$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')" -ForegroundColor Yellow
} else {
    Write-Host "Cancelled. No changes made." -ForegroundColor Yellow
}
