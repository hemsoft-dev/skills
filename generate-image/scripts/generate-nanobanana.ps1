<#
.SYNOPSIS
    Generates an image using Nano Banana (Gemini 2.5 Flash Image) via OpenRouter API.

.DESCRIPTION
    Nano Banana (google/gemini-2.5-flash-image) is Google's contextual image generation model.
    Cost: $0.30/M input tokens, $2.50/M output tokens (~$0.10-0.15/image typical)
    Response format: choices[0].message.content contains inline base64 data URL

.PARAMETER Prompt
    The text prompt describing the image to generate.

.PARAMETER OutputPath
    The full absolute path where the image will be saved.

.PARAMETER Preview
    Opens the generated image in Directory Opus viewer after saving.

.EXAMPLE
    .\generate-nanobanana.ps1 -Prompt "A cute banana mascot" -OutputPath "D:\banana.png"

.EXAMPLE
    .\generate-nanobanana.ps1 -Prompt "A cute banana mascot" -OutputPath "D:\banana.png" -Preview
#>

$InformationPreference = 'Continue'

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Prompt,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Preview
)

$ErrorActionPreference = "Stop"
$Model = "google/gemini-2.5-flash-image"

# Validate OutputPath
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    throw "OutputPath must be absolute: $OutputPath"
}

# Ensure directory exists
$dir = [System.IO.Path]::GetDirectoryName($OutputPath)
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Get API key
$apiKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
if (-not $apiKey) { $apiKey = $env:OPENROUTER_API_KEY }
if (-not $apiKey) { throw "OPENROUTER_API_KEY not set" }

Write-Information "Generating with Nano Banana (Gemini 2.5 Flash)..." -ForegroundColor Cyan

$body = @{
    model = $Model
    messages = @(@{ role = "user"; content = "Generate an image: $Prompt" })
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/chat/completions" `
    -Method Post `
    -Headers @{ "Authorization" = "Bearer $apiKey"; "Content-Type" = "application/json" } `
    -Body $body

$msg = $response.choices[0].message

# Nano Banana returns base64 in message.content as inline data URL
# Or in message.images array - check both

# Helper function to open preview
function Open-ImagePreview {
    param([string]$ImagePath)
    $dopusViewer = "C:\Program Files\GPSoftware\Directory Opus\d8viewer.exe"
    if (Test-Path $dopusViewer) {
        Write-Information "Opening preview in Directory Opus..." -ForegroundColor Cyan
        Start-Process $dopusViewer -ArgumentList "`"$ImagePath`""
    } else {
        Write-Information "Directory Opus viewer not found. Opening with default viewer..." -ForegroundColor Yellow
        Start-Process $ImagePath
    }
}

# Method 1: Check images array first
if ($msg.images -and $msg.images.Count -gt 0) {
    $imgData = $msg.images[0]
    $imgUrl = if ($imgData.image_url.url) { $imgData.image_url.url } else { $imgData.image_url }
    
    if ($imgUrl -match '^data:image/[^;]+;base64,(.+)$') {
        [IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($matches[1]))
        $size = [math]::Round((Get-Item $OutputPath).Length / 1024)
        Write-Information "✓ Saved: $OutputPath (${size}KB)" -ForegroundColor Green
        if ($Preview) { Open-ImagePreview -ImagePath $OutputPath }
        exit 0
    }
}

# Method 2: Check content for inline base64
if ($msg.content -and $msg.content -match 'data:image/[^;]+;base64,([A-Za-z0-9+/=]+)') {
    [IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($matches[1]))
    $size = [math]::Round((Get-Item $OutputPath).Length / 1024)
    Write-Information "✓ Saved: $OutputPath (${size}KB)" -ForegroundColor Green
    if ($Preview) { Open-ImagePreview -ImagePath $OutputPath }
    exit 0
}

# Debug: show what we got
throw "No image data found. Keys in message: $($msg.PSObject.Properties.Name -join ', ')"
