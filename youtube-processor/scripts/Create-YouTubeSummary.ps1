param(
    [Parameter(Mandatory=$true)]
    [string]$TranscriptPath,
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    [Parameter(Mandatory=$true)]
    [string]$BaseFilename,
    [Parameter(Mandatory=$true)]
    [string]$MetadataPath
)

$InformationPreference = 'Continue'

# Ensure output directory exists
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$summaryPath = Join-Path $OutputDir "$BaseFilename-summary.md"

Write-Information "Reading metadata from $MetadataPath..."
$metadata = Get-Content $MetadataPath -Raw | ConvertFrom-Json
$videoTitle = $metadata.title

Write-Information "Reading transcript from $TranscriptPath..."
$transcript = Get-Content $TranscriptPath -Raw

Write-Information "Generating summary using Gemini (gemini-3-flash-preview)..."
$prompt = @"
Create a comprehensive and engaging summary of the following YouTube transcript.

Video Title: $videoTitle

The summary should include:
1. Use the video title above as the main heading (# Video Title).
2. A high-level executive summary.
3. Key takeaways or main points.
4. Detailed notes or chapters if applicable.
5. A conclusion or final thoughts.

Use clean Markdown formatting for readability.

Transcript:
$transcript
"@

$geminiOutput = $prompt | gemini -m gemini-3-flash-preview -o json

if ($null -eq $geminiOutput -or $geminiOutput -eq "") {
    Write-Error "Gemini failed to generate summary."
    exit 1
}

# Parse the wrapper JSON from Gemini CLI
$wrapperObj = $geminiOutput | ConvertFrom-Json
$summary = $wrapperObj.response

if ($null -eq $summary -or $summary -eq "") {
    Write-Error "Gemini response was empty."
    exit 1
}

# Use proper UTF-8 encoding to preserve special characters
[System.IO.File]::WriteAllText($summaryPath, $summary, [System.Text.UTF8Encoding]::new($false))
Write-Information "Summary saved to $summaryPath"

return $summaryPath
