---
name: edge-tts
description: V1.1 - Expert in edge-tts CLI tool and Python module for Microsoft Edge's text-to-speech service. Use for generating speech audio files, subtitles, voice selection, rate/volume/pitch adjustments, and Python integration.
dependencies: edge-tts>=7.2.7
compatibility: Requires Python 3.7+ and network access. Windows, macOS, Linux supported.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the edge-tts directory (path contains 'edge-tts'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if edge-tts was used (check if any files in edge-tts directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in edge-tts directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}"
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Edge-TTS

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert in Microsoft Edge's text-to-speech service via the `edge-tts` CLI tool and Python module. Provides high-quality neural TTS without requiring Microsoft Edge, Windows, or API keys.

## Installation

```bash
# Install via pip
pip install edge-tts

# Or via pipx for CLI-only use
pipx install edge-tts
```

## CLI Commands

### Basic Usage

**Generate audio file:**

```bash
edge-tts --text "Hello, world!" --write-media output.mp3
```

**Generate audio with subtitles:**

```bash
edge-tts --text "Hello, world!" --write-media output.mp3 --write-subtitles output.srt
```

**Read from file:**

```bash
edge-tts --file input.txt --write-media output.mp3 --write-subtitles output.srt
```

**Playback with subtitles (requires mpv on non-Windows):**

```bash
edge-playback --text "Hello, world!"
edge-playback --file input.txt
```

### Voice Selection

**List all available voices:**

```bash
edge-tts --list-voices
```

**Use specific voice:**

```bash
edge-tts --voice en-US-EmmaMultilingualNeural --text "Hello" --write-media output.mp3
edge-tts --voice ar-EG-SalmaNeural --text "مرحبا" --write-media output.mp3
```

**Default voice:** `en-US-EmmaMultilingualNeural`

### Speech Parameters

**Rate adjustment (percentage):**

```bash
edge-tts --rate=-50% --text "Slow speech" --write-media output.mp3
edge-tts --rate=+50% --text "Fast speech" --write-media output.mp3
```

**Volume adjustment (percentage):**

```bash
edge-tts --volume=-50% --text "Quiet speech" --write-media output.mp3
edge-tts --volume=+50% --text "Loud speech" --write-media output.mp3
```

**Pitch adjustment (Hz):**

```bash
edge-tts --pitch=-50Hz --text "Lower pitch" --write-media output.mp3
edge-tts --pitch=+50Hz --text "Higher pitch" --write-media output.mp3
```

**Note:** For negative values, use `--option=-50%` format (equals sign required) to avoid parsing as separate option.

**Combined parameters:**

```bash
edge-tts --voice en-US-AriaNeural --rate=-25% --volume=+10% --pitch=-20Hz --text "Custom speech" --write-media output.mp3
```

### Advanced Options

**Proxy support:**

```bash
edge-tts --proxy http://proxy.example.com:8080 --text "Hello" --write-media output.mp3
```

**Version check:**

```bash
edge-tts --version
```

## Python Module Usage

### Basic Generation

```python
import asyncio
import edge_tts

async def main():
    communicate = edge_tts.Communicate("Hello World!", "en-GB-SoniaNeural")
    await communicate.save("output.mp3")

asyncio.run(main())
```

### With Subtitles

```python
import asyncio
import edge_tts

async def main():
    communicate = edge_tts.Communicate("Hello World!", "en-GB-SoniaNeural")
    await communicate.save("output.mp3")
    
    # Generate subtitles
    with open("output.srt", "w", encoding="utf-8") as f:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                # Audio data
                pass
            elif chunk["type"] == "WordBoundary":
                # Subtitle timing data
                f.write(f"{chunk['offset']} --> {chunk['duration']}\n{chunk['text']}\n\n")

asyncio.run(main())
```

### List Voices

```python
import asyncio
import edge_tts

async def main():
    voices = await edge_tts.list_voices()
    for voice in voices:
        if voice["Locale"].startswith("en-US"):
            print(f"{voice['ShortName']}: {voice['Gender']} - {voice['VoicePersonalities']}")

asyncio.run(main())
```

### Streaming Audio

```python
import asyncio
import edge_tts

async def main():
    communicate = edge_tts.Communicate("Long text here...", "en-US-EmmaNeural")
    with open("output.mp3", "wb") as f:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                f.write(chunk["data"])

asyncio.run(main())
```

### Custom Rate/Volume/Pitch

```python
import asyncio
import edge_tts

async def main():
    communicate = edge_tts.Communicate(
        text="Hello World!",
        voice="en-US-EmmaNeural",
        rate="-50%",
        volume="+10%",
        pitch="-20Hz"
    )
    await communicate.save("output.mp3")

asyncio.run(main())
```

## Voice Categories

Voices are categorized by:

- **Locale**: Language and region (e.g., `en-US`, `ar-EG`)
- **Gender**: Male or Female
- **ContentCategories**: General, News, Novel, Conversation, Copilot, Cartoon
- **VoicePersonalities**: Descriptive traits (Friendly, Positive, Confident, etc.)

**Multilingual voices** support multiple languages:

- `en-US-EmmaMultilingualNeural`
- `en-US-AndrewMultilingualNeural`
- `de-DE-FlorianMultilingualNeural`
- `fr-FR-RemyMultilingualNeural`

## Common Use Cases

1. **Audiobook generation** - Convert text files to audio with subtitles
2. **Accessibility** - Generate speech for screen readers or assistive tech
3. **Content creation** - Create voiceovers for videos/podcasts
4. **Language learning** - Generate native pronunciation examples
5. **Multilingual content** - Use locale-specific voices for international content
6. **Voice customization** - Adjust rate/volume/pitch for specific needs

## Best Practices

1. **Voice selection**: Use `--list-voices` to find voices matching your content category (News, Conversation, etc.)
2. **File input**: Use `--file` for long texts instead of `--text` to avoid command-line length limits
3. **Subtitle format**: Generated subtitles are in SRT format with word-level timestamps
4. **Rate limits**: Be mindful of Microsoft's service limits; avoid excessive requests
5. **Error handling**: Network errors may occur; implement retry logic for production use
6. **Audio format**: Output is MP3 format by default
7. **Encoding**: Ensure text files are UTF-8 encoded for proper handling of non-ASCII characters

## Troubleshooting

**No audio output:**

- Check network connection (requires internet)
- Verify voice name with `--list-voices`
- Ensure output path is writable

**Playback issues:**

- Windows: Uses default media player
- Non-Windows: Requires `mpv` installation (`brew install mpv` or `apt install mpv`)

**Subtitle generation:**

- Subtitles are written to stderr by default unless `--write-subtitles` is specified
- Format is SRT with precise word-level timing

**Proxy issues:**

- Use `--proxy` option if behind corporate firewall
- Format: `http://host:port` or `https://host:port`
