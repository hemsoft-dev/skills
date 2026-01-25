param(
    [Parameter(Mandatory=$true)]
    [string]$InputText,
    
    [string]$Voice = "en-US-EmmaMultilingualNeural",
    
    [string]$Rate = "+0%",
    
    [string]$Volume = "+0%",
    
    [string]$Pitch = "+0Hz"
)

$InformationPreference = 'Continue'

# Determine if input is a file path or text
# Check if input is a valid file path
$isFile = Test-Path $InputText -PathType Leaf

if ($isFile) {
    try {
        $filePath = (Resolve-Path $InputText -ErrorAction Stop).Path
    } catch {
        $filePath = $InputText
    }
    # Input is a file path - play directly with ffplay
    Write-Information "Playing audio file: $filePath"
    & ffplay -nodisp -autoexit "$filePath" 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to play audio file: $filePath"
        exit 1
    }
} else {
    # Input is text - convert to speech first, then play
    Write-Information "Converting text to speech and playing..."
    
    # Create temporary audio file
    $tempAudioFile = Join-Path $env:TEMP "play-audio-$(Get-Date -Format 'yyyyMMdd-HHmmss').mp3"
    
    try {
        # Generate speech using edge-tts
        & edge-tts --voice $Voice --rate $Rate --volume $Volume --pitch $Pitch --text "$InputText" --write-media "$tempAudioFile" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to generate speech from text"
            exit 1
        }
        
        if (-not (Test-Path $tempAudioFile)) {
            Write-Error "Audio file was not created"
            exit 1
        }
        
        # Play the generated audio
        Write-Information "Playing audio..."
        & ffplay -nodisp -autoexit "$tempAudioFile" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to play audio"
            exit 1
        }
    } finally {
        # Clean up temporary file
        if (Test-Path $tempAudioFile) {
            Remove-Item $tempAudioFile -ErrorAction SilentlyContinue
        }
    }
}

Write-Information "Audio playback complete."
