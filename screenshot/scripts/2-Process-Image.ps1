param(
    [Parameter(Mandatory=$true)]
    [string]$ImagePath,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationSkill,
    
    [Parameter(Mandatory=$false)]
    [string[]]$Tags = @(),
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoDescription,
    
    [Parameter(Mandatory=$false)]
    [string]$CustomDescription = "",
    
    [Parameter(Mandatory=$false)]
    [string]$SuggestedFilename = "",

    [Parameter(Mandatory=$false)]
    [string]$Source = "SnagIt",

    [Parameter(Mandatory=$false)]
    [string]$SourceLibrary = "D:\OneDrive\Snagit"
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Screenshot Import ===" -ForegroundColor Cyan

# Validate image exists
if (-not (Test-Path $ImagePath)) {
    Write-Host "ERROR: Image not found: $ImagePath" -ForegroundColor Red
    exit 1
}

# Validate skill exists
$skillPath = "$env:USERPROFILE\.agents\skills\$DestinationSkill"
if (-not (Test-Path $skillPath)) {
    Write-Host "ERROR: Skill not found: $DestinationSkill" -ForegroundColor Red
    exit 1
}

# Create images/library structure
$today = Get-Date -Format "yyyy-MM-dd"
$libraryPath = Join-Path $skillPath "images\library\$today"
if (-not (Test-Path $libraryPath)) {
    New-Item -Path $libraryPath -ItemType Directory -Force | Out-Null
    Write-Host "Created library folder: images/library/$today" -ForegroundColor Gray
}

# Get original file info
$originalFile = Get-Item $ImagePath

# Generate clean filename
if ($SuggestedFilename) {
    # Use suggested filename from metadata
    $cleanName = $SuggestedFilename -replace '[^\w\-]', '-' -replace '-+', '-'
} else {
    # Fall back to original filename
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($originalFile.Name)
    $cleanName = $baseName -replace '[^\w\-]', '-' -replace '-+', '-'
}

$webpName = "$cleanName.webp"
$webpPath = Join-Path $libraryPath $webpName

# Auto-deduplicate: if file exists, add numeric suffix instead of overwriting
if (Test-Path $webpPath) {
    $counter = 2
    do {
        $webpName = "$cleanName-$counter.webp"
        $webpPath = Join-Path $libraryPath $webpName
        $counter++
    } while (Test-Path $webpPath)
    Write-Host "  Auto-renamed to avoid collision: $webpName" -ForegroundColor Yellow
}

# Copy and compress to WebP
Write-Host "Compressing to WebP..." -ForegroundColor Gray
$ffmpegArgs = @(
    "-i", $ImagePath,
    "-vf", "scale=1024:-1",
    "-c:v", "libwebp",
    "-quality", "85",
    $webpPath,
    "-y"
)
$ffmpegOutput = & ffmpeg @ffmpegArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: FFmpeg compression failed" -ForegroundColor Red
    Write-Host $ffmpegOutput -ForegroundColor Red
    exit 1
}

# Get WebP dimensions
$probeOutput = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 $webpPath 2>&1
$dimensions = $probeOutput -split ','
$webpSize = "$($dimensions[0])x$($dimensions[1])"

# Get original dimensions
$originalProbe = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 $ImagePath 2>&1
$originalDims = $originalProbe -split ','
$originalSize = "$($originalDims[0])x$($originalDims[1])"

Write-Host "✓ Compressed: $originalSize → $webpSize" -ForegroundColor Green

# Generate description and extract text
$description = ""
$textContent = ""

if ($AutoDescription) {
    Write-Host "Generating AI description and extracting text..." -ForegroundColor Gray
    $descScriptPath = "$env:USERPROFILE\.agents\skills\text-read-image\scripts\read-text.ps1"
    
    if (Test-Path $descScriptPath) {
        # Generate description
        $description = & $descScriptPath -ImagePath $webpPath -Prompt "Provide a brief 1-2 sentence description of what this image shows. Focus on the main content, purpose, and any visible text or UI elements."
        
        # Extract all visible text (OCR)
        $textContent = & $descScriptPath -ImagePath $webpPath -Prompt "Extract ALL visible text from this image. Preserve formatting and line breaks. If there is no text, respond with 'No text detected'."
        
        if ($description) {
            Write-Host "✓ Description generated" -ForegroundColor Green
        } else {
            Write-Host "WARNING: Description generation failed" -ForegroundColor Yellow
            $description = "[Auto-description failed]"
        }
        
        if ($textContent) {
            Write-Host "✓ Text extracted" -ForegroundColor Green
        } else {
            $textContent = "[No text extracted]"
        }
    } else {
        Write-Host "WARNING: text-read-image script not found, skipping auto-description" -ForegroundColor Yellow
        $description = "[Auto-description not available]"
        $textContent = "[Text extraction not available]"
    }
} elseif ($CustomDescription) {
    $description = $CustomDescription
    $textContent = "[Text extraction skipped - custom description provided]"
} else {
    $description = "Imported from SnagIt on $today"
    $textContent = "[Text extraction not requested]"
}

# Create metadata JSON
$metadata = @{
    filename = $webpName
    source = $Source
    source_library = $SourceLibrary
    imported_date = $today
    imported_time = (Get-Date -Format "HH:mm:ss")
    description = $description.Trim()
    text_content = $textContent.Trim()
    tags = $Tags
    skill = $DestinationSkill
    size_webp = $webpSize
    size_original = $originalSize
    original_filename = $originalFile.Name
    original_path = $originalFile.FullName
}

$metaPath = "$webpPath.meta.json"
$metadata | ConvertTo-Json -Depth 10 | Set-Content $metaPath -Encoding UTF8

Write-Host "✓ Metadata saved" -ForegroundColor Green

# Summary
Write-Host "`n=== Import Complete ===" -ForegroundColor Green
Write-Host "File: $webpName" -ForegroundColor White
Write-Host "Path: images/library/$today/$webpName" -ForegroundColor White
Write-Host "Skill: $DestinationSkill" -ForegroundColor White
Write-Host "Tags: $($Tags -join ', ')" -ForegroundColor White
Write-Host "Description: $($description.Substring(0, [Math]::Min(80, $description.Length)))..." -ForegroundColor White

Write-Host "`nTo reference in SKILL.md:" -ForegroundColor Cyan
Write-Host "![Description](./images/library/$today/$webpName)" -ForegroundColor Gray

