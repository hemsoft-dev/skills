<#
.SYNOPSIS
    Generates an image using OpenRouter API.

.DESCRIPTION
    Calls OpenRouter's image generation models to generate an image based on a text prompt.
    Requires OPENROUTER_API_KEY environment variable.

.PARAMETER Prompt
    The text prompt describing the image to generate.

.PARAMETER OutputPath
    Required. The full absolute path where the image will be saved (e.g., C:\Images\output.png).

.PARAMETER Model
    Optional. The model to use. Can be a full OpenRouter model ID or a shortcut name:
    - "seedream" or "default" -> bytedance-seed/seedream-4.5 ($0.04/image)
    - "nanobanana" or "banana" -> google/gemini-2.5-flash-image ($0.30/M in, $2.50/M out)
    - "nananapro" or "pro" -> google/gemini-3-pro-image-preview ($2/M in, $12/M out)
    Default: bytedance-seed/seedream-4.5

.EXAMPLE
    .\generate-image.ps1 -Prompt "A nano banana on a fancy plate" -OutputPath "C:\Images\banana.png"

.EXAMPLE
    .\generate-image.ps1 -Prompt "A sunset over mountains" -OutputPath "D:\Pictures\sunset.png" -Model nanobanana

.EXAMPLE
    .\generate-image.ps1 -Prompt "Professional product shot" -OutputPath "C:\Images\product.png" -Model pro
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Prompt,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$Model = "seedream"
)

$ErrorActionPreference = "Stop"

# Model shortcuts mapping
$modelMap = @{
    "seedream"   = "bytedance-seed/seedream-4.5"
    "default"    = "bytedance-seed/seedream-4.5"
    "nanobanana" = "google/gemini-2.5-flash-image"
    "banana"     = "google/gemini-2.5-flash-image"
    "nananapro"  = "google/gemini-3-pro-image-preview"
    "pro"        = "google/gemini-3-pro-image-preview"
}

# Resolve model shortcut to full ID
$resolvedModel = if ($modelMap.ContainsKey($Model.ToLower())) {
    $modelMap[$Model.ToLower()]
} else {
    $Model  # Assume it's a full model ID
}

# Validate OutputPath is an absolute path
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    Write-Error "OutputPath must be an absolute path (e.g., C:\Images\output.png). Received: $OutputPath"
    exit 1
}

# Ensure the directory exists
$outputDir = [System.IO.Path]::GetDirectoryName($OutputPath)
if (-not (Test-Path $outputDir)) {
    Write-Host "Creating directory: $outputDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Check for API key
$apiKey = $env:OPENROUTER_API_KEY
if (-not $apiKey) {
    Write-Error "OPENROUTER_API_KEY environment variable is not set. Get one at: https://openrouter.ai/keys"
    exit 1
}

Write-Host "Generating image with $resolvedModel..." -ForegroundColor Cyan

$body = @{
    model = $resolvedModel
    messages = @(@{ role = "user"; content = "Generate an image: $Prompt" })
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/chat/completions" -Method Post `
        -Headers @{ "Authorization" = "Bearer $apiKey"; "Content-Type" = "application/json" } -Body $body

    $msg = $response.choices[0].message

    # Handle images array (OpenRouter format)
    if ($msg.images) {
        $img = @($msg.images)[0]
        if ($img.image_url) {
            $imgUrl = if ($img.image_url.url) { $img.image_url.url } else { $img.image_url }
            if ($imgUrl -match '^data:image/[^;]+;base64,(.+)$') {
                [IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($matches[1]))
            } else {
                Invoke-WebRequest -Uri $imgUrl -OutFile $OutputPath
            }
            Write-Host "Image saved to: $OutputPath ($([math]::Round((Get-Item $OutputPath).Length/1024))KB)" -ForegroundColor Green
            exit 0
        }
        if ($img.b64_json) {
            [IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($img.b64_json))
            Write-Host "Image saved to: $OutputPath ($([math]::Round((Get-Item $OutputPath).Length/1024))KB)" -ForegroundColor Green
            exit 0
        }
    }

    # Handle inline base64 in content
    if ($msg.content -match 'base64,([A-Za-z0-9+/=]+)') {
        [IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($matches[1]))
        Write-Host "Image saved to: $OutputPath" -ForegroundColor Green
        exit 0
    }

    Write-Error "No image data found in response"
    exit 1
}
catch {
    Write-Error "Failed to generate image: $_"
    exit 1
}
