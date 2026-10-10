---
name: generate-audio
description: "V1.0 - Commands: audio, stop-hook. Generate speech with Seed Audio and saved reference voices, defaulting to guide. Use stop-hook to generate a clip and install a repository-local Pi completion hook."
compatibility: Requires PowerShell 7, OPENROUTER_API_KEY for generation, and Node.js 24 for the hook installer and tests. Playback uses ffplay on Windows/Linux or afplay on macOS.
---

# Generate audio

Generate MP3 speech with OpenRouter's `bytedance-seed/seed-audio-1-0`.
Default to the saved `guide` voice unless the user specifies another voice.
Use the bundled scripts; do not depend on an hs-tui-launcher checkout.
Resolve every relative helper path against this skill directory.

## Invocation

```text
/generate-audio <audio-prompt-text> [voice or destination instructions]
/generate-audio stop-hook <audio-prompt-text> [voice or destination instructions]
```

The user-level Pi prompt template supplies `/generate-audio`.
Pi's native `/skill:generate-audio` accepts the same request.

Only a leading `stop-hook` selects hook mode. Otherwise the request is an
ordinary audio prompt. A leading `--` means literal audio text, even if the
next word is `stop-hook`. Do not speak mode keywords, voice selectors, output
instructions, or synthesis directions. Preserve the requested words and
punctuation. For a requested exact phrase, tell the model to speak that phrase
once and nothing else, using the reference voice. Ask for text if it is missing.

Examples:

```text
/generate-audio Welcome aboard.
/generate-audio Welcome aboard. Use narrator and save to D:\Audio\welcome.mp3
/generate-audio stop-hook HemSoft Buddy is done working.
/generate-audio stop-hook The launcher is done working. Use guide.
/generate-audio -- stop-hook is the name of this feature.
```

## Prepare and generate

1. Read the target project's instructions. Resolve the requested repository
   and destination. Honor explicit file or folder instructions. Ordinary
   audio defaults to the user's `Music/OpenRouter/SeedAudio` folder. Hook mode
   defaults to `<repository>/assets/done.mp3`. Do not infer extra spoken words
   from the repository name.
2. Check PowerShell 7 and Node.js 24 before using their helpers. In an SSH
   shell with a minimal PATH, check verified login-shell or installed executable
   paths before declaring a dependency missing. Keep PATH changes process-local.
   Guide is the default. Existing profiles in
   `~/.config/hs-tui-launcher/seed-audio-voices.json` take precedence. When that
   registry is absent, the bundled profile uses the original synthetic guide
   reference in `assets/guide.mp3`. Its transcript is intentionally blank.
   A missing/unconfigured requested voice is an error, not permission to fall
   back to prompt-only speech or invent a speaker ID. Use `-ListVoices` to
   inspect profiles and `-SaveVoice` with consent for a new licensed reference.
3. Validate the request with `-DryRun` before uploading or spending. Use
   `-OutputFile` for an exact MP3 name, or `-OutputDirectory` for a folder with
   unique filenames. Neither the preview nor metadata exposes prompt text,
   reference transcripts, base64 audio, or credentials.
4. State that the published rate is $0.15 per output minute, up to 120 seconds
   or an estimated $0.30 per request. The provider has no documented hard
   request budget/duration control. An explicit generation request authorizes
   one paid call; use `-Force` only for that authorized call. Do not generate
   anything paid while merely creating, testing, or installing this skill.
5. Run `scripts/New-Audio.ps1` with the resolved prompt, voice and destination.
   Pass text as data, never as shell code. For quotes or multiline text, write
   a temporary UTF-8 prompt file and pass its path to `-Prompt`.
   `OPENROUTER_API_KEY` must already be in the environment. Never read auth
   files, request a key in chat, print it, or copy credentials between hosts.
   Do not automatically retry a paid request or change providers.

PowerShell example, using absolute helper and destination paths at execution:

```powershell
pwsh -NoProfile -File '<skill>/scripts/New-Audio.ps1' `
  -Prompt 'Use the reference speaker. Speak only: Welcome aboard.' `
  -OutputFile '<destination>/welcome.mp3' -DryRun
```

Replace `-DryRun` with `-Force -NoOpen` for an explicitly requested generation.
The helper defaults to guide. `-Voice narrator` or `-Voice character` overrides
it when configured. Do not overwrite existing audio or sidecars unless the
user requests replacement; `-Replace` requires an explicit `-OutputFile`.
For a replacement, generate to a fresh staging filename first, validate it,
then move it to the requested name. Preserve old audio until those checks pass.
Delete obsolete copies only when the user asks, and never delete unrelated sounds.

## Stop-hook mode

This mode installs a **Pi** completion hook, not a Python or Git hook. Use
`agent_settled`, not `agent_end`, so retries and queued follow-ups finish first.
No commit is needed. Playback is repo-local; headless children and other or
nested repositories stay silent. Do not change Git hooks or global completion
settings.

1. Inspect any existing completion hook first. If it is safely repo-scoped
   and already plays the selected path, reuse it rather than rewriting code.
   Generate or replace only its audio, then verify that existing hook.
   Otherwise, before generating paid audio, preflight the installer:

   ```text
   node <skill>/scripts/install-stop-hook.mjs --repo <repository> --audio <resolved-mp3-path> --dry-run
   ```

   Read the result. Existing conflicting hook code/configuration is preserved.
   Request explicit replacement authority before adding `--replace-hook`;
   ordinary audio replacement does not authorize replacing unrelated code.
2. Generate and validate the chosen MP3. Default to `assets/done.mp3`; keep a
   user-specified destination instead. Paths outside the repo are supported,
   but report that they make this hook machine-specific.
3. Run the same installer without `--dry-run`. It creates only:
   - `.pi/extensions/done-sound.ts`
   - `.pi/done-sound.json`, with the selected audio path
   - `scripts/Play-DoneSound.ps1`

   The installed hook is self-contained and does not require this skill at
   playback time. Existing Git, Husky, Copilot, or other agent hooks remain
   unchanged. The installer is idempotent and detects changed/conflicting files.
4. Verify the installed config points to the actual MP3. Check Pi can load the
   extension and inspect its scope guard. Run the bundled offline tests when
   changing the templates or installer. Do not commit, push, trust a project,
   weaken host-key checks, or edit agent configuration as a hidden side effect.
5. Play once with the installed script and `-AudioPath` set to the selected
   destination. Playback must not open a media-player window. Failures warn
   without changing the completed task's outcome. The hook loads on the next
   trusted Pi project launch or resource reload; do not claim it was hot-loaded.

Set `GENERATE_AUDIO_DONE_SOUND=0` before starting Pi to mute a generated hook,
or set `enabled` to `false` in that repo's `.pi/done-sound.json`.

## Verify and deliver

- Confirm the output exists and is nonempty. The helper checks HTTP status,
  MP3 MIME type and header. Use `ffmpeg`/`ffprobe` to verify decoding and duration
  when available. A header check alone is not a listening or transcription check.
- Check the sidecar records the selected voice and reference mode/hash. Reference
  reuse improves consistency but does not guarantee an identical speaker.
- Pricing and request fields are documented in the official
  [Seed Audio page](https://openrouter.ai/bytedance-seed/seed-audio-1-0) and
  [speech API](https://openrouter.ai/docs/api/api-reference/tts/create-speech.md).
  Recheck provider documentation if its contract or pricing changes.
- Link the final file. Report the actual billed cost only when verified from
  the generation receipt; otherwise give the published estimate, labeled as such.
- For hook mode, report the repo, selected path, validation and activation state.
- Test without provider access or sound with
  `node --test <skill>/tests/generate-audio.test.mjs`. Use synthetic credentials
  for request mocks and never inherit a real key into tests.

## History

After using or changing this skill, append `## HH:MM - {Action Taken}` and a
one-line outcome to `History/{YYYY-MM-DD}.md` in this skill directory. Obtain
Eastern Time from the shell, never guess it. Note whether the retrospective
found a reusable improvement. Do not log private prompts or credentials.
