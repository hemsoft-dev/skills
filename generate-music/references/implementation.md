# Implementation notes

## API contract

Checked against Google's documentation on September 18, 2026.

- [Music generation](https://ai.google.dev/gemini-api/docs/music-generation) documents
  `POST https://generativelanguage.googleapis.com/v1beta/interactions` with
  `x-goog-api-key`, `model`, and `input`. Lyria 3.5 defaults to MP3. The documented
  WAV selector is `response_format: {"type": "audio"}`.
- The current response contains `steps` with `type: model_output`, whose
  `content` contains `audio` blocks with base64 `data` and `text` blocks. The
  parser also accepts the older `outputs` shape when `steps` is absent. It
  rejects zero or multiple audio blocks rather than concatenating them.
- [Pricing](https://ai.google.dev/gemini-api/docs/pricing) lists USD 0.08 per
  Lyria 3.5 song and USD 0.04 per Lyria 3 Clip preview. Neither has a free tier.
- [Prompt guidance](https://ai.google.dev/gemini-api/docs/lyria-prompt-guide)
  covers musical direction, lyrics and structure. Exact duration and seamless
  loops need verification. Multi-turn editing is not supported.
- [Antigravity skills](https://antigravity.google/docs/skills/) can run bundled
  scripts. Antigravity is not the music-generation backend here.

The helper uses only Python's standard library for HTTP. It keeps credentials
in request headers, refuses redirects, limits response size and never retries a
paid POST. No SDK version or agent authentication session is required. The
script does not enable billing, modify quotas or select another key.

## Verification evidence

- Home has Python 3.12, ffmpeg and ffprobe. The offline test suite exercises
  request construction, approval limits, credentials, failure handling,
  versioned outputs, response parsing and real decoder checks. No unit test
  calls Google. Generated sine-wave fixtures are synthetic test data only.
- The configured API key listed Lyria models and completed a read-only
  `countTokens` call for Lyria 3.5 during the feasibility check. Neither proves
  paid generation access.
- One authorized Lyria 3 Clip request returned HTTP 429 with Google's message
  `Your prepayment credits are depleted`. No music was generated. No retry,
  full-song request, key substitution or billing change followed.
- MP3 generation, WAV generation, actual billed amounts and subjective music
  quality remain unverified end to end. Fixture tests are not provider success.

The failed local request receipt is kept outside the skill under
`D:/output/musicgen/lyria-smoke-test-v001/manifest.json`. It is not distributed to
peers. To unblock generation, the owner must replenish the configured project's
credits in [AI Studio billing](https://ai.studio/projects), then approve a new
bounded test. Do not interpret the original failed attempt as permission to
retry indefinitely.

## Installation

The canonical user-level directory is `~/.agents/skills/generate-music`.
Antigravity CLI's documented global directory is
`~/.gemini/antigravity-cli/skills/generate-music`; use a directory link to the
canonical copy so updates do not diverge. Home uses a Windows junction. Unix
peers use a symlink. Do not replace an existing unrelated folder or link.

On Air, the system Python is 3.9. Use `/opt/homebrew/bin/python3` and include
`/opt/homebrew/bin` in the command's PATH to reach its installed FFmpeg tools.
Mini has Python 3.14 but no ffmpeg or ffprobe on the inspected PATH. Generation
there must wait for authorized dependency setup. No API keys are distributed.

## Scope and recovery

This version accepts text prompts and optional custom lyrics in the same text
file. Image-conditioned generation, real-time streaming, speech, stems and
in-place audio edits are excluded. Use a dedicated workflow for those tasks.

A run keeps the original audio and raw response without transcoding. A failure
after receiving the response leaves `response.json` available for local
inspection and extraction. Fix parsing or local validation before considering
another paid call. Do not print base64 audio or private prompts in shared logs.
A network timeout may have an unknown billing outcome and might leave no
response file.

Technical checks establish decodability, not musical quality or silence-free
audio. Listening and final-use approval remain separate. SynthID is documented
provider behavior, not a local watermark detection result.
