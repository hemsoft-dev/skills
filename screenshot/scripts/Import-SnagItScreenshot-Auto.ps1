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
        
        # Slack detection: prefix with "slack-" if it's a Slack screenshot
        $isSlack = $false
        if ($snagxMetadata.AppName -eq "Slack" -or 
            $snagxMetadata.WindowName -like "*Slack*" -or
            $snagxMetadata.WindowName -like "*|*") {  # Slack channels often have | separator
            $isSlack = $true
        }
        
        if ($isSlack) {
            # Remove "Slack |" prefix and clean up channel/DM names
            $cleanName = $snagxMetadata.WindowName -replace '^Slack\s*\|\s*', '' -replace '\s*\|.*$', ''
            $safeName = $cleanName -replace '[^\w\s\-]', '' -replace '\s+', '-' -replace '--+', '-'
            $suggestedFilename = "slack-" + $safeName.ToLower().Substring(0, [Math]::Min(45, $safeName.Length))
            Write-Host "  Detected Slack screenshot - prefixing with 'slack-'" -ForegroundColor Yellow
        }
        else {
            # Twitter/X detection: prefix with "tweet-" if it's a Twitter screenshot
            $isTwitter = $false
            $twitterIndicators = @("Home", "Post", "Twitter", "X.com", "/", "—", "X")
            foreach ($indicator in $twitterIndicators) {
                if ($snagxMetadata.WindowName -like "*$indicator*" -and 
                    ($snagxMetadata.WindowName.Length -lt 20 -or $snagxMetadata.WindowName -match "^(Home|Post|X)\s")) {
                    $isTwitter = $true
                    break
                }
            }
            
            # Check AppName for browser + short WindowName = likely Twitter
            if (-not $isTwitter -and $snagxMetadata.AppName -match "(Chrome|Edge|Firefox|Brave)" -and 
                $snagxMetadata.WindowName.Length -lt 15) {
                $isTwitter = $true
            }
            
            if ($isTwitter) {
                # Remove common twitter window names and generate meaningful slug
                $cleanName = $snagxMetadata.WindowName -replace '^(Home|Post|X)\s*[—/\-]*\s*', ''
                if ($cleanName.Length -lt 3) {
                    # Default to generic if window name doesn't have content
                    $suggestedFilename = "tweet-timeline"
                } else {
                    $safeName = $cleanName -replace '[^\w\s\-]', '' -replace '\s+', '-' -replace '--+', '-'
                    $suggestedFilename = "tweet-" + $safeName.ToLower().Substring(0, [Math]::Min(45, $safeName.Length))
                }
                Write-Host "  Detected Twitter screenshot - prefixing with 'tweet-'" -ForegroundColor Yellow
            }
        }
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
