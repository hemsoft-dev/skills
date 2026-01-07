# speak-clipboard.ps1 - Speak clipboard contents using edge-tts
param(
    [string]$Voice = "en-US-AndrewNeural"
)

$edgePlayback = "$env:USERPROFILE\AppData\Local\Programs\Python\Python312\Scripts\edge-playback.exe"

# Get clipboard text
$text = Get-Clipboard -Format Text
if (-not $text) {
    exit 1
}

# Play speech directly (edge-playback uses mpv or similar)
& $edgePlayback --voice $Voice --text $text 2>$null
