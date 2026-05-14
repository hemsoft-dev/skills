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

### Latest Movement (2026-05-12)

- Anthropic's engineering article now explicitly points readers to Agent Skills as an open standard, reinforcing that the format is no longer Claude-only.
- agentskills.io is now the main hub for docs, client showcase, and open development, which is a meaningful maturity step beyond the original announcement phase.
- Biggest remaining watch items are still formal versioning/releases and broader discovery/marketplace patterns.

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

- **Latest Release**: 2.1.140 (May 12, 2026)
- Recent headline movement: Agent View (research preview) landed in 2.1.139, along with `/goal`, `/scroll-speed`, and richer plugin details.
- 2.1.140 focused on reliability: better background-session behavior, Windows fixes, hook-related `/goal` fixes, and stronger plugin warnings.
- Net: Claude Code is still moving very quickly, with both new agent UX and frequent stability improvements.

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

- **Latest Stable**: v0.41.0 (May 5, 2026)
- **Release Cadence**: Weekly stable, preview, and nightly channels
- **Direction**: Rapid feature growth around voice, security, context management, and local model support

### Latest Movement (2026-05-12)

- Real-time Voice Mode is now in stable.
- Security posture tightened with workspace trust enforcement and safer `.env` loading.
- Context handling improved with the new `ContextManager`, `AgentChatHistory`, and auto-memory persistence.
- Experimental Gemma 4 support shows the CLI is continuing to broaden beyond hosted Gemini-only workflows.

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

### Latest Movement (2026-05-12)

- Official Ollama surfaces now prominently feature newer tool-capable families beyond the older qwen2.5-coder generation: `qwen3`, `qwen3.5`, `gemma4`, `gpt-oss`, and `deepseek-r1`.
- Ollama's January 2026 Codex post is an important signal that local coding/agent workflows are now a first-class use case.
- Practical takeaway: the recommendation set for a 32GB RTX 5090 has moved forward, and this watch item should increasingly track qwen3/qwen3.5-, gemma4-, and gpt-oss-class models.

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

### Latest Movement (2026-05-12)

- There is still no clear public shipment of the deeper "smarter Siri" / Apple Intelligence Siri experience this watch item is waiting for.
- Reputable reporting continues to frame the major Siri overhaul as delayed, with WWDC 2026 now the next big checkpoint.
- Net: roadmap pressure and reporting have moved, but shipped Siri capability has not materially advanced yet.

---

## GitHub Copilot Preview Bill Rollout

- **Status**: Active
- **Added**: 2026-05-12
- **Expires**: 2026-06-01
- **Notes**: Tracking the rollout of the "Preview my bill" / billing preview experience for GitHub Copilot Business and Enterprise customers ahead of the June 1, 2026 usage-based billing transition. Updated on 2026-05-12: GitHub now documents a "Preview your usage" flow, April usage reports are available, and the public billing preview tool is live, but older "preview bill" / "coming weeks" language still exists in Community posts.

### Key Resources to Monitor

| Resource | URL | What to Watch |
|----------|-----|---------------|
| **GitHub Docs (orgs/enterprises)** | <https://docs.github.com/en/copilot/how-tos/manage-and-track-spending/prepare-for-usage-based-billing> | Whether wording changes from "coming in early May" to confirmed availability |
| **GitHub Blog announcement** | <https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/> | Revised rollout timing or explicit availability confirmation |
| **GitHub Community FAQ #192948** | <https://github.com/orgs/community/discussions/192948> | Staff replies, ETA changes, and rollout clarifications |
| **GitHub Changelog** | <https://github.blog/changelog/> | New posts mentioning billing preview rollout |
| **Billing preview tool** | <https://copilot-billing-preview.github.com/> | Whether the public estimator remains available and how the flow evolves |
| **r/GithubCopilot** | <https://www.reddit.com/r/GithubCopilot/> | User reports of availability, delays, or Enterprise-only access |
| **X: @github** | <https://x.com/github> | Official social updates on the billing preview rollout |

### Current Signals

- As of May 12, the org/admin docs no longer say "coming in early May"; they now direct admins to click **Preview your usage** and request the April usage report.
- GitHub's May 12 changelog says **"Starting today, you can download your usage report"** for Copilot Business and Enterprise admins.
- The public billing preview tool is live at `copilot-billing-preview.github.com`.
- The main GitHub Community FAQ still contains older wording that says the preview bill is rolling out **"in the coming weeks,"** so the public messaging remains historically inconsistent.
- Community reports from earlier on May 12 were conflicting: some users said it was still unavailable, some claimed Enterprise-only access, and at least one reported Enterprise admins still could not find the older in-product experience.

### What is AIC?

**AIC = GitHub AI Credits** — the new billing currency replacing Premium Request Units (PRUs).

| Detail | Value |
|--------|-------|
| **1 AIC** | $0.01 USD |
| **Copilot Pro** | 1,000 AIC/month ($10) |
| **Copilot Pro+** | 3,900 AIC/month ($39) |
| **Copilot Business** | 1,900 AIC/user/month ($19) |
| **Copilot Enterprise** | 3,900 AIC/user/month ($39) |

- Credits are consumed based on **token usage** (input, output, cached) and which **model** is used.
- **Not billed**: Code completions and Next Edit suggestions remain unlimited.
- **Billed**: Chat, CLI, cloud agents, Spaces, Spark, code review, third-party agents.
- Business/Enterprise credits are **pooled** at the org level.
- June–August 2026: promotional higher credit pools for Business/Enterprise.

### Latest Update (2026-05-13)

- The billing preview tool is live and April usage reports are downloadable for Business and Enterprise admins.
- GitHub has shifted terminology from "Preview my bill" to a **usage report + billing preview tool** workflow.
- The June 1, 2026 transition date remains firm — **18 days away**.
- Fallback mode (dropping to cheaper models when credits run out) has been **removed** — usage is strictly governed by credit budget.
- Copilot Code Review now consumes both GitHub Actions minutes **and** AI credits.
- Key concern in community: heavy agentic/long-running workflows will burn through credits much faster than the old flat-rate PRU model.

### Resolution Criteria

- [x] GitHub confirms general availability or publishes revised timing
- [x] Verified access for Copilot Business admins
- [x] Verified access for Copilot Enterprise admins
- [ ] Clear resolution before the June 1, 2026 billing transition
