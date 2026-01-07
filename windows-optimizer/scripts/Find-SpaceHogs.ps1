<#
.SYNOPSIS
    Analyzes user profile folders to find space hogs.
.DESCRIPTION
    Scans user profile and common locations for large folders that can be moved or cleaned.
.PARAMETER MinSizeGB
    Minimum folder size in GB to report (default: 1)
.EXAMPLE
    .\Find-SpaceHogs.ps1
    .\Find-SpaceHogs.ps1 -MinSizeGB 5
#>
[CmdletBinding()]
param(
    [double]$MinSizeGB = 1
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== SPACE HOG ANALYZER ===" -ForegroundColor Cyan
Write-Host "Scanning folders (this may take a minute)...`n"

$results = @()

# User profile folders
Get-ChildItem "$env:USERPROFILE" -Directory -Force | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -Force -EA SilentlyContinue | 
             Measure-Object Length -Sum -EA SilentlyContinue).Sum / 1GB
    if ($size -ge $MinSizeGB) {
        $category = switch -Wildcard ($_.Name) {
            ".ollama" { "LLM Models (moveable)" }
            ".lmstudio" { "LLM Models (moveable)" }
            "Downloads" { "Downloads (cleanable)" }
            "Videos" { "Media (moveable)" }
            "Pictures" { "Media (moveable)" }
            "Music" { "Media (moveable)" }
            ".nuget" { "Dev Cache (cleanable)" }
            ".npm" { "Dev Cache (cleanable)" }
            ".cache" { "Cache (cleanable)" }
            ".docker" { "Docker (moveable)" }
            "AppData" { "App Data (mixed)" }
            ".vscode*" { "VS Code (cleanable)" }
            ".cursor" { "Cursor (cleanable)" }
            ".windsurf" { "Windsurf (cleanable)" }
            "OneDrive*" { "Cloud Sync" }
            "scoop" { "Package Manager" }
            default { "Other" }
        }
        
        $results += [PSCustomObject]@{
            Folder = $_.Name
            SizeGB = [math]::Round($size, 2)
            Path = $_.FullName
            Category = $category
        }
    }
}

# Sort and display
$results = $results | Sort-Object SizeGB -Descending

if ($results.Count -eq 0) {
    Write-Host "No folders found larger than $MinSizeGB GB" -ForegroundColor Yellow
    exit 0
}

$totalSize = ($results | Measure-Object SizeGB -Sum).Sum

Write-Host "LARGE FOLDERS (>$MinSizeGB GB):`n" -ForegroundColor Yellow
Write-Host ("{0,-25} {1,10} {2}" -f "FOLDER", "SIZE", "CATEGORY") -ForegroundColor Gray
Write-Host ("-" * 60)

foreach ($r in $results) {
    $color = switch ($r.Category) {
        { $_ -match "cleanable" } { "Green" }
        { $_ -match "moveable" } { "Yellow" }
        default { "White" }
    }
    Write-Host ("{0,-25} {1,7} GB  {2}" -f $r.Folder, $r.SizeGB, $r.Category) -ForegroundColor $color
}

Write-Host ("-" * 60)
Write-Host ("TOTAL: {0} GB" -f [math]::Round($totalSize, 1)) -ForegroundColor Cyan

# Recommendations
$cleanable = $results | Where-Object { $_.Category -match "cleanable" }
$moveable = $results | Where-Object { $_.Category -match "moveable" }

if ($cleanable) {
    $cleanSize = ($cleanable | Measure-Object SizeGB -Sum).Sum
    Write-Host "`nCLEANABLE: ~$([math]::Round($cleanSize, 1)) GB" -ForegroundColor Green
    $cleanable | ForEach-Object { Write-Host "  - $($_.Folder)" -ForegroundColor Green }
}

if ($moveable) {
    $moveSize = ($moveable | Measure-Object SizeGB -Sum).Sum
    Write-Host "`nMOVEABLE TO OTHER DRIVE: ~$([math]::Round($moveSize, 1)) GB" -ForegroundColor Yellow
    $moveable | ForEach-Object { Write-Host "  - $($_.Folder)" -ForegroundColor Yellow }
}

Write-Host ""
