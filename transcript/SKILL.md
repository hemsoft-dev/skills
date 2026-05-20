---
name: transcript
description: "V1.0 - Transcribes MP3/audio files to text using local GPU-accelerated faster-whisper. Output .txt file is saved next to the source audio."
compatibility: Requires Python, faster-whisper, nvidia-cublas-cu12, NVIDIA GPU with CUDA
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the transcript directory (path contains 'transcript'), verify that history logging occurred.

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
            Before stopping, if transcript was used (check if any files in transcript directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in transcript directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Transcript

Transcribes audio files to timestamped text using faster-whisper on local GPU.

## Default Behavior

When user provides an audio file path, run the transcription script. Output `.txt` file is saved next to the source audio file.

## Usage

```powershell
& "C:\Users\User\.agents\skills\transcript\scripts\Transcribe-Audio.ps1" -AudioPath "{AUDIO_FILE_PATH}"
```

## Parameters

| Parameter | Required | Default | Description |
| :--- | :--- | :--- | :--- |
| `-AudioPath` | ✅ | — | Full path to the audio file (MP3, WAV, M4A, FLAC, OGG) |
| `-Model` | ❌ | `medium` | Whisper model size: `tiny`, `base`, `small`, `medium`, `large-v3` |
| `-Language` | ❌ | `en` | Language code for transcription |
| `-OutputPath` | ❌ | Same dir as audio | Custom output path for the transcript |

## Output

- WebVTT transcript saved as `.vtt` next to the source audio
- Standard subtitle format compatible with video players, YouTube, podcast apps
- Console output shows progress and elapsed time

## Prerequisites

```powershell
pip install faster-whisper nvidia-cublas-cu12
```

## Model Selection Guide

| Model | Speed (5090) | Quality | Use Case |
| :--- | :--- | :--- | :--- |
| `tiny` | ~30s/hr | Low | Quick draft, checking content |
| `base` | ~1min/hr | Fair | Casual transcription |
| `small` | ~2min/hr | Good | General use |
| `medium` | ~4min/hr | Great | Podcasts, interviews |
| `large-v3` | ~8min/hr | Best | Professional, multi-language |
