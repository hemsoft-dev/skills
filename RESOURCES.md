# GitHub Copilot CLI extension resources

## Knowledge

- [Concept: "About extensions for GitHub Copilot CLI" - GitHub Docs](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-extensions)
  Defines discovery, JavaScript entry files, user and project scope, extension modes, Copilot-managed scaffolding and reloads, and the security boundary.
- [Tutorial: "Creating extensions for GitHub Copilot CLI" - GitHub Docs](https://docs.github.com/en/copilot/tutorials/create-an-extension)
  The primary course source. Use it for `joinSession`, user and project locations, tools, slash commands, events, reloading, logs, and the experimental-feature warning.
- [Reference: "Streaming session events" - GitHub Docs](https://docs.github.com/en/copilot/how-tos/copilot-sdk/features/streaming-events)
  Defines the event stream an attached process can observe, including assistant turns, usage, tool execution, progress, and completion events.
- [Guide: "Working with canvas extensions in the GitHub Copilot app" - GitHub Docs](https://docs.github.com/en/copilot/how-tos/github-copilot-app/working-with-canvas-extensions)
  Defines the graphical comparison target: a shared interface in the app side panel with human actions, agent-callable capabilities, and shared state.
- [Concept: "About GitHub Copilot plugins" - GitHub Docs](https://docs.github.com/en/copilot/concepts/agents/about-plugins)
  Use it to keep plugin packaging separate from executable CLI extensions. It lists agents, skills, hooks, MCP, and LSP configuration as plugin contents.
- [Reference: Copilot SDK for Node.js - GitHub](https://github.com/github/copilot-sdk/blob/main/nodejs/README.md)
  Use it for session events, commands, custom tools, capability checks, and terminal UI elicitation such as confirm, select, and input dialogs.
- [Changelog: GitHub Copilot CLI - GitHub](https://github.com/github/copilot-cli/blob/main/changelog.md)
  Check before each implementation lesson because the extension feature and commands are changing quickly.

## Wisdom (Communities)

- [GitHub Community: Copilot discussions](https://github.com/orgs/community/discussions/categories/copilot-conversations)
  Use for behavior that the experimental documentation does not cover and for reports from people testing recent releases.

## Gaps

- GitHub's tutorial demonstrates tools, commands, session events, and basic UI elicitation. It does not yet document a stable arbitrary-layout API for the CLI TUI.
- This shell cannot currently resolve the `copilot` command. Verify the installed version and extension mode from Franz's normal PowerShell profile before relying on local behavior.
