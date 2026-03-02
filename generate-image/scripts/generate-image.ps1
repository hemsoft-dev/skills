<#
.SYNOPSIS
    Generates an image using Nano Banana 2 (Gemini 3.1 Flash Image) via OpenRouter API.

.DESCRIPTION
    Uses google/gemini-3.1-flash-image-preview — Pro-level visual quality at Flash speed and cost.
    Cost: ~$0.08-0.12/image
    Supports contextual understanding, image editing, and multi-turn conversations.

.PARAMETER Prompt
    The text prompt describing the image to generate.

.PARAMETER OutputPath
    The full absolute path where the image will be saved.

.PARAMETER Preview
    Opens the generated image in Directory Opus viewer after saving.

.EXAMPLE
    .\generate-image.ps1 -Prompt "A futuristic cityscape at night" -OutputPath "D:\city.png"

.EXAMPLE
    .\generate-image.ps1 -Prompt "A futuristic cityscape at night" -OutputPath "D:\city.png" -Preview
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Prompt,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Preview
)

$InformationPreference = 'Continue'
$ErrorActionPreference = "Stop"
$Model = "google/gemini-3.1-flash-image-preview"

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

Write-Information "`e[36mGenerating with Nano Banana 2 (Gemini 3.1 Flash Image)...`e[0m"

$body = @{
    model    = $Model
    messages = @(@{ role = "user"; content = "Generate an image: $Prompt" })
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/chat/completions" `
    -Method Post `
    -Headers @{ "Authorization" = "Bearer $apiKey"; "Content-Type" = "application/json" } `
    -Body $body

$msg = $response.choices[0].message

# Helper function to open preview
function Open-ImagePreview {
    param([string]$ImagePath)
    $dopusViewer = "C:\Program Files\GPSoftware\Directory Opus\d8viewer.exe"
    if (Test-Path $dopusViewer) {
        Write-Information "`e[36mOpening preview in Directory Opus...`e[0m"
        Start-Process $dopusViewer -ArgumentList "`"$ImagePath`""
    } else {
        Start-Process $ImagePath
    }
}

# Helper to save and report
function Save-Image {
    param([byte[]]$Bytes)
    [IO.File]::WriteAllBytes($OutputPath, $Bytes)
    $size = [math]::Round((Get-Item $OutputPath).Length / 1024)
    Write-Information "`e[32m✓ Saved: $OutputPath (${size}KB)`e[0m"
    if ($Preview) { Open-ImagePreview -ImagePath $OutputPath }
    # Show credit balance
    $balanceScript = Join-Path $PSScriptRoot "Get-OpenRouterBalance.ps1"
    if (Test-Path $balanceScript) { & $balanceScript }
}

# Method 1: Check images array
if ($msg.images -and $msg.images.Count -gt 0) {
    $imgData = $msg.images[0]
    $imgUrl = if ($imgData.image_url.url) { $imgData.image_url.url } else { $imgData.image_url }

    if ($imgUrl -match '^data:image/[^;]+;base64,(.+)$') {
        Save-Image -Bytes ([Convert]::FromBase64String($matches[1]))
        exit 0
    }
}

# Method 2: Check content for inline base64
if ($msg.content -and $msg.content -match 'data:image/[^;]+;base64,([A-Za-z0-9+/=]+)') {
    Save-Image -Bytes ([Convert]::FromBase64String($matches[1]))
    exit 0
}

throw "No image data found. Keys in message: $($msg.PSObject.Properties.Name -join ', ')"
