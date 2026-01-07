param(
    [Parameter(Mandatory=$true)]
    [string]$TranscriptPath,
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    [Parameter(Mandatory=$true)]
    [string]$BaseFilename
)

# Ensure output directory exists
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$summaryPath = Join-Path $OutputDir "$BaseFilename-summary.md"

Write-Host "Reading transcript from $TranscriptPath..."
$transcript = Get-Content $TranscriptPath -Raw

Write-Host "Generating summary using Gemini (gemini-3-flash-preview)..."
$prompt = @"
Create a comprehensive and engaging summary of the following YouTube transcript.
The summary should include:
1. A catchy title.
2. A high-level executive summary.
3. Key takeaways or main points.
4. Detailed notes or chapters if applicable.
5. A conclusion or final thoughts.

Use Markdown formatting with emojis to make it visually appealing.

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

$summary | Out-File -FilePath $summaryPath -Encoding utf8
Write-Host "Summary saved to $summaryPath"

return $summaryPath
