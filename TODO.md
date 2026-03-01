# Skills TODO

| Status | Priority | Task | Notes |
|--------|----------|------|-------|
| 📋 | Medium | [Update contributing skill documentation](#update-contributing-skill-documentation) | All contributing skills |
| 📋 | Medium | [Create ElevenLabs voice skill](#create-elevenlabs-voice-skill) | For use with OpenClaw |
| ✅ | High | Test complete diary workflow | All 10 scripts (010-100) tested individually (2026-03-01) |
| ✅ | Medium | Add WorkIQ integration to today and diary skills | 100-work.ps1 uses WorkIQ for meetings + emails (2026-03-01) |
| ✅ | High | Establish output/YYYY-MM-DD.md pattern | weather skill (2026-02-10) |
| ✅ | High | Verify today skill follows output pattern | today skill confirmed (2026-02-10) |
| ✅ | High | Verify weather skill only handles weather data | weather skill confirmed (2026-02-10) |
| ✅ | High | Remove news gathering logic from diary skill | diary skill updated (2026-02-11) |
| ✅ | High | Diary consumes weather + news output files directly | diary skill updated (2026-02-11) |
| ✅ | Medium | Document Slack Activity data collection | 18 channels, date-filtered (2026-02-11) |
| ✅ | Medium | Document Watchlist Updates integration | diary skill updated (2026-02-11) |
| ✅ | Medium | Document Daily Numbers (stocks + repo counts) | diary skill updated (2026-02-11) |
| ✅ | Medium | Document LLM Models (3 subsections) | leaderboard, releases, apps (2026-02-11) |
| ✅ | Medium | Document GitHub Trending Repos integration | diary skill updated (2026-02-11) |
| ✅ | Medium | Document Software Watchlist | 22+ items, version tracking (2026-02-11) |
| ✅ | Medium | Document Today's Productivity metrics | diary skill updated (2026-02-11) |
| ✅ | Medium | Document Todoist Integration | completed/upcoming/filtered (2026-02-11) |
| ✅ | Medium | Document Screenshots integration | screenshot skill library (2026-02-11) |
| ✅ | Medium | Verify Today's Highlight is user-provided | confirmed not auto-selected (2026-02-11) |

## Progress

**Completed: 17 / 19** (89%)

---

## Remaining Items

### Update contributing skill documentation

**Goal**: Finalize documented responsibilities for all skills involved in the diary workflow.

**Skills to update**: `weather`, `news`, `today`, `diary`, `slack`

**Each should clearly state**: what it owns, what it outputs, and what it does NOT do.

---

### Create ElevenLabs voice skill

**Goal**: Build a new skill that integrates with ElevenLabs TTS API for high-quality voice synthesis, usable via OpenClaw.

**Proposed capabilities**:

- Text-to-speech via ElevenLabs API (voice selection, stability, similarity settings)
- Voice cloning support
- Output to audio file (MP3/WAV)
- OpenClaw integration for voice responses

**Reference**: `play-audio` and `edge-tts` skills for patterns to follow.
