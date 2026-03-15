---
name: chrome
description: >-
  V1.1 - Commands: debug, connect, inspect, lighthouse, trace.
  Expert in Chrome DevTools Protocol debugging via MCP server for browser automation,
  performance tracing, network inspection, Lighthouse audits, and DOM interaction.
  Also works with Electron apps (renderer process) via --browserUrl.
  Use when debugging web apps, Electron apps, running browser automation, taking screenshots,
  inspecting network traffic, or profiling performance in Chrome.
---

# Chrome DevTools

**Default behavior**: When user activates this skill without specifying an action, check if Chrome is running
with DevTools Protocol enabled and report connection status.

## Prerequisites

| Requirement | How to Verify | Install |
|---|---|---|
| Chrome 144+ | `(Get-Item "C:\Program Files\Google\Chrome\Application\chrome.exe").VersionInfo.ProductVersion` | [Download](https://www.google.com/chrome/) |
| Node.js / npx | `npx --version` | [Download](https://nodejs.org/) |
| Chrome DevTools MCP | `npx chrome-devtools-mcp@latest --version` | Auto-installed via npx |

## VS Code MCP Configuration

The Chrome DevTools MCP servers are configured in `.vscode/mcp.json`:

```json
{
  "servers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--autoConnect"]
    },
    "chrome-devtools-slim": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--autoConnect", "--slim"]
    }
  }
}
```

| Server | Tools | Use Case |
|---|---|---|
| `chrome-devtools` | All 29 | Full debugging, performance, network, Lighthouse |
| `chrome-devtools-slim` | 3 only | Quick navigate + script + screenshot (low tokens) |

## Connection Methods

### Step 1: Determine How Chrome Is Running

| Chrome State | Connection Method | MCP Flag |
|---|---|---|
| Running normally (Chrome 144+) | autoConnect | `--autoConnect` |
| Started with `--remote-debugging-port=PORT` | browserUrl | `--browserUrl http://127.0.0.1:PORT` |
| Have a direct WebSocket URL | wsEndpoint | `--wsEndpoint ws://...` |
| No Chrome running | Launch new instance | (no connection flag) |

### Step 2: Verify Connection

#### autoConnect (default, recommended for Chrome 144+)

autoConnect reads the `DevToolsActivePort` file automatically:

```powershell
# Check if DevToolsActivePort file exists (proves Chrome has debugging enabled)
$dap = "$env:LOCALAPPDATA\Google\Chrome\User Data\DevToolsActivePort"
if (Test-Path $dap) {
    $lines = Get-Content $dap
    Write-Host "Port: $($lines[0])"
    Write-Host "WebSocket path: $($lines[1])"
} else {
    Write-Host "DevToolsActivePort not found - Chrome may not have debugging enabled"
}
```

#### browserUrl (explicit remote debugging port)

```powershell
# Verify CDP endpoint is reachable
curl.exe -s http://127.0.0.1:9222/json/version
```

**Chrome 146+ Note**: HTTP discovery endpoints (`/json/version`, `/json/list`) return 404 when Chrome uses
auto-connect instead of `--remote-debugging-port`. This is expected. Use `autoConnect` instead.

### Step 3: Enable Chrome Debugging (if not already enabled)

**Option A - Enable auto-connect (no restart needed)**:

1. Navigate to `chrome://inspect/#remote-debugging` in Chrome
2. Enable "Discover network targets"

**Option B - Start Chrome with explicit debug port**:

```powershell
& "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222
```

## Commands

### debug (default)

Connect to Chrome and interact with the current page. Uses the MCP tools directly.

### connect

Check connection status and display Chrome DevTools Protocol info:

```powershell
# 1. Check Chrome process
$chrome = Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" |
    Where-Object { $_.CommandLine -like '*remote-debugging*' -or $_.CommandLine -like '*9222*' } |
    Select-Object ProcessId, CommandLine -First 1

# 2. Check DevToolsActivePort
$dap = "$env:LOCALAPPDATA\Google\Chrome\User Data\DevToolsActivePort"
if (Test-Path $dap) { Get-Content $dap }

# 3. Check port listener
netstat -ano | Select-String ":9222 "
```

### inspect

Take a DOM snapshot of the current page for analysis (uses `take_snapshot` MCP tool).

### lighthouse

Run a Lighthouse audit on the current page (uses `lighthouse_audit` MCP tool).

### trace

Start/stop a performance trace (uses `performance_start_trace` / `performance_stop_trace` MCP tools).

## Available MCP Tools (29 total)

### Input (9 tools)

| Tool | Description |
|---|---|
| `click` | Click an element on the page |
| `drag` | Drag from one position to another |
| `fill` | Fill a single input field |
| `fill_form` | Fill multiple form fields at once |
| `handle_dialog` | Accept or dismiss browser dialogs |
| `hover` | Hover over an element |
| `press_key` | Press a keyboard key |
| `type_text` | Type text character by character |
| `upload_file` | Upload a file to an input element |

### Navigation (6 tools)

| Tool | Description |
|---|---|
| `close_page` | Close a browser tab |
| `list_pages` | List all open tabs |
| `navigate_page` | Navigate to a URL |
| `new_page` | Open a new tab |
| `select_page` | Switch to a specific tab |
| `wait_for` | Wait for an element, text, or condition |

### Emulation (2 tools)

| Tool | Description |
|---|---|
| `emulate` | Emulate a specific device (e.g., iPhone, Pixel) |
| `resize_page` | Change viewport dimensions |

### Performance (4 tools)

| Tool | Description |
|---|---|
| `performance_start_trace` | Start recording a performance trace |
| `performance_stop_trace` | Stop recording and get trace data |
| `performance_analyze_insight` | Analyze performance insights |
| `take_memory_snapshot` | Capture heap memory snapshot |

### Network (2 tools)

| Tool | Description |
|---|---|
| `get_network_request` | Get details of a specific network request |
| `list_network_requests` | List all network requests |

### Debugging (6 tools)

| Tool | Description |
|---|---|
| `evaluate_script` | Execute JavaScript in the page context |
| `get_console_message` | Get a specific console message |
| `list_console_messages` | List all console messages |
| `lighthouse_audit` | Run a full Lighthouse audit |
| `take_screenshot` | Capture a screenshot of the page |
| `take_snapshot` | Take an accessibility/DOM snapshot |

## MCP Server Flags Reference

| Flag | Description |
|---|---|
| `--autoConnect` | Connect to running Chrome via DevToolsActivePort (Chrome 144+) |
| `--browserUrl URL` | Connect to Chrome at explicit URL |
| `--wsEndpoint URL` | Connect via direct WebSocket URL |
| `--slim` | Only 3 tools: navigate, evaluate_script, take_screenshot |
| `--headless` | Run Chrome without UI |
| `--isolated` | Use temporary user-data-dir |
| `--experimentalScreencast` | Enable video recording (requires ffmpeg) |
| `--channel stable/canary/beta/dev` | Select Chrome channel |
| `--no-category-emulation` | Disable emulation tools |
| `--no-category-performance` | Disable performance tools |
| `--no-category-network` | Disable network tools |

## Chrome 146 Behavior Changes

Chrome 146 introduced important changes to the DevTools Protocol:

1. **HTTP discovery endpoints return 404** - `/json/version`, `/json/list`, `/json/protocol` no longer work
   when Chrome uses auto-connect (enabled via `chrome://inspect/#remote-debugging`)
2. **WebSocket-only CDP** - Chrome now only exposes the WebSocket endpoint for CDP communication
3. **DevToolsActivePort file** - Located at `%LOCALAPPDATA%\Google\Chrome\User Data\DevToolsActivePort`,
   contains the port (line 1) and WebSocket path (line 2)
4. **autoConnect is the recommended method** - Reads DevToolsActivePort directly, no URL needed

## Troubleshooting

### "DevToolsActivePort not found"

**Cause**: Chrome is not running or debugging is not enabled.

**Solution**:

1. Open Chrome
2. Navigate to `chrome://inspect/#remote-debugging`
3. Enable "Discover network targets"
4. Verify: `Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\DevToolsActivePort"`

### "HTTP endpoints return 404"

**Cause**: Chrome 146+ no longer serves HTTP discovery endpoints with auto-connect.

**Solution**: Use `--autoConnect` flag instead of `--browserUrl`. This is expected behavior.

### "Connection refused on port 9222"

**Cause**: Chrome is not listening on that port.

**Solution**: Check `netstat -ano | Select-String ":9222 "` and verify Chrome is running with debugging.

### "MCP tools not available in VS Code"

**Cause**: MCP server not started or not configured.

**Solution**:

1. Verify `.vscode/mcp.json` contains the chrome-devtools server config
2. Restart VS Code to pick up MCP config changes
3. Check that `github.copilot.chat.cli.mcp.enabled` is `true` in VS Code settings

## Electron App Debugging

Chrome DevTools MCP works with Electron apps because Electron embeds Chromium and exposes the same CDP.

### What Works vs What Doesn't

| Surface | Works with Chrome DevTools MCP? | How |
|---|---|---|
| Renderer process (UI, DOM, network) | Yes | Launch with `--remote-debugging-port`, connect via `--browserUrl` |
| Main process (Node.js, IPC) | No | Use VS Code Node debugger with `--inspect=9229` instead |

### Step 1: Launch Electron App with Debugging

```powershell
# Slack
& "$env:LOCALAPPDATA\slack\slack.exe" --remote-debugging-port=9222

# VS Code (another instance)
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe" --remote-debugging-port=9223

# Discord
& "$env:LOCALAPPDATA\Discord\Update.exe" --processStart Discord.exe --process-start-args "--remote-debugging-port=9224"
```

**Important**: Quit the app first if already running. The flag must be present at launch time.

### Step 2: Connect Chrome DevTools MCP

```powershell
# Use --browserUrl (NOT --autoConnect, which reads Chrome's DevToolsActivePort file)
npx -y chrome-devtools-mcp@latest --browserUrl http://127.0.0.1:9222
```

### Step 3: Use All 29 MCP Tools

All tools work on Electron renderer windows: `take_screenshot`, `evaluate_script`,
`list_console_messages`, `list_network_requests`, `click`, `fill`, `lighthouse_audit`,
`performance_start_trace`, etc.

### Key Difference from Chrome

| | Chrome | Electron |
|---|---|---|
| Connection | `--autoConnect` (reads DevToolsActivePort) | `--browserUrl http://127.0.0.1:PORT` |
| Launch | Already running | Must launch with `--remote-debugging-port` |
| Main process | N/A | Requires separate `--inspect` + Node debugger |
| Tab management | `list_pages` / `select_page` | Same, but Electron may have splash/hidden windows |

**See also**: The `electron` skill covers Playwright, agent-browser, WebdriverIO, and main-process debugging.

## Links

- [Chrome DevTools MCP GitHub](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [Chrome DevTools Documentation](https://developer.chrome.com/docs/devtools/)
- [Chrome DevTools Protocol Viewer](https://chromedevtools.github.io/devtools-protocol/)
- [WebMCP Proposal (March 2026)](https://developer.chrome.com/blog/webmcp-mcp-usage)
- [WebMCP Early Preview Program](https://developer.chrome.com/docs/ai/join-epp)
