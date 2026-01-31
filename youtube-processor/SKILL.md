---
name: youtube-processor
description: V1.5 - Processes a YouTube URL by extracting metadata, downloading video, generating transcript, summary, and audio summary.
---

# YouTube Processor

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

A comprehensive skill for processing YouTube videos into high-quality summaries and reports. This skill uses **Gemini 3 Flash Preview** for AI tasks and **PowerShell** for orchestration.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Core Commands

### Process-YouTubeUrl

The primary command to run the entire pipeline for a single URL.

```powershell
# 1. Extract Metadata
$metadata = & "c:\Users\User\.claude\skills\youtube-processor\scripts\Get-YouTubeMetadata.ps1" -Url "{URL}" -OutputDir "{OUTPUT_DIR}"

# 2. Download Video & Audio
& "c:\Users\User\.claude\skills\youtube-processor\scripts\Download-YouTubeVideo.ps1" -Url "{URL}" -OutputDir "{OUTPUT_DIR}" -BaseFilename $metadata.base_filename

# 3. Get Transcript (YouTube or Whisper fallback)
& "c:\Users\User\.claude\skills\youtube-processor\scripts\Get-YouTubeTranscript.ps1" -Url "{URL}" -OutputDir "{OUTPUT_DIR}" -BaseFilename $metadata.base_filename -VideoPath "{OUTPUT_DIR}/$($metadata.base_filename).webm"

# 4. Create Markdown Summary
& "c:\Users\User\.claude\skills\youtube-processor\scripts\Create-YouTubeSummary.ps1" -TranscriptPath "{OUTPUT_DIR}/$($metadata.base_filename).en.vtt" -OutputDir "{OUTPUT_DIR}" -BaseFilename $metadata.base_filename -MetadataPath "{OUTPUT_DIR}/$($metadata.base_filename)-metadata.json"

# 5. Create Audio Summary (edge-tts)
& "c:\Users\User\.claude\skills\youtube-processor\scripts\Create-YouTubeSummaryAudio.ps1" -SummaryPath "{OUTPUT_DIR}/$($metadata.base_filename)-summary.md" -OutputDir "{OUTPUT_DIR}" -BaseFilename $metadata.base_filename
```

## Individual Step Scripts

All scripts are located in `c:\Users\User\.claude\skills\youtube-processor\scripts\`.

| Script | Purpose |
| :--- | :--- |
| `Get-YouTubeMetadata.ps1` | Extracts raw metadata via `ytd` and transforms it via Gemini into a structured JSON. |
| `Download-YouTubeVideo.ps1` | Downloads the video (.webm) and extracts high-quality audio (.mp3). |
| `Get-YouTubeTranscript.ps1` | Fetches YouTube subtitles or runs local Whisper AI if unavailable. |
| `Create-YouTubeSummary.ps1` | Generates a structured Markdown summary using Gemini 3 Flash Preview. |
| `Create-YouTubeSummaryAudio.ps1` | Converts the "Executive Summary" section to speech using `edge-tts`. |

## Requirements

- **Gemini CLI**: Must be installed and configured. Uses model `gemini-3-flash-preview`.
- **yt-dlp (`ytd`)**: Must be in PATH.
- **ffmpeg**: Required for audio extraction and Whisper.
- **edge-tts**: Required for audio summary generation.
- **Whisper AI**: Required for fallback transcription (expects `whisper-env` in the workspace).

## Workflow Details

1. **Metadata**: The script ensures a consistent `base_filename` (format: `YYYY-MM-DD - title`) used by all subsequent steps.
2. **Transcription**: Prefers official YouTube subtitles. Falls back to local Whisper transcription if needed.
3. **Summarization**: Uses a detailed prompt to ensure high-quality, technical summaries with timestamps.
4. **Audio**: Uses the `en-US-AndrewNeural` voice by default for a professional sound.
