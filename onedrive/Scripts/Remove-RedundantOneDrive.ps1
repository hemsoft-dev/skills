# Remove-RedundantOneDrive.ps1
# Safely removes redundant OneDrive folders after verification

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    
    [string]$PrimaryLocation = "D:\OneDrive",
    
    [switch]$Force
)

# Safety check: Don't allow removal of primary location
if ($Path -eq $PrimaryLocation) {
    Write-Host "❌ Cannot remove primary OneDrive location: $PrimaryLocation" -ForegroundColor Red
    exit 1
}

# Check if path exists
if (-not (Test-Path $Path)) {
    Write-Host "✅ Folder does not exist: $Path" -ForegroundColor Green
    exit 0
}

Write-Host "Analyzing: $Path" -ForegroundColor Cyan

# Count contents
$fileCount = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
$folderCount = (Get-ChildItem $Path -Recurse -Directory -ErrorAction SilentlyContinue | Measure-Object).Count

Write-Host "  Files: $fileCount" -ForegroundColor Gray
Write-Host "  Folders: $folderCount" -ForegroundColor Gray

# If not empty and no Force flag, require confirmation
if ($fileCount -gt 0 -and -not $Force) {
    Write-Host "`n⚠️  Folder contains $fileCount files!" -ForegroundColor Yellow
    $confirmation = Read-Host "Are you sure you want to delete this folder? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Cancelled." -ForegroundColor Gray
        exit 0
    }
}

# Perform removal
try {
    Remove-Item $Path -Recurse -Force -ErrorAction Stop
    Write-Host "✅ Successfully removed: $Path" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to remove folder: $_" -ForegroundColor Red
    exit 1
}
