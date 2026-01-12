# Watchlist

Items being tracked and monitored.

---

<!-- Add entries below this line -->

## Anthropic Agent Skills Technology

- **Status**: Active
- **Added**: 2024-12-24
- **Expires**: Never
- **Notes**: Tracking the evolution of Anthropic's Skills system - an open standard for giving AI
  agents new capabilities via SKILL.md files. Watch for spec updates, industry adoption, and new
  integrations.

### Key Resources to Monitor

| Resource                     | URL                                                                           | What to Watch                            |
|------------------------------|-------------------------------------------------------------------------------|------------------------------------------|
| **Agent Skills Spec**        | <https://agentskills.io>                                                      | Official open standard spec, adoption list |
| **GitHub: anthropics/skills** | <https://github.com/anthropics/skills>                                       | New skills, spec changes, PRs, issues    |
| **GitHub: agentskills/agentskills** | <https://github.com/agentskills/agentskills>                          | Open standard development                |
| **Claude Cookbooks (skills)** | <https://github.com/anthropics/claude-cookbooks/tree/main/skills>            | Cookbook updates, new notebooks          |
| **Anthropic Engineering Blog** | <https://www.anthropic.com/engineering>                                      | New engineering posts on Skills          |
| **Skills Overview Docs**     | <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview> | Official documentation updates           |
| **Support: What are Skills?** | <https://support.claude.com/en/articles/12512176-what-are-skills>            | User-facing changes                      |
| **Support: Custom Skills**   | <https://support.claude.com/en/articles/12512198-creating-custom-skills>     | Authoring guidance changes               |

### Industry Adoption (as of Dec 2024)

- OpenCode
- Cursor
- Amp
- Letta
- Goose (Block)
- GitHub
- VS Code
- Claude Code
- Claude.ai
- OpenAI Codex

### Partner Skills to Watch

- **Notion**: <https://www.notion.so/notiondevs/Notion-Skills-for-Claude-28da4445d27180c7af1df7d8615723d0>
- **Box**: Skills integration for document workflows
- **Canva**: Planning Skills integration for design workflows
- **Rakuten**: Finance/accounting workflow Skills

### Key Milestones

- [x] Oct 16, 2025 - Skills announced (engineering blog)
- [x] Dec 18, 2025 - Agent Skills published as open standard at agentskills.io
- [ ] Official spec versioning/releases
- [ ] Skills marketplace/discovery
- [ ] Self-improving agents creating their own Skills

---

## GitHub Copilot in VS Code Insiders

- **Status**: Active
- **Added**: 2024-12-24
- **Expires**: Never
- **Notes**: Tracking GitHub Copilot feature enhancements as they flow through the VS Code
  Insiders pipeline. Focus on new capabilities, agent mode improvements, and MCP integrations.

### Key Resources to Monitor

| Resource                     | URL                                                                            | What to Watch                                         |
|------------------------------|--------------------------------------------------------------------------------|-------------------------------------------------------|
| **VS Code Release Notes**    | <https://code.visualstudio.com/updates>                                        | Monthly stable release features                       |
| **VS Code Insiders Download** | <https://code.visualstudio.com/insiders>                                      | Daily builds info                                     |
| **GitHub: vscode-copilot-chat** | <https://github.com/microsoft/vscode-copilot-chat>                           | Source code, commits, PRs, releases                   |
| **Copilot Chat Releases**    | <https://github.com/microsoft/vscode-copilot-chat/releases>                    | Version history (v0.35.2 stable, v0.36.x pre-release) |
| **Copilot Chat CHANGELOG**   | <https://github.com/microsoft/vscode-copilot-chat/blob/main/CHANGELOG.md>      | Detailed change history                               |
| **VS Code Repo**             | <https://github.com/microsoft/vscode>                                          | Core editor commits                                   |
| **VS Code Issues**           | <https://github.com/microsoft/vscode/issues>                                   | Feature requests, bugs                                |
| **VS Code Blog**             | <https://code.visualstudio.com/blogs>                                          | Announcements                                         |
| **Copilot Docs**             | <https://code.visualstudio.com/docs/copilot/overview>                          | Official documentation                                |

### Current Stable: v1.107.1 (Dec 10, 2025)

Major release with multi-agent orchestration, background agents with Git worktrees, and Claude Skills support.

### Current Insiders: v1.108 (January 2026)
>
> **Last Updated**: January 3, 2026

#### Copilot Chat Extension

- **Stable**: v0.35.2 (Dec 19, 2025)
- **Pre-release**: v0.36.2025121901

#### Hot Off the Press (Jan 2-3, 2026)

##### Agent Sessions (Major Focus)

- Agent sessions quick access (#285715) - @roblourens
- Accept in background as editor (#285723) - @bpasero
- Developer: Inspect Chat Model action (#285707) - @roblourens
- Fix slow requests when other chat requests running (#285717) - @roblourens
- Remove count on chat editor title (#285691)

##### Terminal Improvements

- Shell history prevention for pwsh (#285599)
- Shell integration script cleanup
- Terminal view lifecycle fixes (#285661, #285657)
- Text-decoration-color support (#285582)
- Auto-approve commands fix (#282471)

#### v1.107 Stable Highlights (What's Now Live)

- [x] Agent HQ - Unified agent sessions in Chat view
- [x] Background agents with Git worktrees isolation
- [x] Claude Skills reuse (`chat.useClaudeSkills` setting)
- [x] Custom agents as subagents
- [x] GitHub MCP Server (Preview) - built-in
- [x] MCP Spec 2025-11-25 support
- [x] TypeScript 7.0 preview extension
- [x] Extended thinking for Anthropic models (4K tokens default)
- [x] Language Models editor for managing chat models
- [x] Organization-wide custom agent sharing

### Features to Watch in v1.108

- [ ] Agent sessions quick access improvements
- [ ] Background session acceptance workflows
- [ ] Chat model inspection/debugging tools
- [ ] Performance improvements for concurrent requests
- [ ] Continued terminal shell integration improvements

### Social/Community

- **X (Twitter)**: <https://twitter.com/code>
- **YouTube**: <https://www.youtube.com/@code>
- **VS Code Insiders Podcast**: <https://www.vscodepodcast.com/>
- **Reddit**: <https://www.reddit.com/r/vscode/>

---

## Claude Code

- **Status**: Active
- **Added**: 2026-01-09
- **Expires**: Never
- **Notes**: Tracking Claude Code evolution, releases, and feature updates as Anthropic's AI-powered coding assistant.

### Key Resources to Monitor

| Resource                     | URL                                                                            | What to Watch                            |
|------------------------------|--------------------------------------------------------------------------------|------------------------------------------|
| **GitHub: anthropics/claude-code** | <https://github.com/anthropics/claude-code>                            | Source code, commits, PRs, releases      |
| **Claude Code CHANGELOG**    | <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>             | Version history and feature releases     |
| **Claude Code Releases**     | <https://github.com/anthropics/claude-code/releases>                           | Release notes and version tags           |
| **Anthropic Engineering Blog** | <https://www.anthropic.com/engineering>                                      | New posts about Claude Code              |

### Latest Updates

- Integrated with VS Code as extended Copilot Chat functionality
- Part of multi-agent orchestration in v1.107.1+
- Claude Skills support added in v1.107

---

## Gemini CLI

- **Status**: Active
- **Added**: 2026-01-09
- **Expires**: Never
- **Notes**: Tracking Google's Gemini CLI - an open-source AI agent bringing Google's Gemini directly to your terminal. Lightweight, developer-focused with MCP server support and real-time web grounding.

### Key Resources to Monitor

| Resource                     | URL                                                                            | What to Watch                            |
|------------------------------|--------------------------------------------------------------------------------|------------------------------------------|
| **GitHub: google-gemini/gemini-cli** | <https://github.com/google-gemini/gemini-cli>                         | Source code, commits, PRs, issues        |
| **Changelog**                | <https://github.com/google-gemini/gemini-cli/blob/main/docs/changelogs/index.md> | Version history and changes              |
| **Releases**                 | <https://github.com/google-gemini/gemini-cli/releases>                        | Release notes (weekly stable, nightly)   |
| **Official Documentation**   | <https://geminicli.com/docs/>                                                  | Docs and guides                          |
| **Roadmap**                  | <https://github.com/google-gemini/gemini-cli/blob/main/ROADMAP.md>             | Planned features and improvements        |
| **NPM Package**              | <https://www.npmjs.com/package/@google/gemini-cli>                             | Package info and version history         |

### Current Status

- **Latest Stable**: v0.23.0 (Jan 6, 2026)
- **Release Cadence**: Weekly stable (Tuesdays 20:00 UTC), weekly preview (Tuesdays 23:59 UTC), nightly builds
- **Total Releases**: 284
- **License**: Apache 2.0
- **Stars**: 90.3k

### Key Features

- Code understanding and generation
- Automation & integration (MCP servers support)
- Google Search grounding for real-time information
- Terminal-first design for developers
- Free tier: 60 req/min, 1,000 req/day
- Gemini 2.5 Pro with 1M token context window

---

## Ollama Models for RTX 5090

- **Status**: Active
- **Added**: 2026-01-11
- **Expires**: Never
- **Notes**: Tracking new Ollama models optimized for RTX 5090 (32GB VRAM). Focus on models with tool/function calling support for AI agent integration (Goose, etc.).

### Hardware Constraints

- **GPU**: NVIDIA RTX 5090 (32GB VRAM)
- **Sweet Spot**: Models 5-20GB (comfortable headroom)
- **Max Practical**: ~24GB models (leaves room for context)

### Current Recommended Models

| Model | Size | Tool Support | Status |
|-------|------|--------------|--------|
| `qwen3:14b` | 9.3GB | ✅ | Primary choice |
| `qwen2.5-coder:32b` | 19GB | ✅ | Best for coding |
| `hermes3:8b` | 5GB | ✅ | Function calling specialist |
| `llama3.1:8b` | 5GB | ✅ | General purpose |
| `mistral-nemo:12b` | 7GB | ✅ | Strong tool support |
| `deepseek-r1:14b` | 9GB | ✅ | Reasoning model |

### Key Resources to Monitor

| Resource | URL | What to Watch |
|----------|-----|---------------|
| **Ollama Model Library** | <https://ollama.com/library> | New model releases |
| **Ollama Blog** | <https://ollama.com/blog> | Announcements, new features |
| **Ollama GitHub** | <https://github.com/ollama/ollama> | Releases, issues |
| **Ollama Discord** | <https://discord.gg/ollama> | Community discussions |
| **r/LocalLLaMA** | <https://reddit.com/r/LocalLLaMA> | Community model reviews |
| **Hugging Face Trending** | <https://huggingface.co/models?sort=trending> | New models to watch |

### Models to Watch For

- [ ] Qwen3 larger variants (30b+) when released
- [ ] Llama 4 family (expected 2026)
- [ ] DeepSeek R2 (next generation reasoning)
- [ ] Mistral next-gen models
- [ ] Phi-4 larger variants
- [ ] New function-calling optimized models

### What Makes a Good 5090 Model

1. **Size**: 5-20GB optimal, up to 24GB workable
2. **Tool Calling**: MUST support function/tool calling for agent use
3. **Context Window**: Larger is better (32k+ preferred)
4. **Speed**: Good tokens/sec on consumer hardware
5. **Quantization**: Q4_K_M or Q5_K_M for size/quality balance

---

## Apple Siri Assistant

- **Status**: Active
- **Added**: 2026-01-12
- **Expires**: Never
- **Notes**: Tracking Apple's Siri AI assistant evolution, especially AI/LLM improvements, developer API updates, and integration with Apple Intelligence features.

### Key Resources to Monitor

| Resource | URL | What to Watch |
|----------|-----|---------------|
| **Apple Newsroom** | <https://www.apple.com/newsroom/> | Official announcements |
| **Apple Developer News** | <https://developer.apple.com/news/> | API updates, WWDC info |
| **SiriKit Documentation** | <https://developer.apple.com/documentation/sirikit> | Developer API changes |
| **Apple Intelligence** | <https://www.apple.com/apple-intelligence/> | AI features integration |
| **iOS Release Notes** | <https://developer.apple.com/documentation/ios-release-notes> | iOS updates |
| **WWDC Sessions** | <https://developer.apple.com/videos/> | Annual conference updates |

### Key Features to Watch

- [ ] LLM/Generative AI improvements
- [ ] On-device AI capabilities
- [ ] Developer API expansions
- [ ] Third-party app integrations
- [ ] Privacy-preserving AI features
- [ ] Multi-modal capabilities (vision, audio)
- [ ] App Intents framework updates
- [ ] Shortcuts automation improvements

### Expected Updates

- **WWDC 2026**: Major annual announcement (typically June)
- **iOS 19**: Expected Fall 2026
- **Apple Intelligence v2**: Expected throughout 2026

### Competitive Context

Monitoring against: Google Assistant, Amazon Alexa, Claude, ChatGPT, Gemini, Copilot
