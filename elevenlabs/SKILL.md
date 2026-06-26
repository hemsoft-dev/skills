---
name: elevenlabs
description: "V1.2 - Commands: tts, podcast. Expert in ElevenLabs API for text-to-speech generation, voice management, and audio processing. Use when generating speech, producing two-host podcasts, listing voices, or working with ElevenLabs features."
dependencies: PowerShell 5.1+
compatibility: Requires ELEVENLABS_API_KEY environment variable, network access, and ffplay (from ffmpeg) for playback.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the elevenlabs directory (path contains 'elevenlabs'), verify that history logging occurred.
            
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
            Before stopping, if elevenlabs was used (check if any files in elevenlabs directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in elevenlabs directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# ElevenLabs

Expert in ElevenLabs API for text-to-speech, voice cloning, voice management, and audio processing.

## Authentication

All scripts use the `ELEVENLABS_API_KEY` environment variable. Ensure it is set before use.

## Default Behavior

When user activates this skill without specifying a command, assume `tts` command.

## Commands

### tts - Text-to-Speech

Generate speech audio from text using ElevenLabs voices.

**Script**: `scripts/Invoke-ElevenLabsTts.ps1`

**Workflow:**

1. User provides text (required)
2. If `-OutputFile` is NOT specified: **ask the user** where to save the audio file. Do not default to a temp location.
3. If `-Voice` is NOT specified: use the preferred voice (`Hope`)
4. Run the script with resolved parameters

**Usage:**

```powershell
# TTS with preferred voice (Hope) — output path required
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "Hello, world!" -OutputFile "C:\audio\hello.mp3"

# Specify a voice by name
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "Hello, world!" -Voice "Adam" -OutputFile "C:\audio\hello.mp3"

# Play audio after generation
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "Hello, world!" -OutputFile "C:\audio\hello.mp3" -Play

# Adjust voice settings
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "Hello, world!" -OutputFile "C:\audio\hello.mp3" -Stability 0.5 -SimilarityBoost 0.8 -Style 0.3
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Text` | Yes | - | Text to convert to speech |
| `-OutputFile` | Yes | - | Output file path (agent must ask user if not provided) |
| `-Voice` | No | `Hope` | Preferred voice name or voice ID |
| `-Model` | No | `eleven_v3` | TTS model ID |
| `-Play` | No | `$false` | Play audio after generation |
| `-Stability` | No | `0.5` | Voice stability (0.0-1.0) |
| `-SimilarityBoost` | No | `0.75` | Voice similarity boost (0.0-1.0) |
| `-Style` | No | `0.0` | Style exaggeration (0.0-1.0) |

### podcast - Two-Host Podcast Generation

Generate a two-host conversational podcast from user-provided sources, then synthesize it with alternating ElevenLabs voices.

**Scripts**:

- `scripts/New-ElevenLabsPodcastDialogue.ps1` (builds source-driven dialogue)
- `scripts/Invoke-ElevenLabsPodcast.ps1` (synthesizes dialogue to audio)

**Default Voices** (researched and selected for contrast and clarity):

- Host 1: `Sarah` (confident, warm explainer tone)
- Host 2: `Adam` (deep, steady analyst tone)

These defaults create a clear conversational contrast similar to two-host explainer formats.

**Source requirement (mandatory):**

The user must provide at least one source. If no source is provided, stop and ask for sources. Encourage multiple sources because breadth improves podcast quality.

Accepted source types:

- URLs
- File paths (PDF, Markdown, text, docs)
- Raw pasted notes

**Workflow:**

1. Ask for sources (required, one or more)
2. Ask for podcast length: `short`, `medium`, or `long`
3. Ask for style direction:
   - `casual/conversational` (default)
   - `formal`
   - `news-reporting`
4. Ask for audience depth (default: digestible, non-deep-technical)
5. Ask for any focus hints (must-cover points, callouts, sections)
6. Ask for output path (required)
7. Generate a two-host script from the sources

- Preferred helper: `New-ElevenLabsPodcastDialogue.ps1`

1. Review transcript for quality (required before synthesis)
2. Synthesize with `Invoke-ElevenLabsPodcast.ps1`

**Default behavior for script generation:**

- Gravitate toward conversational back-and-forth between two hosts (NotebookLM-style)
- Prioritize clarity and digestibility over deep technical depth
- Keep examples practical and concrete
- Use v3-friendly expressive cues sparingly (audio tags + punctuation)

**Dialogue authoring constraints:**

- Alternate hosts naturally (avoid long monologues)
- Keep turns short-to-medium and easy to follow
- Include occasional recap lines and transitions
- Avoid inventing facts not grounded in provided sources
- Do not overuse audio tags; one subtle tag every few turns is usually enough
- Never read raw URLs, route paths, or website navigation labels out loud
- Synthesize purpose and meaning from source material; do not enumerate menus or page chrome

**Cost-control guidance:**

- Default to transcript-first generation and review (`.txt`) before running audio synthesis
- If transcript quality is poor, fix prompts/source extraction first; do not repeatedly regenerate audio

**Length guidance:**

| Length | Target turns | Typical duration |
|--------|-------------|------------------|
| `short` | 12-18 turns | 3-6 minutes |
| `medium` | 22-32 turns | 8-14 minutes |
| `long` | 36-52 turns | 16-28 minutes |

**Required dialogue format (input to script):**

```text
Host 1: [curious] Welcome back - today we are unpacking...
Host 2: [thoughtful] Right, and the first source highlights...
Host 1: So the practical takeaway is...
```

Speaker labels can match custom host names passed to script parameters.

**Usage:**

```powershell
# Basic podcast synthesis from prepared dialogue text
.\scripts\Invoke-ElevenLabsPodcast.ps1 `
  -DialogueText (Get-Content .\podcast-dialogue.txt -Raw) `
  -OutputFile "C:\audio\episode-01.mp3"

# Auto-build dialogue from sources, then generate audio
.\scripts\New-ElevenLabsPodcastDialogue.ps1 `
  -Source "https://example.com/article", ".\notes.md" `
  -Length medium -StylePreset casual `
  -FocusHint "focus on practical takeaways" `
  -OutputDialogueFile "C:\audio\episode-01-dialogue.txt" `
  -GenerateAudio -OutputAudioFile "C:\audio\episode-01.mp3"

# Custom host voices and names
.\scripts\Invoke-ElevenLabsPodcast.ps1 `
  -DialogueText (Get-Content .\podcast-dialogue.txt -Raw) `
  -Host1Name "Maya" -Host1Voice "Sarah" `
  -Host2Name "Noah" -Host2Voice "Adam" `
  -OutputFile "C:\audio\episode-01.mp3" -Play

# News-style with stronger delivery
.\scripts\Invoke-ElevenLabsPodcast.ps1 `
  -DialogueText (Get-Content .\podcast-dialogue.txt -Raw) `
  -OutputFile "C:\audio\daily-brief.mp3" `
  -Style 0.45 -Stability 0.35
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-DialogueText` | Yes | - | Two-host dialogue text using `Speaker: line` format |
| `-OutputFile` | Yes | - | Output podcast file path |
| `-Host1Name` | No | `Host 1` | Speaker label for host 1 lines |
| `-Host2Name` | No | `Host 2` | Speaker label for host 2 lines |
| `-Host1Voice` | No | `Sarah` | Voice name or ID for host 1 |
| `-Host2Voice` | No | `Adam` | Voice name or ID for host 2 |
| `-Model` | No | `eleven_v3` | TTS model ID |
| `-Play` | No | `$false` | Play audio after generation |
| `-Stability` | No | `0.35` | Voice stability (0.0-1.0) |
| `-SimilarityBoost` | No | `0.80` | Voice similarity boost (0.0-1.0) |
| `-Style` | No | `0.35` | Style exaggeration (0.0-1.0) |

**Dialogue helper parameters (`New-ElevenLabsPodcastDialogue.ps1`):**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Source` | Yes | - | One or more URL/file/raw-text sources |
| `-OutputDialogueFile` | Yes | - | Where to save generated dialogue text |
| `-Length` | No | `medium` | `short`, `medium`, or `long` |
| `-StylePreset` | No | `casual` | `casual`, `formal`, or `news-reporting` |
| `-FocusHint` | No | - | Extra guidance on what to emphasize |
| `-Host1Name` | No | `Host 1` | Speaker label for host 1 |
| `-Host2Name` | No | `Host 2` | Speaker label for host 2 |
| `-GenerateAudio` | No | `$false` | If set, also synthesize audio |
| `-OutputAudioFile` | No* | - | Required when `-GenerateAudio` is set |

### Long-Form Audio (Automatic Chunking)

The script automatically handles long text (>500 chars) using production-quality chunked generation:

1. **Splits** text into ~1000-char chunks at paragraph boundaries
2. **Generates** each chunk as a separate API call
3. **Stitches** chunks using `previous_request_ids` for prosody continuity (non-V3 models)
4. **Concatenates** audio segments with ffmpeg

> **V3 Limitation**: `eleven_v3` does **not** support `previous_text`, `next_text`, or `previous_request_ids` yet. Chunks are generated independently and concatenated. Quality relies on natural paragraph boundaries for clean breaks.

| Model | Char Limit | Stitching Support |
|-------|-----------|-------------------|
| `eleven_v3` | 5,000 | None (chunks are independent) |
| `eleven_multilingual_v2` | 10,000 | `previous_text`, `next_text`, `previous_request_ids` |
| `eleven_flash_v2_5` | 40,000 | `previous_text`, `next_text`, `previous_request_ids` |

**Best practices for long-form text:**

- Write text with clear paragraph breaks (double newlines) — each becomes a chunk boundary
- End paragraphs at natural sentence endpoints, not mid-thought
- Keep individual paragraphs under ~1000 chars for V3
- For the highest quality long-form narration, consider `eleven_multilingual_v2` which has full stitching support

### Available Models

| Model ID | Name | Languages | TTS |
|----------|------|-----------|-----|
| `eleven_v3` | Eleven v3 | 74 | Yes |
| `eleven_multilingual_v2` | Eleven Multilingual v2 | 29 | Yes |
| `eleven_flash_v2_5` | Eleven Flash v2.5 | 32 | Yes |
| `eleven_turbo_v2_5` | Eleven Turbo v2.5 | 32 | Yes |
| `eleven_turbo_v2` | Eleven Turbo v2 | 1 | Yes |
| `eleven_flash_v2` | Eleven Flash v2 | 1 | Yes |
| `eleven_monolingual_v1` | Eleven English v1 | 1 | Yes |
| `eleven_multilingual_sts_v2` | Eleven Multilingual v2 (STS) | 29 | No |
| `eleven_english_sts_v2` | Eleven English v2 (STS) | 1 | No |
| `eleven_multilingual_v1` | Eleven Multilingual v1 | 9 | Yes |

> **Recommended**: Use `eleven_v3` (default) for best quality and widest language support. Use `eleven_flash_v2_5` for low-latency applications.

### Popular Default Voices

#### V3 Recommended Voices

| Voice | Description |
|-------|-------------|
| `Hope` | Recommended for V3 model |

#### Classic Voices

| Voice | Description |
|-------|-------------|
| `Rachel` | Calm, young American female |
| `Adam` | Deep, middle-aged American male, dominant/firm |
| `Sarah` | Mature, reassuring, confident young American female |
| `George` | Warm, captivating storyteller, British middle-aged male |
| `Charlie` | Deep, confident, energetic young Australian male |
| `Brian` | Deep, resonant and comforting American male |
| `Lily` | Velvety actress, British middle-aged female |
| `Daniel` | Steady broadcaster, British middle-aged male |
| `Alice` | Clear, engaging educator, British middle-aged female |
| `Bill` | Wise, mature, balanced old American male |

### Voice Selection

**By name** — pass any built-in or custom voice name:

```powershell
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "Hello" -Voice "Adam"
```

**By voice ID** — use the raw ID (e.g., from cloned voices):

```powershell
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "Hello" -Voice "pNInz6obpgDQGcFmaJgB"
```

The script auto-detects names vs IDs. Names are resolved via the `/v1/voices` API. If no match is found, all available voices are listed in the error message.

**Discover voices:**

```powershell
$headers = @{ "xi-api-key" = $env:ELEVENLABS_API_KEY }
$voices = (Invoke-RestMethod -Uri "https://api.elevenlabs.io/v1/voices" -Headers $headers).voices
$voices | Select-Object name, voice_id, labels | Format-Table
```

### Emotion & Expressiveness (V3 Audio Tags)

Eleven v3 uses **audio tags** in square brackets to control vocal delivery. Tags must describe something **auditory** and only for the **voice** — never use tags for music, environmental sounds, or non-vocal effects.

> **CRITICAL**: Tags like `[music]`, `[standing]`, `[grinning]`, `[pacing]` are INVALID and will be read aloud or cause artifacts. V3 does NOT support SSML break tags.

#### Valid Audio Tags

**Emotional directions:**

`[happy]`, `[sad]`, `[excited]`, `[angry]`, `[whisper]`, `[annoyed]`, `[appalled]`, `[thoughtful]`, `[surprised]`, `[sarcastic]`, `[curious]`, `[mischievously]`, `[crying]`

**Non-verbal vocal sounds:**

`[laughing]`, `[laughs]`, `[laughs harder]`, `[starts laughing]`, `[wheezing]`, `[chuckles]`, `[sighs]`, `[clears throat]`, `[exhales sharply]`, `[inhales deeply]`, `[whispers]`, `[exhales]`, `[snorts]`, `[swallows]`, `[gulps]`, `[short pause]`, `[long pause]`

**Sound effects (less reliable, voice-dependent):**

`[gunshot]`, `[applause]`, `[clapping]`, `[explosion]`

**Experimental:**

`[strong X accent]`, `[sings]`, `[woo]`, `[fart]`

#### Invalid Tags (DO NOT USE)

| ❌ Invalid | Why |
|-----------|-----|
| `[music]`, `[piano music]`, `[soft music]` | Music tags are explicitly banned |
| `[bells]`, `[chime]`, `[wind]`, `[rain]` | Environmental sounds, not vocal |
| `[standing]`, `[grinning]`, `[pacing]` | Physical actions, not auditory |
| `[gentle transition]`, `[scene change]` | Structural cues, not vocal |
| `[heartbeat]`, `[footsteps]` | Body/environmental sounds |

#### Punctuation Controls

| Technique | Effect | Example |
|-----------|--------|---------|
| Ellipses `…` | Adds pauses and weight | `"It was… something else."` |
| CAPITALIZATION | Increases emphasis | `"That was INCREDIBLE!"` |
| `!` | Excitement/urgency | `"I can't believe it!"` |
| `?` | Questioning tone | `"Are you sure about that?"` |
| `—` (em dash) | Short pause | `"Wait — what was that?"` |

#### Voice Settings Parameters

| Parameter | Effect | Low Values | High Values |
|-----------|--------|------------|-------------|
| `-Stability` | Emotional variability | Creative (more expressive, may hallucinate) | Robust (consistent but less responsive to tags) |
| `-SimilarityBoost` | Voice fidelity | More creative | Closer to original voice |
| `-Style` | Style exaggeration | Neutral delivery | More dramatic/expressive |

> **Stability** is the most important V3 setting. Use Creative for maximum expressiveness with audio tags. Natural is balanced. Robust reduces tag responsiveness.

#### Tag Placement

Place tags **before** or **after** the text they modify:

```
[whispers] I never knew it could be this way.
Are you SERIOUS? [sighs] I can't believe that.
[excited] This is going to be AMAZING!
```

#### Examples

```powershell
# Excited delivery with audio tag
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "[excited] This is AMAZING!" -Stability 0.25 -Style 0.6 -Play

# Sad, reflective with punctuation
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "[sad] I really miss those days…" -Stability 0.3 -Style 0.5 -Play

# Whispering
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "[whispers] Don't tell anyone…" -Stability 0.5 -Style 0.4 -Play

# Narrative with mixed tags
.\scripts\Invoke-ElevenLabsTts.ps1 -Text "[happy] You are NOT going to believe this! [laughing] It actually WORKED!" -Play
```

> **Tip**: Match tags to the voice's character. A meditative voice won't shout convincingly; a hyped voice won't whisper well. The voice's training samples determine tag effectiveness.

## API Reference

Base URL: `https://api.elevenlabs.io`

### Key Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/text-to-speech/{voice_id}` | POST | Generate speech from text |
| `/v1/text-to-speech/{voice_id}/stream` | POST | Stream speech from text |
| `/v1/voices` | GET | List all available voices |
| `/v1/voices/{voice_id}` | GET | Get voice details |
| `/v1/models` | GET | List available models |
| `/v1/user` | GET | Get user info and quota |
| `/v1/user/subscription` | GET | Get subscription details |
| `/v1/history` | GET | Get generation history |
| `/v1/sound-generation` | POST | Generate sound effects |
| `/v1/voice-generation/generate-voice` | POST | Generate a random voice |

### Headers

All API requests require:

```
xi-api-key: {ELEVENLABS_API_KEY}
Content-Type: application/json
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 401 Unauthorized | Check `ELEVENLABS_API_KEY` is set and valid. Note: quota_exceeded also returns 401 — read full error message |
| 429 Too Many Requests | Rate limited — wait and retry |
| Voice not found | Use voice ID instead of name, or list voices first |
| No audio output | Check output path permissions and disk space |
| Playback fails | Ensure ffplay is installed (from ffmpeg) |
| Sentences mixing/garbled on long text | Text too long for single API call — script auto-chunks at >500 chars. If still bad, split into shorter paragraphs |
| `unsupported_model` with previous_text | V3 doesn't support text/request_id stitching yet. Script auto-skips for V3 |
| Audio cues read aloud | Only use valid V3 audio tags (see Emotion section). Never use `[music]`, `[bells]`, environmental tags |
