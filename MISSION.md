# Mission: Executable GitHub Copilot CLI extensions

## Why

Build Copilot CLI extensions that participate in a live agent session, rather than repackaging skills and MCP servers Franz already knows. Use the Canvas model as the comparison point so each idea lands in the right Copilot host.

## Success looks like

- Explain the difference between a plugin, a CLI extension, and a Canvas extension.
- Build and reload a project extension that observes session events and keeps session state.
- Add a native tool, slash command, and permission-aware terminal form.
- Decide when a workflow needs the CLI TUI and when it needs the Copilot app Canvas.

## Constraints

- Use current GitHub documentation because CLI extensions are experimental and their contract can change.
- Target Windows and PowerShell for all hands-on commands.
- Keep lessons short and end each one with retrieval practice or a working artifact.
- Verify the installed Copilot CLI from Franz's normal profile before the first hands-on build. The current automation shell does not resolve `copilot` from `PATH`.

## Out of scope

- Re-teaching skills, MCP servers, or basic plugin packaging.
- Building a standalone application around the full Copilot SDK unless a CLI extension cannot meet the goal.
- Treating terminal dialogs as equivalent to a free-form Canvas interface.
