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

$InformationPreference = 'Continue'

$tempFolder = Join-Path $PSScriptRoot "..\temp"
$tempFolder = [System.IO.Path]::GetFullPath($tempFolder)

if (-not (Test-Path $tempFolder)) {
    Write-Information "[33mTemp folder does not exist: $tempFolder`e[0m"
    exit 0
}

# Get all files except .gitkeep
$files = Get-ChildItem -Path $tempFolder -File -Recurse | Where-Object { $_.Name -ne ".gitkeep" }

if ($files.Count -eq 0) {
    Write-Information "[32m✓ Temp folder is already clean.`e[0m"
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

Write-Information "[36m`n=== Slack Temp Files ===`e[0m"
Write-Information "[90mLocation: $tempFolder`e[0m"
Write-Information "[97mFiles: $($files.Count)`e[0m"
Write-Information "[97mTotal Size: $sizeStr`e[0m"
Write-Information ""

if ($ListOnly) {
    Write-Information "[33mFiles that would be deleted:`e[0m"
    foreach ($file in $files) {
        $fileSize = if ($file.Length -gt 1KB) {
            "{0:N1} KB" -f ($file.Length / 1KB)
        } else {
            "$($file.Length) bytes"
        }
        Write-Information "[97m  • $($file.Name) ($fileSize)`e[0m"
    }
    exit 0
}

# Confirm deletion
if (-not $Force) {
    $response = Read-Host "Delete $($files.Count) temp files? (y/N)"
    if ($response -notmatch '^[yY]') {
        Write-Information "[33mCancelled.`e[0m"
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
    Write-Information "[32m✓ Deleted $deleted temp files ($sizeStr freed).`e[0m"
} else {
    Write-Information "[33mDeleted $deleted files, $errors errors.`e[0m"
}
