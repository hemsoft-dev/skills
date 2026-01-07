<#
.SYNOPSIS
    Opens an image in Directory Opus viewer.

.DESCRIPTION
    Opens the specified image file in Directory Opus d8viewer.exe for preview.
    Falls back to the system default image viewer if Directory Opus is not installed.

.PARAMETER Path
    The path to the image file to preview.

.EXAMPLE
    .\Open-ImagePreview.ps1 -Path "D:\image.png"

.EXAMPLE
    .\Open-ImagePreview.ps1 "D:\slack-downloads\screenshot.png"
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

# Validate the file exists
if (-not (Test-Path $Path)) {
    throw "File not found: $Path"
}

# Resolve to absolute path
$Path = (Resolve-Path $Path).Path

# Directory Opus viewer location
$dopusViewer = "C:\Program Files\GPSoftware\Directory Opus\d8viewer.exe"

if (Test-Path $dopusViewer) {
    Write-Host "Opening in Directory Opus viewer: $Path" -ForegroundColor Cyan
    Start-Process $dopusViewer -ArgumentList "`"$Path`""
} else {
    Write-Host "Directory Opus not found. Opening with default viewer..." -ForegroundColor Yellow
    Start-Process $Path
}
