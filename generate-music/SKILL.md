---
name: generate-music
description: "V1.0 - Generate Lyria music, songs, instrumentals and soundtrack drafts through the Gemini API. Use when the user invokes this skill or requests a Lyria music workflow. Not for speech, voice cloning or general sound effects."
disable-model-invocation: true
compatibility: Requires Python 3.10+, ffmpeg, ffprobe, network access, and GEMINI_API_KEY with paid Lyria access. API billing is separate from an Antigravity or Gemini app subscription.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If generate-music files were used or changed, verify a factual,
            shell-timestamped History entry exists. Never invent timestamps.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Verify that any claimed generated music exists and passed file
            validation. Distinguish technical validation from listening review.
            Confirm paid-call approval and record the outcome and retrospective
            in the skill History. Never claim success from prose alone.
---

# Generate music

Generate music through Google's [Lyria Interactions API](https://ai.google.dev/gemini-api/docs/music-generation).
Use the bundled Python script directly. No Antigravity subprocess, agent
delegation, browser automation, third-party music service or SDK package is
needed. This is paid API access, not subscription-based native generation.

Resolve `scripts/generate_music.py` relative to this skill's directory and use
its absolute path in commands. Run `python <script> --help` first. On systems
where Python is named `python3`, use that executable.

## Prepare and approve

1. Read the project's asset rules. Capture the intended use, musical style,
   instruments, mood, tempo, vocal language, any user-provided lyrics, and output
   destination. Preserve detailed user instructions in a UTF-8 prompt file.
   Prefer section tags such as `[Verse]`, `[Chorus]` and `[Bridge]`. State
   `instrumental, no vocals` when vocals are unwanted. Treat exact timing, BPM,
   key and seamless loops as requests to verify, not guarantees.
2. Use `lyria-3.5` for full songs and highest-quality requests. Offer
   `lyria-3-clip-preview` for inexpensive 30-second prompt trials. Do not silently
   downgrade to Clip or generate both. MP3 is the default. Only Lyria 3.5 supports
   the helper's WAV option. RealTime streaming, image inputs, stems and editing
   existing tracks are outside this skill's first version.
3. Check the current [Google pricing](https://ai.google.dev/gemini-api/docs/pricing).
   The helper's published estimates were checked on September 18, 2026:
   Lyria 3.5 costs USD 0.08 per song and Clip costs USD 0.04 per song. Neither has
   a free tier. If pricing has changed, stop and update the helper's estimates
   and tests before generation. `--max-cost-usd` checks the local estimate only;
   it cannot enforce a Google billing cap.
4. Obtain approval for the model, request count and estimated spend before
   `generate`. Existing explicit approval for that bounded request is enough.
   A full-song request needs approval even after an approved Clip trial. Do not
   treat the helper's numeric flag as permission or buy credits, enable billing,
   rotate keys, change provider or install dependencies without authorization.
5. Use `GEMINI_API_KEY` from the environment. Never print it, put it in command
   arguments, read authentication stores or ask for it in chat. If absent, the
   user must configure it privately using [Google AI Studio](https://aistudio.google.com/apikey).
   `ffmpeg` and `ffprobe` must already be on PATH. The helper checks dependencies
   before any paid call. Do not inherit a different Google API key silently.

## Run

An offline plan makes no network request and does not require credentials:

```text
python <script> plan --prompt-file <prompt.txt> --model lyria-3-clip-preview --name piano-study
```

One approved Clip request:

```text
python <script> generate --prompt-file <prompt.txt> --model lyria-3-clip-preview --max-cost-usd 0.04 --out-dir <project-assets> --name piano-study
```

One separately approved full-song request:

```text
python <script> generate --prompt-file <prompt.txt> --model lyria-3.5 --format wav --max-cost-usd 0.08 --out-dir <project-assets> --name piano-song
```

Quote paths containing spaces. `--prompt` accepts short public prompts directly;
use `--prompt-file` for private material to avoid shell-history exposure. The
script sends the prompt to Google and saves it in the local manifest.

The default destination is `output/musicgen` under the current directory. Each
call reserves a new folder such as `piano-study-v001`, then saves:

- `track.mp3` or `track.wav`, the original audio bytes without conversion.
- `lyrics.txt`, returned text, which may include arrangement notes.
- `manifest.json`, prompt, requested and reported model, estimated price,
  interaction ID, technical validation, SHA-256 and listening-review status.
- `response.json`, the unmodified API response for local recovery. It contains
  audio and potentially private text. Keep it out of shared logs and Git.

If a request fails, retain the error and run directory. The helper never retries
or changes provider. A timeout can mean a paid generation completed remotely.
A retained `response.json` may allow local extraction without another API call.
Do not blindly resubmit, concatenate unexpected audio blocks or substitute
synthetic tones. Report billing or quota failures without claiming that model
visibility proves paid access.

## Verify and deliver

1. Require a successful exit and a manifest with `status: validated`. The script
   uses ffprobe to check the container, duration, channels and sample rate, then
   fully decodes the file with ffmpeg. It records SHA-256 and flags deviations
   from the documented 44.1 kHz stereo and 30-second Clip duration.
2. Inspect all warnings. If the request's timing or format is unmet, report it.
   Keep the original when creating a separately named trim, fade or conversion.
   Recompute metadata and distinguish post-processing from model generation.
3. Listen using an available audio-capable tool or request human listening
   approval. Check clipping, unwanted vocals, cut-off endings, lyric accuracy
   and musical fit. Do not claim to have listened if only decoder checks ran.
   Keep `listening_review: pending` and final-use approval pending until reviewed.
4. Link the delivered audio file and manifest. Report actual duration, model
   provenance and any unmet constraints. Never infer a returned model if the
   response does not expose it. Price estimates are not billing receipts.
5. Google documents an imperceptible SynthID watermark. Local decoding does not
   detect it. Do not remove watermarks or promise exclusive copyright or cleared
   third-party rights. Follow Google's safety restrictions and do not bypass
   artist-voice or copyrighted-lyrics filters.

## Validation and maintenance

Run offline tests after changes. They mock paid requests and label synthetic
fixtures as test data, never as generated music:

```text
python -m unittest discover -s <skill-directory>/tests -v
```

See [implementation notes](references/implementation.md) for the API contract,
known limits and live-test evidence. Follow the shared fleet deployment rules
for active skill updates, without copying credentials, generated audio, history
or private responses to peers.

## History

After using or changing this skill, append `## HH:MM - {Action Taken}` and a
one-line outcome to `History/{YYYY-MM-DD}.md` in this skill directory. Obtain the
current timestamp from the shell in America/New_York, never an estimate. Record
whether the retrospective found a reusable improvement. Keep prompts, lyrics,
credentials and raw API responses out of shared history.
