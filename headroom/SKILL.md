---
name: headroom
description: "V1.0 - Commands: install, uninstall, upgrade. Expert in the trending chopratejas/headroom LLM context-compression project, including safe setup, teardown, and update workflows."
license: Apache-2.0
compatibility: Requires network access for live release/package checks; Headroom Python package requires Python 3.10+.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the headroom directory (path contains 'headroom'), verify that history logging occurred.

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
            Before stopping, if headroom was used (check if any files in headroom directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in headroom directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Headroom

Use this skill for installing, uninstalling, upgrading, and troubleshooting the
trending `chopratejas/headroom` project: an LLM context optimization layer that
compresses tool outputs, logs, files, RAG chunks, and conversation history before
they reach the model. It ships as the Python package `headroom-ai`, the npm
package `headroom-ai`, a Docker image, a proxy server, agent wrappers, and MCP
tools.

## Default Behavior

When activated without a command, identify the user's target environment, then
recommend the safest install path without changing anything. Prefer MCP-only or
manual proxy configuration for Codex Desktop until the current Codex provider
injection issue is resolved upstream.

## MCP Tool Usage When Asked

When the user asks to use Headroom, Headroom MCP, compression, token headroom, or
context compression in the active task, do not stop at reading this skill. Make a
best-effort attempt to use the actual MCP tools:

1. If `mcp__headroom` tools are not already visible, discover them with
   `tool_search` using a query such as `headroom compress retrieve stats MCP`.
2. Use `mcp__headroom.headroom_compress` before reasoning over large payloads:
   long command output, logs, stack traces, JSON/API responses, broad search
   results, generated reports, or research bundles.
3. Keep the returned hash in notes or the response so the original can be
   retrieved later.
4. Use `mcp__headroom.headroom_retrieve` when exact original details are needed
   from compressed content.
5. Use `mcp__headroom.headroom_stats` near closeout for substantive sessions
   where Headroom was used, and report compressions/retrievals/tokens saved.

If the MCP tools are unavailable, say that clearly and fall back to normal
summarization or other available compression tools. Do not claim Headroom was
used unless a Headroom MCP tool, proxy, wrapper, SDK, or CLI command actually ran.

## Repository Target

Default to `chopratejas/headroom`.

Disambiguate only when the user clearly means another project:

| Repo | Use When |
| --- | --- |
| `chopratejas/headroom` | LLM token/context compression, proxy, MCP, Claude/Codex/Cursor wrapping |
| `M-Igashi/headroom` | Audio loudness analyzer and mastering gain adjustment |
| `gglucass/headroom-desktop` | macOS menu-bar app for Claude Code usage/headroom |

## Always Refresh First

Headroom is moving quickly. Before giving exact commands, run live checks:

```powershell
$repo = Invoke-RestMethod -Uri 'https://api.github.com/repos/chopratejas/headroom' -Headers @{ 'User-Agent' = 'codex-headroom-skill' }
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/chopratejas/headroom/releases/latest' -Headers @{ 'User-Agent' = 'codex-headroom-skill' }
$pypi = Invoke-RestMethod -Uri 'https://pypi.org/pypi/headroom-ai/json' -Headers @{ 'User-Agent' = 'codex-headroom-skill' }
npm view headroom-ai name version description dist-tags.latest --json
```

Report the live GitHub release, PyPI version, npm version, platform, and package
manager before recommending install or upgrade.

Current snapshot from 2026-06-16:

| Source | Value |
| --- | --- |
| GitHub repo | `chopratejas/headroom` |
| Latest GitHub release | `v0.25.0` |
| PyPI package | `headroom-ai` `0.25.0`, Python `>=3.10` |
| npm package | `headroom-ai` `0.22.4`, Node.js `18+` |
| Docker image | `ghcr.io/chopratejas/headroom:latest` |
| License | Apache-2.0 |

## Commands

| Command | Use When | Outcome |
| --- | --- | --- |
| `install` | User wants Headroom added to a machine, app, agent, or shell | Choose Python, npm, Docker, proxy, MCP, or wrapper setup |
| `uninstall` | User wants Headroom removed or reverted | Remove wrappers/MCP/proxy supervisor first, then packages |
| `upgrade` | User wants latest Headroom or a broken install repaired | Check live release/package state, upgrade the chosen channel, verify CLI/proxy/MCP |

## Command: install

### Choose Install Path

| Target | Preferred Command | Notes |
| --- | --- | --- |
| Python core SDK | `pip install headroom-ai` | Includes `compress()`, SmartCrusher, CacheAligner, and IntelligentContext |
| Python proxy and MCP | `pip install "headroom-ai[proxy,mcp]"` | Best general local setup for agents and HTTP proxy |
| Full Python package | `pip install "headroom-ai[all]"` | Heaviest install; use only when user needs all integrations |
| uv tool | `uv tool install "headroom-ai[proxy,mcp]"` | Good CLI isolation when Python tooling is already available |
| TypeScript SDK | `npm install headroom-ai` | Requires a running Python Headroom proxy |
| Docker proxy | `docker run -p 8787:8787 ghcr.io/chopratejas/headroom:latest` | Good disposable proxy path |
| MCP server | `headroom mcp install` | Native Claude Code registration; other MCP hosts can point to `headroom mcp serve` |
| Agent wrapper | `headroom wrap claude`, `headroom wrap codex`, `headroom wrap cursor` | Powerful but changes agent configuration; inspect config diffs first |

### Verify Install

```powershell
headroom --help
python -c "import headroom; print(headroom.__version__)"
headroom mcp status
```

For proxy mode:

```powershell
headroom proxy --port 8787
curl http://localhost:8787/health
curl http://localhost:8787/stats
```

For TypeScript:

```powershell
node -e "const h = require('headroom-ai'); console.log('headroom-ai loaded')"
```

### Codex-Specific Caution

As of 2026-06-16, upstream issue `#961` reports that installing Headroom for
Codex can inject `model_provider = "headroom"` into `~/.codex/config.toml`,
which may hide existing Codex Desktop chat/thread history by provider filtering.
The data is reported as not deleted, but the UI can appear to lose history.

Safer Codex guidance:

1. Prefer MCP-only setup when possible:

   ```toml
   [mcp_servers.headroom]
   command = "headroom"
   args = ["mcp", "serve"]
   ```

2. If testing wrapper/proxy mode, back up `~/.codex/config.toml` first.
3. Inspect config changes before restarting Codex Desktop.
4. Keep `headroom unwrap codex --no-stop-proxy` available as the first revert.

### Windows-Specific Caution

As of PyPI `0.25.0`, live package metadata showed macOS and Linux wheels plus an
sdist, but no `win_amd64` wheel. On Windows, install or upgrade may compile from
source and require Rust plus MSVC C/C++ build tools. If the user wants a low-risk
Windows setup, prefer Docker or wait for a Windows wheel unless they accept the
toolchain cost.

## Command: uninstall

There is not yet a single stable top-level `headroom uninstall` command. Upstream
issue `#748` tracks that gap. Teardown is currently channel-specific.

### Teardown Order

1. Stop proxy processes or persistent supervisors.
2. Unwrap each modified agent.
3. Remove MCP registration.
4. Remove persistent install supervisor if used.
5. Uninstall Python/npm packages.
6. Inspect user config files for leftover Headroom entries.

### Common Commands

```powershell
headroom unwrap codex --no-stop-proxy
headroom unwrap claude --no-stop-proxy
headroom unwrap cursor --no-stop-proxy
headroom mcp uninstall
headroom install agent remove
pip uninstall headroom-ai
npm uninstall -g headroom-ai
uv tool uninstall headroom-ai
```

Only run commands that match what was installed. If the user is not sure, inspect
the configs first:

```powershell
headroom --help
headroom mcp status
Get-Content "$env:USERPROFILE\.codex\config.toml" -ErrorAction SilentlyContinue
Get-Content "$env:USERPROFILE\.claude.json" -ErrorAction SilentlyContinue
Get-Content "$env:CLAUDE_CONFIG_DIR\.claude.json" -ErrorAction SilentlyContinue
```

For Claude Code, check both `~/.claude.json` and
`$CLAUDE_CONFIG_DIR/.claude.json` when that environment variable is set. Upstream
issue `#872` reports cases where Headroom wrote MCP entries to the legacy config
path instead of the active Claude Code config.

## Command: upgrade

### Upgrade Procedure

1. Refresh live GitHub, PyPI, npm, and Docker metadata.
2. Record current local state:

   ```powershell
   headroom --version
   python -c "import headroom; print(headroom.__version__)"
   npm list -g headroom-ai --depth=0
   headroom mcp status
   ```

3. Upgrade the installed channel:

   ```powershell
   pip install --upgrade "headroom-ai[proxy,mcp]"
   uv tool upgrade headroom-ai
   npm install -g headroom-ai@latest
   docker pull ghcr.io/chopratejas/headroom:latest
   ```

4. Re-run verification:

   ```powershell
   headroom --help
   python -c "import headroom; print(headroom.__version__)"
   headroom mcp status
   curl http://localhost:8787/health
   ```

5. For wrapped agents, inspect config diffs after upgrade before restarting the
   agent.

### Upgrade Risk Checks

| Risk | Check |
| --- | --- |
| Windows build from source | Confirm whether PyPI now publishes a `win_amd64` wheel |
| Codex history visibility | Avoid global `model_provider = "headroom"` unless user accepts the behavior |
| Claude MCP path mismatch | Honor `CLAUDE_CONFIG_DIR` when present |
| Persistent Docker crash loop | If using `headroom install apply --preset persistent-docker`, inspect issue `#833` status first |
| Version skew | Remember npm may lag PyPI/GitHub releases |

## What Headroom Does Well

Use Headroom when token pressure comes from:

- JSON-heavy tool outputs, API responses, database rows, or structured logs.
- Build/test logs and long shell output.
- Multi-tool agent sessions with accumulated context.
- Proxying LLM traffic without changing application code.
- MCP access to `headroom_compress`, `headroom_retrieve`, and `headroom_stats`.

When the user explicitly asks for Headroom in a task, prefer the MCP tools for
large inputs before drafting or reasoning, then retrieve originals only when
exactness is needed.

Do not oversell Headroom for:

- Short chats.
- Code-only edit sessions where exact source code must remain available.
- Compact grep/search output.
- RAG document contexts that Headroom currently passes through.

## Key Commands

```powershell
headroom proxy --port 8787
headroom proxy --no-optimize
headroom proxy --log-level debug
headroom wrap claude
headroom wrap codex
headroom wrap cursor
headroom mcp install
headroom mcp status
headroom mcp serve --debug
headroom mcp uninstall
```

## Sources

- GitHub: <https://github.com/chopratejas/headroom>
- Docs index: <https://headroom-docs.vercel.app/llms.txt>
- Installation docs: <https://headroom-docs.vercel.app/docs/installation>
- Quickstart docs: <https://headroom-docs.vercel.app/docs/quickstart>
- Proxy docs: <https://headroom-docs.vercel.app/docs/proxy>
- MCP docs: <https://headroom-docs.vercel.app/docs/mcp>
- Limitations docs: <https://headroom-docs.vercel.app/docs/limitations>
- PyPI: <https://pypi.org/project/headroom-ai/>
- npm: <https://www.npmjs.com/package/headroom-ai>
- Uninstall tracking issue: <https://github.com/chopratejas/headroom/issues/748>
- Codex provider issue: <https://github.com/chopratejas/headroom/issues/961>
- Windows wheel issue: <https://github.com/chopratejas/headroom/issues/974>
- Persistent Docker issue: <https://github.com/chopratejas/headroom/issues/833>
- Claude config path issue: <https://github.com/chopratejas/headroom/issues/872>
