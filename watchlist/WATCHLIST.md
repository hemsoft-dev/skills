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
| **Claude Code CHANGELOG**    | <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>             | Track Claude Code release notes and updates           |

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
