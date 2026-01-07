param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
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

$videoPath = Join-Path $OutputDir "$BaseFilename.webm"
$audioPath = Join-Path $OutputDir "$BaseFilename.mp3"

Write-Information "Downloading video for $Url..."
# Download best video + best audio, merged into webm (or mp4 if preferred)
# Using --extractor-args to avoid 403 errors as seen in repo scripts
& ytd "$Url" --output "$videoPath" --extractor-args "youtube:player_js_version=actual"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to download video."
    exit 1
}

Write-Information "Extracting audio as MP3..."
& ytd "$Url" --extract-audio --audio-format mp3 --output "$audioPath" --keep-video --extractor-args "youtube:player_js_version=actual"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to extract audio."
    exit 1
}

Write-Information "Video saved to $videoPath"
Write-Information "Audio saved to $audioPath"

# Return the paths
return @{
    VideoPath = $videoPath
    AudioPath = $audioPath
}
