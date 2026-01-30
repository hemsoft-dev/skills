param(
    [Parameter(Mandatory=$true)]
    [string]$SnagItFileName,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationSkill,
    
    [Parameter(Mandatory=$false)]
    [string[]]$Tags = @(),
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoDescription = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$CustomDescription = ""
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Automated SnagIt Import ===" -ForegroundColor Cyan

$snagitLibrary = "D:\OneDrive\Snagit"

# Find the .snagx file
$snagxPath = Join-Path $snagitLibrary $SnagItFileName
if (-not $snagxPath.EndsWith(".snagx")) {
    $snagxPath = "$snagxPath.snagx"
}

if (-not (Test-Path $snagxPath)) {
    Write-Host "ERROR: SnagIt file not found: $snagxPath" -ForegroundColor Red
    Write-Host "Looking in: $snagitLibrary" -ForegroundColor Gray
    exit 1
}

Write-Host "Found: $SnagItFileName" -ForegroundColor Green

# Extract .snagx (it's a ZIP file)
$extractDir = Join-Path $env:TEMP "snagx-extract-$(Get-Random)"
New-Item -Path $extractDir -ItemType Directory -Force | Out-Null

Write-Host "Extracting image from .snagx..." -ForegroundColor Gray
try {
    Expand-Archive -Path $snagxPath -DestinationPath $extractDir -Force
} catch {
    Write-Host "ERROR: Failed to extract .snagx file" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Find the main PNG image (not thumbnail)
$pngFiles = Get-ChildItem $extractDir -Filter "*.png" | Where-Object { $_.Name -ne "thumbnail.png" }
if ($pngFiles.Count -eq 0) {
    Write-Host "ERROR: No PNG image found in .snagx file" -ForegroundColor Red
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$extractedPng = $pngFiles[0].FullName
Write-Host "✓ Extracted PNG: $($pngFiles[0].Name)" -ForegroundColor Green

# Read metadata from .snagx for smart filename generation
$metadataPath = Join-Path $extractDir "metadata.json"
$snagxMetadata = $null
$suggestedFilename = ""

if (Test-Path $metadataPath) {
    $snagxMetadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
    
    # Generate filename from metadata (AppName, WindowName, or timestamp)
    if ($snagxMetadata.WindowName) {
        # Use window name for filename (e.g., "slack-dm-bryan-halterman")
        $safeName = $snagxMetadata.WindowName -replace '[^\w\s\-]', '' -replace '\s+', '-' -replace '--+', '-'
        $suggestedFilename = $safeName.ToLower().Substring(0, [Math]::Min(50, $safeName.Length))
    }
    elseif ($snagxMetadata.AppName) {
        $timestamp = Get-Date -Format "HHmm"
        $suggestedFilename = "$($snagxMetadata.AppName.ToLower())-$timestamp"
    }
    
    Write-Host "  App: $($snagxMetadata.AppName)" -ForegroundColor Gray
    if ($snagxMetadata.WindowName) {
        Write-Host "  Window: $($snagxMetadata.WindowName)" -ForegroundColor Gray
    }
}

# Call the main import script
$importScript = Join-Path $PSScriptRoot "Import-SnagItScreenshot.ps1"
if (-not (Test-Path $importScript)) {
    Write-Host "ERROR: Import script not found: $importScript" -ForegroundColor Red
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "`nRunning import process..." -ForegroundColor Cyan

$importParams = @{
    ImagePath = $extractedPng
    DestinationSkill = $DestinationSkill
    Tags = $Tags
    SuggestedFilename = $suggestedFilename
}

if ($AutoDescription) {
    $importParams['AutoDescription'] = $true
} elseif ($CustomDescription) {
    $importParams['CustomDescription'] = $CustomDescription
}

& $importScript @importParams

# Cleanup
Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n✓ Automated import complete!" -ForegroundColor Green
