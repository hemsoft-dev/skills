<#
.SYNOPSIS
    Cleans up User PATH by removing duplicates and dead entries.
.DESCRIPTION
    - Removes duplicate entries
    - Removes dead paths that no longer exist
    - Does NOT require administrator privileges
#>

$InformationPreference = 'Continue'

Write-Information "[36m=== User PATH Cleanup ===`e[0m"

# Backup first
$backup = [Environment]::GetEnvironmentVariable("Path", "User")
$backupFile = "$env:TEMP\user_path_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$backup | Out-File $backupFile
Write-Information "[32mBacked up to: $backupFile`e[0m"

# Current state
$paths = $backup -split ";" | Where-Object { $_ }
Write-Information "Current entries: $($paths.Count)"
Write-Information "Current length: $($backup.Length) chars"

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
Write-Information "[33mDuplicates removed: $dupeCount`e[0m"

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
Write-Information "[33mDead paths removed: $($dead.Count)`e[0m"
Write-Information "[31m  - $_`e[0m"

# Build new PATH
$newPath = $valid -join ";"
Write-Information "[32m`nNew length: $($newPath.Length) chars (saved $($backup.Length - $newPath.Length) chars)`e[0m"

# Confirm and apply
$confirm = Read-Host "`nApply changes? (y/n)"
if ($confirm -eq 'y') {
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Information "[32mUser PATH updated successfully!`e[0m"
    Write-Information "[33mRun: `$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')`e[0m"
} else {
    Write-Information "[33mCancelled. No changes made.`e[0m"
}
