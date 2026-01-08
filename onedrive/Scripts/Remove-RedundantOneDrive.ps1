$InformationPreference = 'Continue'

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
    Write-Information "[31m❌ Cannot remove primary OneDrive location: $PrimaryLocation`e[0m"
    exit 1
}

# Check if path exists
if (-not (Test-Path $Path)) {
    Write-Information "[32m✅ Folder does not exist: $Path`e[0m"
    exit 0
}

Write-Information "[36mAnalyzing: $Path`e[0m"

# Count contents
$fileCount = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
$folderCount = (Get-ChildItem $Path -Recurse -Directory -ErrorAction SilentlyContinue | Measure-Object).Count

Write-Information "[90m  Files: $fileCount`e[0m"
Write-Information "[90m  Folders: $folderCount`e[0m"

# If not empty and no Force flag, require confirmation
if ($fileCount -gt 0 -and -not $Force) {
    Write-Information "[33m`n⚠️  Folder contains $fileCount files!`e[0m"
    $confirmation = Read-Host "Are you sure you want to delete this folder? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Information "[90mCancelled.`e[0m"
        exit 0
    }
}

# Perform removal
try {
    Remove-Item $Path -Recurse -Force -ErrorAction Stop
    Write-Information "[32m✅ Successfully removed: $Path`e[0m"
} catch {
    Write-Information "[31m❌ Failed to remove folder: $_`e[0m"
    exit 1
}
