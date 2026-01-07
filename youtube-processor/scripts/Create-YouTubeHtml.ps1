param(
    [Parameter(Mandatory=$true)]
    [string]$SummaryPath,

    [Parameter(Mandatory=$true)]
    [string]$MetadataPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputDir,

    [Parameter(Mandatory=$true)]
    [string]$BaseFilename
)

$InformationPreference = 'Continue'

$ErrorActionPreference = "Stop"

Write-Information "Generating HTML report for: $BaseFilename" -ForegroundColor Cyan

if (-not (Test-Path $SummaryPath)) {
    Write-Error "Summary file not found: $SummaryPath"
}

if (-not (Test-Path $MetadataPath)) {
    Write-Error "Metadata file not found: $MetadataPath"
}

$summaryContent = Get-Content -Path $SummaryPath -Raw
$metadataContent = Get-Content -Path $MetadataPath -Raw
$audioPath = Join-Path $OutputDir "$BaseFilename-summary.mp3"
$audioExists = Test-Path $audioPath
$audioFilename = if ($audioExists) { "$BaseFilename-summary.mp3" } else { $null }

# Define the HTML generation prompt
$prompt = @"
You are an expert web developer. Generate a single-file, styled HTML report for a YouTube video summary.

CONTEXT:
- Video Metadata: $metadataContent
- Markdown Summary: $summaryContent
- Audio Summary Filename: $audioFilename (Include audio player ONLY if this is not empty)

REQUIREMENTS:
1. Use a modern 'crypto-dark-blue' theme.
2. Use 'Work Sans' for primary text and 'Fira Code' for monospace.
3. Include a header with:
   - Video Title (linked to YouTube URL)
   - Channel Name (linked to Channel URL)
   - Engagement metrics (Likes, Comments, Duration, Upload Date) as badges.
4. If an audio summary exists, include a native HTML5 audio player with controls immediately after the header.
5. Convert the Markdown summary into semantic HTML sections:
   - Executive Summary
   - Main Topics (with clickable timestamps)
   - Key Takeaways
   - Technical Details
   - Resources
   - Tags
6. All timestamps (e.g., 12:34) must be converted to clickable YouTube links using the format: https://www.youtube.com/watch?v={VIDEO_ID}&t={SECONDS}s
7. Use the following CSS variables for the theme:
   --bg-primary: #0f1419;
   --bg-secondary: #1a1f2e;
   --bg-accent: #242d3d;
   --text-primary: #e8ecf1;
   --text-secondary: #a0aec0;
   --accent-cyan: #00d9ff;
   --accent-blue: #0ea5e9;
   --border-light: #2d3748;

8. The output MUST be a single, complete HTML document starting with <!DOCTYPE html>.
9. DO NOT include any markdown formatting or code blocks in your response. Return ONLY the raw HTML.
10. Ensure the layout is responsive and looks professional.

CRITICAL: Return ONLY the HTML content. No preamble, no postamble, no code blocks.
"@

Write-Information "Calling Gemini to generate HTML..." -ForegroundColor Yellow

try {
    $result = gemini -m gemini-3-flash-preview -p $prompt
    $wrapper = $result | ConvertFrom-Json
    $htmlContent = $wrapper.response

    # Clean up any potential markdown code block markers if Gemini ignored the instruction
    $htmlContent = $htmlContent -replace "^```html\s*", ""
    $htmlContent = $htmlContent -replace "^```\s*", ""
    $htmlContent = $htmlContent -replace "\s*```$", ""

    $outputPath = Join-Path $OutputDir "$BaseFilename.html"
    $htmlContent | Out-File -FilePath $outputPath -Encoding utf8

    Write-Information "Successfully generated HTML report: $outputPath" -ForegroundColor Green
}
catch {
    Write-Information "Error generating HTML: $_" -ForegroundColor Red
    exit 1
}
