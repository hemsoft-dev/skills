---
name: play-audio
description: V2.0 - Plays audio files or converts text to speech using edge-tts (fast) or Qwen3-TTS VoiceDesign (high quality). Supports voice profiles for customizable TTS output.
dependencies: edge-tts>=7.2.7, ffmpeg (for ffplay), qwen-tts (for high quality mode), Python 3.12+, PyTorch with CUDA support
compatibility: Requires Windows PowerShell, ffplay (from ffmpeg), edge-tts for fast mode, and Qwen3-TTS VoiceDesign model for high quality mode.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the play-audio directory (path contains 'play-audio'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if play-audio was used (check if any files in play-audio directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in play-audio directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Play Audio

Plays audio files or converts text to speech with two quality modes:

- **Fast Mode (default)**: Uses edge-tts with Aria female voice (~2-3 seconds)
- **High Quality Mode (-hq)**: Uses Qwen3-TTS VoiceDesign with customizable voice profiles (~15-25 seconds)

## Global PowerShell Function

The `play` function is globally available in PowerShell via the profile.

### Usage

```powershell
# Fast mode (edge-tts)
play "Hello world"

# High quality with default British female
play -hq "Hello world"

# High quality with specific voice profile
play -hq -voice pro "Hi there!"

# Play audio file
play "C:\path\to\audio.mp3"
```

### Voice Profiles

Available voice profiles for `-hq` mode:

| Profile | Description |
|---------|-------------|
| `british` | Professional British female, clear and articulate, mid-30s (default) |
| `pro` | Professional American female narrator, mid-40s, news anchor quality |
| `brit-male` | Sophisticated British male, deep and resonant, 40s, documentary style |
| `casual` | Casual American male, 30s, friendly and conversational, podcast style |

### Examples

```powershell
# Fast mode with edge-tts (Aria female)
play "The quick brown fox"

# British female (default HQ)
play -hq "Good afternoon, how are you today?"

# Professional narrator
play -hq -voice pro "In today's news, we examine the latest developments"

# British male documentary
play -hq -voice brit-male "The natural world is full of wonders"

# Casual American male
play -hq -voice casual "What's up guys, let's talk about this"
```

## Voice Profile Configuration

Voice profiles are defined in `C:\Users\User\qwen3_voice_profiles.ps1` and loaded automatically by the PowerShell profile.

### Adding Custom Profiles

Edit `qwen3_voice_profiles.ps1`:

```powershell
# Add new voice description
$VOICE_CUSTOM = "Your custom voice description here"

# Add to profiles map
$global:VoiceProfiles = @{
    "british" = $VOICE_BRITISH_FEMALE
    "custom" = $VOICE_CUSTOM  # Add your custom profile
    # ... other profiles
}
```

Then use it:

```powershell
play -hq -voice custom "Testing my custom voice"
```

### Voice Description Tips

When creating custom voice descriptions, include:

- **Gender and age**: "Female, mid-30s" or "Male, 20s"
- **Accent**: "British", "American", "Australian"
- **Tone/Style**: "Professional", "casual", "energetic", "warm"
- **Reference style**: "News anchor", "podcast host", "narrator"

Examples:

- "Young Australian female, cheerful and upbeat, radio host style"
- "Mature American male, authoritative, documentary narrator, deep voice"
- "British female, sophisticated, aged 50s, BBC presenter quality"

## Technical Details

### Architecture

```
┌─────────────────────────────────────────┐
│ PowerShell `play` function              │
│ (D:\OneDrive\Documents\PowerShell\      │
│  profile.ps1)                           │
└──────────────┬──────────────────────────┘
               │
               ├─ Fast Mode ──────────────┐
               │                          │
               │  ┌───────────────────────▼──┐
               │  │ edge-tts                 │
               │  │ Voice: en-US-AriaNeural  │
               │  │ Output: temp MP3         │
               │  └───────────────────────┬──┘
               │                          │
               ├─ HQ Mode ────────────────┤
               │                          │
               │  ┌───────────────────────▼──────────┐
               │  │ qwen3_tts_voicedesign.py         │
               │  │ Model: Qwen3-TTS-12Hz-1.7B-      │
               │  │        VoiceDesign               │
               │  │ Voice: Custom description        │
               │  │ Output: ~/qwen3_output.wav       │
               │  └───────────────────────┬──────────┘
               │                          │
               └──────────────────────────┼──────────┐
                                          │          │
                                    ┌─────▼──────────▼─┐
                                    │ ffplay           │
                                    │ Plays audio      │
                                    └──────────────────┘
```

### Dependencies

#### Fast Mode (edge-tts)

- `ffplay` (from ffmpeg) - for audio playback
- `edge-tts` - for text-to-speech conversion
- Network access for TTS API

#### High Quality Mode (Qwen3-TTS)

- `ffplay` (from ffmpeg) - for audio playback
- Python 3.12+ with conda environment: `qwen3-tts`
- `qwen-tts` package
- PyTorch with CUDA 12.8+ (for RTX 5090)
- Model: `Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign`
- Scripts:
  - `C:\Users\User\qwen3_tts_voicedesign.py`
  - `C:\Users\User\qwen3_voice_profiles.ps1`

### File Locations

- **PowerShell Profile**: `D:\OneDrive\Documents\PowerShell\profile.ps1`
- **Voice Profiles**: `C:\Users\User\qwen3_voice_profiles.ps1`
- **Qwen3-TTS Script**: `C:\Users\User\qwen3_tts_voicedesign.py`
- **Output File (HQ)**: `C:\Users\User\qwen3_output.wav`
- **Conda Environment**: `C:\Users\User\miniconda3\envs\qwen3-tts`

## Performance

| Mode | Engine | Voice | Generation Time | Quality |
|------|--------|-------|----------------|---------|
| Fast | edge-tts | Aria (US Female) | ~2-3 sec | Good |
| HQ | Qwen3-TTS | Custom profiles | ~15-25 sec | Excellent |

## Notes

- Audio playback is silent (no GUI window) using `-nodisp` flag
- Playback auto-exits when finished using `-autoexit` flag  
- Temporary audio files are cleaned up automatically
- HQ mode requires first-time model download (~3.4GB)
- HQ mode runs locally on GPU (RTX 5090) - no API calls
- Voice profiles can be customized via `qwen3_voice_profiles.ps1`
- For edge-tts voices: `edge-tts --list-voices`

## Troubleshooting

### HQ Mode Falls Back to edge-tts

Check:

1. Qwen3-TTS environment exists: `conda env list | grep qwen3-tts`
2. Python executable exists: `Test-Path C:\Users\User\miniconda3\envs\qwen3-tts\python.exe`
3. Script exists: `Test-Path C:\Users\User\qwen3_tts_voicedesign.py`
4. Model downloaded: Check `~\.cache\huggingface\hub\models--Qwen--Qwen3-TTS-12Hz-1.7B-VoiceDesign`

### Voice Profile Not Found

```powershell
# List available profiles
. C:\Users\User\qwen3_voice_profiles.ps1
$global:VoiceProfiles.Keys
```

### Slow HQ Mode

First generation is slower (~25 sec) due to model loading. Subsequent generations in the same session are faster (~15 sec).
