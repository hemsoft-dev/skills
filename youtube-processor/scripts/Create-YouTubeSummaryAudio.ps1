param(
    [Parameter(Mandatory=$true)]
    [string]$SummaryPath,
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    [Parameter(Mandatory=$true)]
    [string]$BaseFilename
)

$InformationPreference = 'Continue'

# Ensure output directory exists
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$audioPath = Join-Path $OutputDir "$BaseFilename-summary.mp3"

Write-Information "Reading summary from $SummaryPath..."
$markdownContent = Get-Content $SummaryPath -Raw

# Extract Executive Summary section
$executiveSummary = ""
if ($markdownContent -match '## Executive Summary\s+([\s\S]+?)(?=\r?\n##|\r?\n---|\z)') {
    $executiveSummary = $matches[1].Trim()
} else {
    # Fallback: use the first 1000 characters if section not found
    $executiveSummary = $markdownContent.Substring(0, [Math]::Min(1000, $markdownContent.Length))
}

# Clean text for TTS
$cleanText = $executiveSummary
$cleanText = $cleanText -replace '\*\*([^*]+)\*\*', '$1'
$cleanText = $cleanText -replace '\*([^*]+)\*', '$1'
$cleanText = $cleanText -replace '`([^`]+)`', '$1'
$cleanText = $cleanText -replace '\[([^\]]+)\]\([^\)]+\)', '$1'
$cleanText = $cleanText -replace '(?m)^\s*[-*+]\s+', ''
$cleanText = $cleanText -replace '\r?\n', ' '
$cleanText = $cleanText -replace '\s+', ' '
$cleanText = $cleanText.Trim()

if ([string]::IsNullOrWhiteSpace($cleanText)) {
    Write-Error "Executive Summary is empty."
    exit 1
}

Write-Information "Generating audio with edge-tts..."
$voice = "en-US-AvaNeural" # Good default voice
$tempTextFile = Join-Path $env:TEMP "$BaseFilename-summary.txt"
$cleanText | Out-File -FilePath $tempTextFile -Encoding UTF8 -NoNewline

& edge-tts --voice $voice --rate=+10% --file "$tempTextFile" --write-media "$audioPath"

# Clean up temp file
Remove-Item $tempTextFile -ErrorAction SilentlyContinue

if (Test-Path $audioPath) {
    Write-Information "✓ Audio summary saved: $audioPath"
    return $audioPath
} else {
    Write-Error "Audio file was not created."
    exit 1
}
