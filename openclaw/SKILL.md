---
name: openclaw
description: V1.0 - Expert in OpenClaw personal AI assistant setup, configuration, channels, operations, troubleshooting, and continuous management. Use when installing, configuring, updating, or operating OpenClaw.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the openclaw directory (path contains 'openclaw'), verify that history logging occurred.

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
            Before stopping, if openclaw was used (check if any files in openclaw directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in openclaw directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# OpenClaw

Expert in the [OpenClaw](https://github.com/openclaw/openclaw) personal AI assistant — setup, configuration, channels, operations, and troubleshooting.

**Default action**: When activated without a specific request, show current installation status (`openclaw --version`, `openclaw gateway status`) and offer common next steps.

## Key Resources

| Resource | URL |
|---|---|
| GitHub | <https://github.com/openclaw/openclaw> |
| Docs | <https://docs.openclaw.ai/> |
| Getting Started | <https://docs.openclaw.ai/start/getting-started> |
| Configuration | <https://docs.openclaw.ai/gateway/configuration> |
| Config Reference | <https://docs.openclaw.ai/gateway/configuration-reference> |
| Channels | <https://docs.openclaw.ai/channels> |
| Security | <https://docs.openclaw.ai/gateway/security> |
| Troubleshooting | <https://docs.openclaw.ai/channels/troubleshooting> |
| Discord | <https://discord.gg/clawd> |
| ClawHub (Skills) | <https://clawhub.com/> |

## Prerequisites

- **Node.js ≥ 22** (check: `node --version`)
- **pnpm** (recommended for building from source)
- **Windows**: WSL2 strongly recommended

## Installation

### Recommended (npm global)

```powershell
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

### macOS/Linux (install script)

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

### From Source (development)

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install
pnpm ui:build
pnpm build
pnpm openclaw onboard --install-daemon
```

### Dev Loop

```bash
pnpm gateway:watch   # auto-reload on TS changes
```

## Onboarding Wizard

The wizard is the recommended setup path. It configures auth, gateway, channels, and skills interactively.

```bash
openclaw onboard --install-daemon
```

The `--install-daemon` flag installs the Gateway as a launchd/systemd user service so it stays running.

## Configuration

Config file: `~/.openclaw/openclaw.json` (JSON5 format, optional — safe defaults if missing).

### Minimal Config

```json5
{
  agent: {
    model: "anthropic/claude-opus-4-6",
  },
}
```

### Editing Config

| Method | Command |
|---|---|
| Full wizard | `openclaw onboard` |
| Config wizard | `openclaw configure` |
| Control UI | `openclaw dashboard` |
| Direct edit | `~/.openclaw/openclaw.json` |

### Environment Variables

OpenClaw reads env vars from `~/.openclaw/.env` (global) and `.env` (cwd). Inline env vars in config:

```json5
{
  env: {
    OPENROUTER_API_KEY: "sk-or-...",
    vars: { GROQ_API_KEY: "gsk-..." },
  },
}
```

| Variable | Purpose |
|---|---|
| `OPENCLAW_HOME` | Override home directory |
| `OPENCLAW_STATE_DIR` | Override state directory |
| `OPENCLAW_CONFIG_PATH` | Override config file path |

### Config Hot Reload

The Gateway watches `~/.openclaw/openclaw.json` and applies changes automatically.

| Mode | Behavior |
|---|---|
| `hybrid` (default) | Hot-applies safe changes; auto-restarts for critical ones |
| `hot` | Hot-applies safe changes only; logs warning for restart-needed |
| `restart` | Restarts Gateway on any config change |
| `off` | Manual restart required |

**Hot-applies without restart**: channels, agent, models, routing, hooks, cron, sessions, tools, browser, skills, UI, logging.

**Requires restart**: `gateway.*` (port, bind, auth, TLS), discovery, plugins.

### Strict Validation

OpenClaw rejects invalid config and refuses to start. Run `openclaw doctor` to diagnose, `openclaw doctor --fix` to auto-repair.

## Channels

OpenClaw supports multi-channel messaging:

| Channel | Key Config |
|---|---|
| WhatsApp | `channels.whatsapp.allowFrom` — uses Baileys |
| Telegram | `TELEGRAM_BOT_TOKEN` or `channels.telegram.botToken` |
| Slack | "Open Bot" installed — see [Slack Setup](#slack-setup) |
| Discord | `DISCORD_BOT_TOKEN` or `channels.discord.token` |
| Signal | `signal-cli` + `channels.signal` |
| BlueBubbles (iMessage) | `channels.bluebubbles.serverUrl` + `.password` |
| iMessage (legacy) | macOS-only via `imsg` |
| Microsoft Teams | Bot Framework + `msteams` config |
| Google Chat | Chat API integration |
| Matrix | Extension channel |
| Zalo / Zalo Personal | Extension channels |
| WebChat | Built-in via Gateway WebSocket |

### Channel Setup

```bash
# Login to WhatsApp (QR code)
openclaw channels login

# Send a test message
openclaw message send --to +1234567890 --message "Hello from OpenClaw"
```

Docs: <https://docs.openclaw.ai/channels>

## Slack Setup

An **Open Bot** Slack app is installed in the workspace with credentials stored in two User-level environment variables:

| Variable | Token Type | Purpose |
|---|---|---|
| `SLACK_OPENCLAW_BOT_USER_OAUTH_TOKEN` | `xoxb-...` | Bot User OAuth token for the Open Bot app |
| `SLACK_OPENCLAW_USER_OAUTH_TOKEN` | `xapp-...` | App-Level token (Socket Mode) for the Open Bot app |

The `openclaw.json` config references these via env var substitution:

```json5
{
  channels: {
    slack: {
      mode: "socket",
      enabled: true,
      botToken: "${SLACK_OPENCLAW_BOT_USER_OAUTH_TOKEN}",
      appToken: "${SLACK_OPENCLAW_USER_OAUTH_TOKEN}",
      userTokenReadOnly: true,
      groupPolicy: "allowlist",
      channels: {
        "#pe-bot-test": { allow: true },
      },
    },
  },
}
```

**Current setup**: Socket mode, allowlisted to `#pe-bot-test` channel.

**Known log warning** (non-fatal): `channel resolve failed; using config entries. Error: An API error occurred: missing_scope` — this is normal when channels are explicitly listed in config. OpenClaw falls back to config entries for channel resolution. The Slack connection works fine despite this message.

## Security

### DM Pairing (default)

Unknown senders receive a pairing code. Approve with:

```bash
openclaw pairing approve <channel> <code>
```

Set `dmPolicy="open"` + `allowFrom: ["*"]` for public access (not recommended).

### Sandboxing

Run non-main sessions in Docker sandboxes:

```json5
{
  agents: {
    defaults: {
      sandbox: { mode: "non-main" },
    },
  },
}
```

Run `openclaw doctor` to surface risky DM policies.

## Continuous Operation

### Gateway Management

| Command | Purpose |
|---|---|
| `openclaw gateway status` | Check if running |
| `openclaw gateway --port 18789 --verbose` | Run in foreground |
| `openclaw dashboard` | Open Control UI |
| `openclaw doctor` | Diagnose issues |
| `openclaw doctor --fix` | Auto-repair config |
| `openclaw health` | Health check |
| `openclaw logs` | View logs |
| `openclaw status` | Status overview |

### Updating

```bash
openclaw update --channel stable|beta|dev
```

After updating, always run `openclaw doctor` to apply migrations.

Docs: <https://docs.openclaw.ai/install/updating>

### Development Channels

| Channel | Description |
|---|---|
| `stable` | Tagged releases (`vYYYY.M.D`), npm `latest` |
| `beta` | Prereleases (`vYYYY.M.D-beta.N`), npm `beta` |
| `dev` | Head of `main`, npm `dev` |

### Chat Commands

Send in any connected channel (group commands are owner-only):

| Command | Action |
|---|---|
| `/status` | Session status (model + tokens) |
| `/new` or `/reset` | Reset session |
| `/compact` | Compact session context |
| `/think <level>` | off/minimal/low/medium/high/xhigh |
| `/verbose on\|off` | Toggle verbosity |
| `/usage off\|tokens\|full` | Per-response usage footer |
| `/restart` | Restart gateway (owner-only) |
| `/activation mention\|always` | Group activation toggle |

## Advanced Features

### Multi-Agent Routing

Route channels/accounts to isolated agents with separate workspaces and sessions.

Docs: <https://docs.openclaw.ai/gateway/configuration>

### Agent-to-Agent (sessions tools)

| Tool | Purpose |
|---|---|
| `sessions_list` | Discover active sessions |
| `sessions_history` | Fetch session transcript |
| `sessions_send` | Message another session |

### Tailscale Integration

Auto-configure HTTPS access to Gateway dashboard:

| Mode | Access |
|---|---|
| `off` | No Tailscale (default) |
| `serve` | Tailnet-only HTTPS |
| `funnel` | Public HTTPS (requires password auth) |

### Remote Gateway

Run Gateway on Linux, connect clients over Tailscale or SSH tunnels. Exec runs where Gateway lives; device actions run on device nodes.

### Skills & Workspace

- Workspace root: `~/.openclaw/workspace`
- Injected prompts: `AGENTS.md`, `SOUL.md`, `TOOLS.md`
- Skills: `~/.openclaw/workspace/skills/<skill>/SKILL.md`
- Skills registry: [ClawHub](https://clawhub.com/)

### Companion Apps (optional)

| Platform | Features |
|---|---|
| macOS | Menu bar, Voice Wake, PTT, WebChat, debug tools |
| iOS | Canvas, Voice Wake, Talk Mode, camera, Bonjour pairing |
| Android | Canvas, Talk Mode, camera, screen recording, SMS |

### Browser Control

```json5
{
  browser: {
    enabled: true,
    color: "#FF4500",
  },
}
```

### Cron, Webhooks, Gmail

- Cron jobs: <https://docs.openclaw.ai/automation/cron-jobs>
- Webhooks: <https://docs.openclaw.ai/automation/webhook>
- Gmail Pub/Sub: <https://docs.openclaw.ai/automation/gmail-pubsub>

## Troubleshooting

| Issue | Solution |
|---|---|
| Config validation fails | `openclaw doctor --fix` |
| Gateway won't start | Check `openclaw logs`, run `openclaw doctor` |
| Channel not connecting | `openclaw channels login`, check tokens/env vars |
| DM not working | Check `dmPolicy` and `allowFrom` settings |
| Browser not launching | Verify Chrome/Chromium installed, check `browser.enabled` |
| Risky DM policies | `openclaw doctor` surfaces misconfigured policies |
| Need full diagnostics | `openclaw doctor`, `openclaw health`, `openclaw logs` |

Docs: <https://docs.openclaw.ai/channels/troubleshooting>
