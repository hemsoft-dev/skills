---
name: installs
description: V1.1 - Fresh Windows setup guide for installing and configuring essential apps, tools, and HemSoft development environment.
---

# Windows Install

Complete setup guide for a fresh Windows installation with HemSoft development environment.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

**CRITICAL:** If adding a new tool or application, YOU MUST DO ALL 4 STEPS:

1. ⚠️ **FIRST:** Update `INSTALLS.md` with the installation command (prefer `winget` for mainstream, `scoop` for dev tools)
2. ⚠️ **SECOND:** Add the tool to the `Quick Install Script` in `INSTALLS.md` if available via `winget`
3. **THIRD:** Add the tool to the `Post-Install Checklist` in `SKILL.md`
4. **FOURTH:** Update the `Install Tracking` section in `SKILL.md` for the current machine

**DO NOT SKIP STEPS 1 & 2** - They are the most important for future installations.

## Prerequisites

- Windows 11 with internet connection
- Administrator access
- HemSoft GitHub credentials (<franz_hemmer@hotmail.com>)

## Installation Steps

See [INSTALLS.md](INSTALLS.md) for full installation instructions.

## Post-Install Checklist

- [ ] Scoop installed with nerd-fonts bucket
- [ ] Dev fonts installed (JetBrains, Geist, Victor, Iosevka)
- [ ] Edge signed in and synced
- [ ] LastPass extension installed and logged in
- [ ] OneDrive configured and syncing
- [ ] Git configured with name/email
- [ ] GitHub CLI authenticated to HemSoft
- [ ] Bun installed
- [ ] VS Code Insiders installed with settings restored
- [ ] Claude Code installed (`claude --version`)
- [ ] Gemini CLI installed (`gemini --version`)
- [ ] Skills copied to `~/.claude/skills/`
- [ ] Agents copied to VSCode Insiders global agents
- [ ] Obsidian installed and vault configured
- [ ] MarkText installed (fast Markdown viewer)
- [ ] Discord installed and logged in
- [ ] Todoist installed as Edge app
- [ ] Steam installed and logged in
- [ ] AutoHotkey running with startup script
- [ ] Wispr Flow installed and configured
- [ ] Directory Opus installed and licensed
- [ ] SnagIt installed and licensed
- [ ] Slack installed and logged in
- [ ] Microsoft Teams installed and logged in
- [ ] NVIDIA Broadcast installed and configured
- [ ] XSplit VCam installed and licensed
- [ ] .NET SDK installed
- [ ] Python 3.12 installed
- [ ] Docker Desktop installed
- [ ] Neo4j running in Docker (<http://localhost:7474>)
- [ ] edge-tts installed (TTS for AutoHotkey)
- [ ] Goose CLI installed (AI agent)
- [ ] VLC media player installed
- [ ] Audacity installed
- [ ] Spotify installed and logged in
- [ ] Logitech G Hub installed
- [ ] ClipChamp installed
- [x] cloc installed
- [x] Pandoc installed (document conversion)
- [ ] ffmpeg installed (media processing)
- [ ] docling installed (document processing and parsing)
- [ ] Ollama installed (local LLM runtime)
- [ ] OpenCode installed
- [ ] GitHub Copilot CLI installed (`copilot --version`)
- [ ] uv installed (fast Python package manager)
- [ ] LangFlow installed (AI workflow builder, venv at ~/.langflow)

## Install Tracking

### Franz PC 2026

- [x] Scoop installed with nerd-fonts bucket
- [x] Dev fonts installed (JetBrains, Geist, Victor, Iosevka)
- [x] Edge signed in and synced
- [x] VS Code Insiders installed with settings restored
- [x] LastPass extension installed and logged in
- [x] Bun installed (v1.3.5)
- [x] SnagIt installed and licensed
- [x] Slack installed and logged in
- [x] Microsoft Teams installed and logged in
- [x] NVIDIA Broadcast installed and configured
- [x] XSplit VCam installed and licensed
- [x] .NET SDK installed
- [x] Docker Desktop installed
- [x] VLC media player installed
- [x] Audacity installed
- [x] Spotify installed and logged in
- [x] Logitech G Hub installed
- [ ] ClipChamp installed
- [x] cloc installed
- [x] Pandoc installed (3.8.3, document conversion)
- [x] ffmpeg installed
- [x] Goose CLI installed (v1.18.0, GitHub Copilot provider)
- [x] OneDrive configured and syncing
- [x] Git configured with name/email
- [x] GitHub CLI authenticated to HemSoft
- [x] Claude Code installed
- [x] Gemini CLI installed (v0.23.0)
- [x] Skills copied to `~/.claude/skills/`
- [ ] Agents copied to VSCode Insiders global agents
- [x] Obsidian installed and vault configured
- [ ] MarkText installed
- [x] Discord installed and logged in
- [x] Todoist installed as Edge app
- [x] Steam installed and logged in
- [x] AutoHotkey running with startup script
- [x] Wispr Flow installed and configured
- [x] Directory Opus installed and licensed
- [x] Python 3.12 installed
- [ ] Neo4j running in Docker (<http://localhost:7474>)
- [x] edge-tts installed
- [x] ffmpeg installed
- [x] Goose CLI installed (v1.18.0, GitHub Copilot provider)
- [x] Ollama installed (local LLM runtime)
- [ ] docling installed (document processing and parsing)
- [ ] OpenCode installed
- [x] GitHub Copilot CLI installed (v0.0.381)
- [x] uv installed (v0.9.26, via pipx)
- [x] LangFlow installed (v1.7.2, venv at ~/.langflow)

## Hotkey Reference (AutoHotkey)

| Hotkey             | Action                         |
|--------------------|--------------------------------|
| `Ctrl+Shift+E` | Edit AutoHotkey script |
| `Ctrl+Shift+R` | Reload AutoHotkey script |
| `Ctrl+Shift+G` | Activate/Launch ChatGPT |
| `Ctrl+Shift+N` | Activate/Launch Obsidian (Notes) |
| `Ctrl+Shift+T` | Activate/Launch Todoist |
