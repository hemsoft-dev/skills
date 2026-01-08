<#
.SYNOPSIS
    Generates an image using Seedream 4.5 via OpenRouter API.

.DESCRIPTION
    Seedream 4.5 (bytedance-seed/seedream-4.5) is a fast, cost-effective image generator.
    Cost: ~$0.04/image
    Response format: images[].image_url containing base64 data URL

.PARAMETER Prompt
    The text prompt describing the image to generate.

.PARAMETER OutputPath
    The full absolute path where the image will be saved.

.PARAMETER Preview
    Opens the generated image in Directory Opus viewer after saving.

.EXAMPLE
    .\generate-seedream.ps1 -Prompt "A futuristic cityscape at night" -OutputPath "D:\city.png"

.EXAMPLE
    .\generate-seedream.ps1 -Prompt "A futuristic cityscape at night" -OutputPath "D:\city.png" -Preview
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
$Model = "bytedance-seed/seedream-4.5"

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

Write-Information "[36mGenerating with Seedream 4.5...`e[0m"

$body = @{
    model = $Model
    messages = @(@{ role = "user"; content = "Generate an image: $Prompt" })
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/chat/completions" `
    -Method Post `
    -Headers @{ "Authorization" = "Bearer $apiKey"; "Content-Type" = "application/json" } `
    -Body $body

# Seedream returns: choices[0].message.images[0].image_url = "data:image/png;base64,..."
$msg = $response.choices[0].message

if (-not $msg.images -or $msg.images.Count -eq 0) {
    throw "No images in response. Response: $($response | ConvertTo-Json -Depth 5)"
}

$imgData = $msg.images[0]
$imgUrl = if ($imgData.image_url.url) { $imgData.image_url.url } else { $imgData.image_url }

if ($imgUrl -match '^data:image/[^;]+;base64,(.+)$') {
    [IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($matches[1]))
    $size = [math]::Round((Get-Item $OutputPath).Length / 1024)
    Write-Information "[32m✓ Saved: $OutputPath (${size}KB)`e[0m"
    
    # Open in Directory Opus viewer if requested
    if ($Preview) {
        $dopusViewer = "C:\Program Files\GPSoftware\Directory Opus\d8viewer.exe"
        if (Test-Path $dopusViewer) {
            Write-Information "[36mOpening preview in Directory Opus...`e[0m"
            Start-Process $dopusViewer -ArgumentList "`"$OutputPath`""
        } else {
            Write-Information "[33mDirectory Opus viewer not found at: $dopusViewer`e[0m"
            Write-Information "[33mOpening with default viewer...`e[0m"
            Start-Process $OutputPath
        }
    }
} else {
    throw "Unexpected image_url format: $($imgUrl.Substring(0, [Math]::Min(100, $imgUrl.Length)))..."
}
