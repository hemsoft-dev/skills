<#
.SYNOPSIS
    Extracts text from images using OpenRouter vision models.

.DESCRIPTION
    Uses OpenRouter's vision-capable models to extract visible text from images.
    Supports PNG, JPG, JPEG, GIF, and WEBP formats.

.PARAMETER ImagePath
    The absolute path to the image file to extract text from.

.PARAMETER Prompt
    Custom extraction prompt. Default: "Extract all visible text. Output plain text. Preserve line breaks."

.PARAMETER OutputPath
    Optional path to save the extracted text to a file.

.PARAMETER Model
    OpenRouter model ID to use. Default: "openrouter/auto"

.EXAMPLE
    .\read-text.ps1 -ImagePath "D:\screenshot.png"

.EXAMPLE
    .\read-text.ps1 -ImagePath "D:\receipt.jpg" -Prompt "Extract the total amount and date"

.EXAMPLE
    .\read-text.ps1 -ImagePath "D:\document.png" -OutputPath "D:\extracted.txt"
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ImagePath,

    [Parameter(Mandatory = $false)]
    [string]$Prompt = "Extract all visible text. Output plain text. Preserve line breaks.",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$Model = "google/gemini-2.0-flash-001"
)

$InformationPreference = 'Continue'
$ErrorActionPreference = "Stop"

# Validate ImagePath
if (-not [System.IO.Path]::IsPathRooted($ImagePath)) {
    throw "ImagePath must be absolute: $ImagePath"
}

if (-not (Test-Path $ImagePath)) {
    throw "Image file not found: $ImagePath"
}

# Determine MIME type from extension
$ext = [System.IO.Path]::GetExtension($ImagePath).ToLower()
$mimeType = switch ($ext) {
    ".png"  { "image/png" }
    ".jpg"  { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".gif"  { "image/gif" }
    ".webp" { "image/webp" }
    default { throw "Unsupported image format: $ext. Supported: PNG, JPG, JPEG, GIF, WEBP" }
}

# Get API key
$apiKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
if (-not $apiKey) { $apiKey = $env:OPENROUTER_API_KEY }
if (-not $apiKey) { throw "OPENROUTER_API_KEY not set. Get one at https://openrouter.ai/keys" }

Write-Information "`e[36mReading text from image...`e[0m"
Write-Information "`e[90mModel: $Model`e[0m"
Write-Information "`e[90mImage: $ImagePath`e[0m"

# Read and encode image
$bytes = [System.IO.File]::ReadAllBytes($ImagePath)
$b64 = [System.Convert]::ToBase64String($bytes)
$dataUrl = "data:$mimeType;base64,$b64"

# Build request body
$body = @{
    model = $Model
    messages = @(
        @{
            role = "user"
            content = @(
                @{ type = "text"; text = $Prompt },
                @{ type = "image_url"; image_url = @{ url = $dataUrl } }
            )
        }
    )
} | ConvertTo-Json -Depth 10

# Make API request
try {
    $response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/chat/completions" `
        -Method Post `
        -Headers @{ 
            "Authorization" = "Bearer $apiKey"
            "Content-Type" = "application/json"
        } `
        -Body $body
} catch {
    $errorBody = $_.ErrorDetails.Message
    throw "API request failed: $errorBody"
}

# Extract text from response
$extractedText = $response.choices[0].message.content

if (-not $extractedText) {
    throw "No text extracted from response. Response: $($response | ConvertTo-Json -Depth 5)"
}

# Output results
if ($OutputPath) {
    # Ensure directory exists
    $dir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    
    [System.IO.File]::WriteAllText($OutputPath, $extractedText)
    Write-Information "`e[32m✓ Saved extracted text to: $OutputPath`e[0m"
} else {
    Write-Information "`e[32m✓ Extracted text:`e[0m"
    Write-Information ""
}

# Return the extracted text
$extractedText
