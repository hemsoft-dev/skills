param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
    [Parameter(Mandatory=$true)]
    [string]$OutputDir
)

$InformationPreference = 'Continue'

# Ensure output directory exists
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Information "Extracting raw metadata for $Url..."
$rawMetadataJson = ytd --dump-json --no-download --no-warnings --quiet "$Url"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to extract metadata using ytd."
    exit 1
}

# Filter metadata to reduce token usage and avoid Gemini API limits
$rawObj = $rawMetadataJson | ConvertFrom-Json
$filteredObj = @{
    id = $rawObj.id
    title = $rawObj.title
    description = $rawObj.description
    upload_date = $rawObj.upload_date
    uploader = $rawObj.uploader
    duration = $rawObj.duration
    view_count = $rawObj.view_count
    like_count = $rawObj.like_count
    channel = $rawObj.channel
    webpage_url = $rawObj.webpage_url
    chapters = $rawObj.chapters
    tags = $rawObj.tags
    categories = $rawObj.categories
    automatic_captions = $rawObj.automatic_captions
    subtitles = $rawObj.subtitles
}
$filteredMetadata = $filteredObj | ConvertTo-Json -Depth 10

# Get current date for date_downloaded
$currentDate = Get-Date -Format "yyyy-MM-dd"

# Prepare prompt for Gemini
$schemaPath = Join-Path $PSScriptRoot "..\youtube-metadata.schema.json"
$schemaContent = Get-Content $schemaPath -Raw

$prompt = @"
Transform the following filtered YouTube metadata into a JSON object that strictly follows the provided JSON schema.

Rules:
1. title_short: Create a URL-friendly version of the title (lowercase, hyphens only, max 60 chars).
2. upload_date: Ensure it is in YYYY-MM-DD format.
3. publishDate: Same as upload_date.
4. base_filename: Format as "YYYY-MM-DD - title_short".
5. date_downloaded: Use "$currentDate".
6. duration_formatted: Convert duration (seconds) to MM:SS or HH:MM:SS.
7. has_transcript: Set to true if 'automatic_captions' or 'subtitles' are present in the filtered data.
8. Output ONLY the valid JSON object. No markdown blocks, no preamble.

Schema:
$schemaContent

Filtered Metadata:
$filteredMetadata
"@

Write-Information "Transforming metadata using Gemini (gemini-3-flash-preview)..."
# Use Gemini CLI to transform
$geminiOutput = $prompt | gemini -m gemini-3-flash-preview -o json

if ($null -eq $geminiOutput -or $geminiOutput -eq "") {
    Write-Error "Gemini failed to transform metadata."
    exit 1
}

# Parse the wrapper JSON from Gemini CLI
$wrapperObj = $geminiOutput | ConvertFrom-Json
$transformedMetadata = $wrapperObj.response

if ($null -eq $transformedMetadata -or $transformedMetadata -eq "") {
    Write-Error "Gemini response was empty."
    exit 1
}

# Parse the actual metadata to get base_filename for the output path
$metadataObj = $transformedMetadata | ConvertFrom-Json
$baseFilename = $metadataObj.base_filename
$outputPath = Join-Path $OutputDir "$baseFilename-metadata.json"

$transformedMetadata | Out-File -FilePath $outputPath -Encoding utf8
Write-Information "Metadata saved to $outputPath"

# Output the path for the next step
return $outputPath
