---
name: electron
description: V1.0 - Debug and automate Electron desktop apps with Playwright and CDP-attached tools such as agent-browser. Use when the user needs to interact with an Electron app, automate a desktop app, connect to a running app, control a native app, test an Electron application, or choose between Playwright, CDP, and WebDriver-based approaches for Electron.
---

# Electron App Automation And Debugging

Use this skill for Electron automation and debugging, especially when an AI agent or GitHub Copilot should drive the investigation.

Core rule: Electron debugging has two separate surfaces.

- Main process: Node/V8 debugging via `--inspect` or `--inspect-brk`
- Renderer process: Chromium debugging via DevTools or `--remote-debugging-port`

Most Electron debugging failures come from mixing those two surfaces. Playwright and CDP-attached tools are best for renderer and UI debugging. They do not replace Node inspector debugging for the Electron main process.

Official guidance to keep in mind:

- Electron officially documents Playwright and WebdriverIO as the modern Spectron replacements
- Spectron is deprecated
- Playwright has experimental Electron support
- Playwright's `connectOverCDP` works for existing Chromium targets, but is lower fidelity than native Playwright protocol control

## Best Use Cases

| Scenario | Best Tool | Why |
| --- | --- | --- |
| You can launch the Electron app from source | Playwright `_electron.launch` | Best debugging fidelity for Electron windows plus limited main-process evaluation |
| You need to drive an already-installed or packaged Electron app | `agent-browser` or Playwright via CDP | Easy renderer attachment through `--remote-debugging-port` |
| You need Node breakpoints in the Electron main process | VS Code Node debugger | Playwright is not a replacement for `--inspect` |
| You need broader packaged-app E2E coverage with WebDriver-style tooling | WebdriverIO | Electron officially documents it as an alternative |

## Recommended Decision Order

1. If you own the app source and can launch it directly, prefer Playwright `_electron.launch`.
2. If the app is packaged or already installed, prefer CDP attach with `--remote-debugging-port`.
3. If you need main-process breakpoints, use the Node debugger separately with `--inspect`.

## Core Workflow

1. Launch the Electron app with the correct debugging surface enabled
2. Connect the debugging tool
3. Capture state with snapshots, console, network, or traces
4. Reproduce the issue
5. Save evidence with screenshots, traces, and logs

## Playwright First: Source-Based Apps

If you can start the Electron app from source, Playwright is usually the best option.

```ts
import { test, _electron as electron, expect } from '@playwright/test';

test('debug electron ui flow', async () => {
	const electronApp = await electron.launch({ args: ['.'] });

	electronApp.on('console', async message => {
		const values = [];
		for (const arg of message.args()) {
			values.push(await arg.jsonValue());
		}
		console.log('[main]', ...values);
	});

	const window = await electronApp.firstWindow();

	window.on('console', message => {
		console.log('[renderer]', message.text());
	});

	window.on('pageerror', error => {
		console.log('[renderer-error]', error.message);
	});

	await window.screenshot({ path: 'electron-debug.png' });
	await electronApp.close();
});
```

Use this route when you want:

- Playwright Inspector with `--debug`
- `page.pause()` while stepping through a flow
- trace capture and Trace Viewer
- screenshots, video, HAR, and console capture
- limited access to Electron main-process state through `electronApp.evaluate()`

This is the strongest option when Copilot should help reproduce a UI bug, inspect locators, capture traces, and iterate on a test harness.

## CDP Attach: Packaged Or Installed Apps

If the app is already installed or you only have a packaged executable, use CDP attach. This is usually the best agent-driven workflow for desktop Electron apps.

```bash
# Launch an Electron app with remote debugging
"C:\Users\%USERNAME%\AppData\Local\slack\slack.exe" --remote-debugging-port=9222

# Connect agent-browser to the app
agent-browser connect 9222

# Standard workflow from here
agent-browser snapshot -i
agent-browser click @e5
agent-browser screenshot slack-desktop.png
```

Why this works well for AI-driven debugging:

- `snapshot -i` gives deterministic refs the agent can act on
- `console`, `errors`, `network requests`, `trace start`, and `trace stop` create usable debugging artifacts
- the workflow is optimized for repeated inspect-act-inspect loops

## Main-Process Debugging

Use Node debugging when the bug lives in Electron startup, IPC wiring, native integrations, or other main-process code.

```bash
electron . --inspect=9229
electron . --inspect-brk=9229
```

Use this with the VS Code Node debugger. Do not expect Playwright or CDP-attached browser tools to replace main-process breakpoints.

## Launching Electron Apps with CDP

Every Electron app exposes Chromium renderer debugging through `--remote-debugging-port` because Electron embeds Chromium.

### macOS

```bash
# Slack
open -a "Slack" --args --remote-debugging-port=9222

# VS Code
open -a "Visual Studio Code" --args --remote-debugging-port=9223

# Discord
open -a "Discord" --args --remote-debugging-port=9224

# Figma
open -a "Figma" --args --remote-debugging-port=9225

# Notion
open -a "Notion" --args --remote-debugging-port=9226

# Spotify
open -a "Spotify" --args --remote-debugging-port=9227
```

### Linux

```bash
slack --remote-debugging-port=9222
code --remote-debugging-port=9223
discord --remote-debugging-port=9224
```

### Windows

```bash
"C:\Users\%USERNAME%\AppData\Local\slack\slack.exe" --remote-debugging-port=9222
"C:\Users\%USERNAME%\AppData\Local\Programs\Microsoft VS Code\Code.exe" --remote-debugging-port=9223
"C:\Users\%USERNAME%\AppData\Local\Discord\Update.exe" --processStart Discord.exe --process-start-args "--remote-debugging-port=9224"
```

**Important:** If the app is already running, quit it first, then relaunch with the flag. The `--remote-debugging-port` flag must be present at launch time.

For packaged apps, launch-time flags matter more than post-launch tricks.

## Connecting

```bash
# Connect to a specific port
agent-browser connect 9222

# Or use --cdp on each command
agent-browser --cdp 9222 snapshot -i

# Auto-discover a running Chromium-based app
agent-browser --auto-connect snapshot -i
```

After `connect`, all subsequent commands target the connected app without needing `--cdp`.

### Playwright Over CDP

If you need to attach Playwright to an already running Chromium target, CDP is possible, but lower fidelity than native Playwright protocol control.

```ts
import { chromium } from 'playwright';

const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
const context = browser.contexts()[0];
const page = context.pages()[0];
```

Use this when native `_electron.launch` is not available, not as the first choice for source-based apps.

## Tab Management

Electron apps often have multiple windows or webviews. Use tab commands to list and switch between them:

```bash
# List all available targets (windows, webviews, etc.)
agent-browser tab

# Switch to a specific tab by index
agent-browser tab 2

# Switch by URL pattern
agent-browser tab --url "*settings*"
```

This matters for Electron more than normal browser automation because many apps create splash windows, hidden windows, settings windows, and separate webviews.

## Debugging Artifacts

Prefer artifacts over ad hoc guessing.

### With Playwright

- Run with `npx playwright test --debug`
- Use `await page.pause()` to stop at the interesting moment
- Use Playwright Inspector for locator debugging
- Use Trace Viewer to inspect DOM snapshots, console, network, source location, and actionability logs

### With agent-browser

```bash
agent-browser connect 9222
agent-browser console
agent-browser errors
agent-browser network requests
agent-browser trace start electron-trace.zip
agent-browser screenshot --annotate electron-ui.png
agent-browser trace stop electron-trace.zip
```

These artifacts are the fastest way to let an AI agent or Copilot reason about what happened.

## Common Patterns

### Inspect and Navigate an App

```bash
open -a "Slack" --args --remote-debugging-port=9222
sleep 3  # Wait for app to start
agent-browser connect 9222
agent-browser snapshot -i
# Read the snapshot output to identify UI elements
agent-browser click @e10  # Navigate to a section
agent-browser snapshot -i  # Re-snapshot after navigation
```

### Reproduce A Renderer Bug For Copilot

```bash
"C:\Users\%USERNAME%\AppData\Local\Programs\Microsoft VS Code\Code.exe" --remote-debugging-port=9223
agent-browser connect 9223
agent-browser snapshot -i
agent-browser console
agent-browser errors
agent-browser screenshot --annotate vscode-ui.png
```

This workflow is ideal when Copilot should identify the visible UI, interact with it, and capture evidence.

### Take Screenshots of Desktop Apps

```bash
agent-browser connect 9222
agent-browser screenshot app-state.png
agent-browser screenshot --full full-app.png
agent-browser screenshot --annotate annotated-app.png
```

### Extract Data from a Desktop App

```bash
agent-browser connect 9222
agent-browser snapshot -i
agent-browser get text @e5
agent-browser snapshot --json > app-state.json
```

### Fill Forms in Desktop Apps

```bash
agent-browser connect 9222
agent-browser snapshot -i
agent-browser fill @e3 "search query"
agent-browser press Enter
agent-browser wait 1000
agent-browser snapshot -i
```

### Inspect Main-Process State With Playwright

```ts
const isPackaged = await electronApp.evaluate(async ({ app }) => {
	return app.isPackaged;
});

const appPath = await electronApp.evaluate(async ({ app }) => {
	return app.getAppPath();
});
```

This is useful for diagnostics, but it is not the same as step-debugging the main process.

### Run Multiple Apps Simultaneously

Use named sessions to control multiple Electron apps at the same time:

```bash
# Connect to Slack
agent-browser --session slack connect 9222

# Connect to VS Code
agent-browser --session vscode connect 9223

# Interact with each independently
agent-browser --session slack snapshot -i
agent-browser --session vscode snapshot -i
```

## Color Scheme

Playwright overrides the color scheme to `light` by default when connecting via CDP. To preserve dark mode:

```bash
agent-browser connect 9222
agent-browser --color-scheme dark snapshot -i
```

Or set it globally:

```bash
AGENT_BROWSER_COLOR_SCHEME=dark agent-browser connect 9222
```

## WebdriverIO

Electron officially documents WebdriverIO as another supported path. Prefer it when the project already uses WebDriver-style automation or when packaged-app coverage matters more than Playwright-style debugging ergonomics.

Do not pick WebdriverIO by default when the goal is "let Copilot drive the investigation". Playwright or CDP-attached agent-browser is usually the better fit for that workflow.

## Troubleshooting

### "Connection refused" or "Cannot connect"

- Make sure the app was launched with `--remote-debugging-port=NNNN`
- If the app was already running, quit and relaunch with the flag
- Check that the port isn't in use by another process: `lsof -i :9222`

On Windows, use a port check such as:

```powershell
Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue
```

### App launches but connect fails

- Wait a few seconds after launch before connecting (`sleep 3`)
- Some apps take time to initialize their webview
- Some packaged apps sanitize startup behavior; always relaunch from a fresh process with the flag present

### Playwright Electron launch times out

- Check whether Electron fuses disable Node CLI inspect arguments
- Prefer CDP attach for packaged applications if `_electron.launch` is unreliable

### Elements not appearing in snapshot

- The app may use multiple webviews. Use `agent-browser tab` to list targets and switch to the right one
- Use `agent-browser snapshot -i -C` to include cursor-interactive elements (divs with onclick handlers)

### Cannot type in input fields

- Try `agent-browser keyboard type "text"` to type at the current focus without a selector
- Some Electron apps use custom input components; use `agent-browser keyboard inserttext "text"` to bypass key events

### The issue is in app startup, IPC, or native integration

- Stop using renderer tooling and switch to Node main-process debugging with `--inspect`
- Playwright and CDP tools are the wrong layer for that class of bug

## Supported Apps

Any app built on Electron works, including:

- **Communication:** Slack, Discord, Microsoft Teams, Signal, Telegram Desktop
- **Development:** VS Code, GitHub Desktop, Postman, Insomnia
- **Design:** Figma, Notion, Obsidian
- **Media:** Spotify, Tidal
- **Productivity:** Todoist, Linear, 1Password

If an app is built with Electron, it supports `--remote-debugging-port` and can be automated with agent-browser.

## Summary

Use Playwright `_electron.launch` when you can start the app from source. Use CDP attach for packaged or installed apps. Use Node inspector separately for the Electron main process. That split is the key to making Electron debugging work reliably.
