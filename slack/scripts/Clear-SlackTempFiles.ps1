<#
.SYNOPSIS
    Clean up temporary files downloaded by Slack scripts.

.DESCRIPTION
    Removes all files from the Slack skill temp folder except .gitkeep.
    Run this at the end of a session or when temp files are no longer needed.

.PARAMETER Force
    Skip confirmation prompt and delete all files immediately.

.PARAMETER ListOnly
    List files that would be deleted without actually deleting them.

.EXAMPLE
    .\Clear-SlackTempFiles.ps1
    Prompts for confirmation then cleans up temp files.

.EXAMPLE
    .\Clear-SlackTempFiles.ps1 -Force
    Immediately deletes all temp files without prompting.

.EXAMPLE
    .\Clear-SlackTempFiles.ps1 -ListOnly
    Shows what files would be deleted.
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$ListOnly
)

$tempFolder = Join-Path $PSScriptRoot "..\temp"
$tempFolder = [System.IO.Path]::GetFullPath($tempFolder)

if (-not (Test-Path $tempFolder)) {
    Write-Host "Temp folder does not exist: $tempFolder" -ForegroundColor Yellow
    exit 0
}

# Get all files except .gitkeep
$files = Get-ChildItem -Path $tempFolder -File -Recurse | Where-Object { $_.Name -ne ".gitkeep" }

if ($files.Count -eq 0) {
    Write-Host "✓ Temp folder is already clean." -ForegroundColor Green
    exit 0
}

# Calculate total size
$totalSize = ($files | Measure-Object -Property Length -Sum).Sum
$sizeStr = if ($totalSize -gt 1MB) {
    "{0:N2} MB" -f ($totalSize / 1MB)
} elseif ($totalSize -gt 1KB) {
    "{0:N2} KB" -f ($totalSize / 1KB)
} else {
    "$totalSize bytes"
}

Write-Host "`n=== Slack Temp Files ===" -ForegroundColor Cyan
Write-Host "Location: $tempFolder" -ForegroundColor Gray
Write-Host "Files: $($files.Count)" -ForegroundColor White
Write-Host "Total Size: $sizeStr" -ForegroundColor White
Write-Host ""

if ($ListOnly) {
    Write-Host "Files that would be deleted:" -ForegroundColor Yellow
    foreach ($file in $files) {
        $fileSize = if ($file.Length -gt 1KB) {
            "{0:N1} KB" -f ($file.Length / 1KB)
        } else {
            "$($file.Length) bytes"
        }
        Write-Host "  • $($file.Name) ($fileSize)" -ForegroundColor White
    }
    exit 0
}

# Confirm deletion
if (-not $Force) {
    $response = Read-Host "Delete $($files.Count) temp files? (y/N)"
    if ($response -notmatch '^[yY]') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Delete files
$deleted = 0
$errors = 0

foreach ($file in $files) {
    try {
        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
        $deleted++
    } catch {
        Write-Warning "Failed to delete: $($file.Name) - $_"
        $errors++
    }
}

# Summary
if ($errors -eq 0) {
    Write-Host "✓ Deleted $deleted temp files ($sizeStr freed)." -ForegroundColor Green
} else {
    Write-Host "Deleted $deleted files, $errors errors." -ForegroundColor Yellow
}
