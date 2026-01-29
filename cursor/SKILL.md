---
name: cursor
description: V1.2 - Expert in Cursor IDE features, shortcuts, settings, Composer mode, chat, custom agents, MCP servers, and usage tracking. Includes @ symbol context inclusion guide. Use when working with Cursor IDE or needing help with Cursor-specific functionality.
---

# Cursor IDE Helper

Expert guidance for using Cursor IDE - the AI-powered code editor. Provides help with features, shortcuts, settings, Composer mode, chat, and usage tracking.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Usage Dashboard

Monitor your Cursor usage, subscription status, and API consumption:

**Dashboard URL**: <https://cursor.com/dashboard?tab=usage>

The dashboard shows:

- Request counts and limits
- Subscription tier and billing
- Usage statistics over time
- API token consumption
- Model usage breakdown

## Core Features

### Composer Mode

Composer is Cursor's multi-file editing mode that can make changes across your entire codebase.

**Activation:**

- Keyboard shortcut: `Ctrl+I` (Windows/Linux) or `Cmd+I` (Mac)
- Command Palette: "Composer: Open Composer"
- Sidebar: Click Composer icon

**Usage:**

- Describe changes you want across multiple files
- Composer analyzes your codebase and makes coordinated edits
- Review changes before accepting
- Can refactor, add features, fix bugs across entire projects

### Chat Mode

One-on-one conversation with the AI assistant for questions, explanations, and single-file edits.

**Activation:**

- Keyboard shortcut: `Ctrl+L` (Windows/Linux) or `Cmd+L` (Mac)
- Command Palette: "Chat: Open Chat"
- Sidebar: Click Chat icon

**Usage:**

- Ask questions about code
- Get explanations of complex logic
- Request code generation
- Debug errors and issues
- Single-file edits and suggestions

### Context Inclusion with `@` Symbol

Use the `@` symbol to explicitly include files, code, and other context in Chat or Composer (similar to `#` in GitHub Copilot):

| Symbol | Purpose | Example |
|--------|---------|---------|
| `@Files` | Include specific files in context | `@Button.tsx` `@src/utils/helpers.ts` |
| `@Folders` | Include entire folders | `@src/components/` `@lib/` |
| `@Code` | Reference code symbols (functions, classes, variables) | `@fetchUser` `@UserClass` |
| `@Docs` | Include documentation or web results | `@docs react hooks` |
| `@Web` | Search web and include results | `@web latest typescript 5.4 features` |
| `@Git` | Include git diff/changes | `@git` |
| `@Codebase` | Semantic search across codebase | `@codebase authentication flow` |
| `@Chat` | Reference previous chat messages | `@chat` |

**Usage Examples:**

```
"Refactor @Button.tsx to use the pattern from @Card.tsx"

"Explain how @fetchUser function works with @database/"

"Update @codebase error handling to match @docs error boundaries"

"What changed in @git that might affect @api/routes.ts?"
```

**Tips:**

- Type `@` and start typing - autocomplete will suggest matches
- Can combine multiple `@` references in one prompt
- Files are auto-included based on cursor position, but `@` gives explicit control
- `@Codebase` performs semantic search across entire project

### Inline Edit Mode

Quick edits directly in your code using `Ctrl+K` (Windows/Linux) or `Cmd+K` (Mac).

**Usage:**

- Select code you want to modify
- Press `Ctrl+K` / `Cmd+K`
- Describe the change
- Accept or reject suggestions

## Keyboard Shortcuts

### Essential Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+L` / `Cmd+L` | Open Chat |
| `Ctrl+I` / `Cmd+I` | Open Composer |
| `Ctrl+K` / `Cmd+K` | Inline edit (select code first) |
| `Ctrl+Shift+L` / `Cmd+Shift+L` | Open Chat in new tab |
| `Ctrl+/` / `Cmd+/` | Toggle AI suggestions |

### Navigation

| Shortcut | Action |
|----------|--------|
| `Ctrl+P` / `Cmd+P` | Quick file open |
| `Ctrl+Shift+P` / `Cmd+Shift+P` | Command Palette |
| `Ctrl+B` / `Cmd+B` | Toggle sidebar |
| `Ctrl+` ` / `Cmd+` ` | Toggle terminal |

### Code Actions

| Shortcut | Action |
|----------|--------|
| `Ctrl+.` / `Cmd+.` | Quick fix / suggestions |
| `F2` | Rename symbol |
| `Shift+Alt+F` / `Shift+Option+F` | Format document |
| `Ctrl+Shift+K` / `Cmd+Shift+K` | Delete line |

## Settings & Configuration

### Access Settings

- File → Preferences → Settings (or `Ctrl+,` / `Cmd+,`)
- Settings UI for visual configuration
- `settings.json` for direct JSON editing

### Key Settings

**AI Model Selection:**

- Settings → Cursor → Model
- Choose between Claude, GPT-4, GPT-3.5, etc.
- Set default model for different modes

**Composer Settings:**

- Settings → Cursor → Composer
- Configure file inclusion/exclusion patterns
- Set max files to edit simultaneously
- Enable/disable auto-apply

**Chat Settings:**

- Settings → Cursor → Chat
- Configure context window size
- Set default behavior for code suggestions
- Enable/disable inline suggestions

**Privacy & Data:**

- Settings → Privacy
- Control telemetry and usage data
- Configure code indexing
- Manage data sharing preferences

## Custom Agents & MCP Servers

Cursor supports custom agents and agent-like workflows similar to GitHub Copilot, though some features are in beta.

### Custom Modes (Beta)

Custom Modes let you tailor agent behavior by selecting which tools it has access to and custom instructions/prompts.

**Access:**

- Settings → Chat → Custom Modes
- Create modes with specific tool access and behavior
- Mix and match capabilities to match your workflow

**Use Cases:**

- Create specialized "Review Agent" for code reviews
- Create "Implement Agent" focused on implementation
- Create "Debug Agent" for troubleshooting
- Define persona-based agents with specific rules

**Configuration:**

- Select which tools are enabled (file search, code editing, terminal, MCP servers)
- Set custom prompts and instructions
- Configure tool permissions per mode
- Define behavior patterns and constraints

### MCP (Model Context Protocol) Servers

Cursor supports MCP servers to extend functionality with external services and APIs.

**Configuration Location:**

- Windows: `%APPDATA%\Cursor\User\mcp.json` or `%APPDATA%\Code\User\mcp.json`
- Mac: `~/Library/Application Support/Cursor/User/mcp.json`
- Linux: `~/.config/Cursor/User/mcp.json`

**Example MCP Configuration:**

```json
{
  "mcpServers": {
    "cortex-remote": {
      "transport": "http",
      "url": "https://mcp.cortex.io/mcp",
      "headers": {
        "Authorization": "Bearer ${CORTEX_TOKEN}"
      }
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp-server"],
      "env": {
        "PLAYWRIGHT_BROWSER_TYPE": "chromium"
      }
    }
  }
}
```

**Available MCP Servers:**

- **Cortex** - Internal Developer Portal integration
- **Playwright** - Browser automation tools
- **GitHub** - Repository and issue management
- **Custom servers** - Build your own MCP servers

**After Configuration:**

- Restart Cursor after modifying `mcp.json`
- Use Command Palette: "MCP: Restart All Servers" to reload
- MCP tools become available in Chat and Composer modes

### Parallel Agents

Cursor supports running up to **eight agents in parallel** per prompt.

**Features:**

- Each agent runs in isolated workspace (git worktrees)
- Agents don't interfere with each other
- Useful for experimenting with different approaches
- Compare results from multiple agent instances

**Usage:**

- Enable in Composer settings
- Specify number of parallel agents
- Each agent works independently on the same task
- Review and merge best results

### Agent Hooks (Beta)

Hooks allow observing and influencing agent behavior at runtime.

**Capabilities:**

- Block certain commands dynamically
- Change behavior based on context
- Intercept and modify agent actions
- Add custom validation logic

**Use Cases:**

- Prevent destructive operations
- Enforce coding standards
- Add custom approval workflows
- Monitor agent activity

### Creating Custom Agent Workflows

**Strategy 1: Custom Modes**

1. Go to Settings → Chat → Custom Modes
2. Create new mode with specific name (e.g., "Code Review Agent")
3. Configure tool access (enable/disable specific tools)
4. Add custom instructions and prompts
5. Save and select mode when needed

**Strategy 2: Rules-Based Agents**

1. Use `.cursorrules` file for project-specific behavior
2. Define agent personas and constraints
3. Set coding standards and patterns
4. Enforce architectural decisions

**Strategy 3: MCP Integration**

1. Configure MCP servers in `mcp.json`
2. Connect to external services (APIs, databases, tools)
3. Extend agent capabilities with custom tools
4. Build domain-specific agent workflows

**Strategy 4: Workspace Configuration**

1. Use `.cursorignore` to control context
2. Configure file inclusion/exclusion patterns
3. Set up project-specific agent behavior
4. Create isolated agent environments

### Limitations & Future Features

**Current Limitations:**

- Custom Modes are in beta and may have limited features
- Subagents (orchestrated specialized agents) not fully available
- Some advanced agent features require enterprise/beta access
- Agent sharing across teams is limited

**Requested Features:**

- Full subagent support with orchestration
- Versionable agent definitions
- Team-wide agent sharing
- More robust custom agent UI
- Better agent orchestration tools

**Workarounds:**

- Use Custom Modes to simulate different agent personas
- Combine rules, MCP servers, and modes for complex workflows
- Use parallel agents to test different approaches
- Leverage hooks for runtime behavior control

## Workspace Configuration

### .cursorrules File

Create `.cursorrules` in your project root to customize AI behavior:

```markdown
# Project-specific rules for Cursor AI

- Use TypeScript strict mode
- Prefer functional programming patterns
- Follow existing code style
- Add JSDoc comments for public APIs
```

### .cursorignore File

Exclude files/directories from AI context:

```gitignore
node_modules/
dist/
build/
*.log
.env
```

## Best Practices

### Using Composer

1. **Be specific** - Describe exactly what you want changed
2. **Provide context** - Mention related files or patterns
3. **Review changes** - Always review before accepting
4. **Iterate** - Break large changes into smaller requests
5. **Use natural language** - Describe intent, not implementation

### Using Chat

1. **Ask focused questions** - One topic at a time
2. **Use `@` for context** - Explicitly include files (`@filename`), code symbols (`@function`), or search codebase (`@codebase`)
3. **Provide examples** - Show what you're trying to achieve
4. **Clarify context** - Mention framework, language version, etc.
5. **Follow up** - Refine requests based on responses

### Code Quality

1. **Review AI suggestions** - Don't blindly accept all changes
2. **Test changes** - Verify functionality after AI edits
3. **Maintain style** - Ensure consistency with existing code
4. **Add comments** - Document complex AI-generated logic
5. **Run linters** - Check for issues after AI edits

## Troubleshooting

### Common Issues

**AI not responding:**

- Check internet connection
- Verify API key in settings
- Check usage limits on dashboard
- Restart Cursor

**Composer not finding files:**

- Check `.cursorignore` patterns
- Verify file paths are correct
- Ensure files are saved
- Check workspace root configuration

**Suggestions not appearing:**

- Enable inline suggestions in settings
- Check keyboard shortcut conflicts
- Verify AI model is selected
- Restart language server

**High token usage:**

- Review usage dashboard
- Reduce context window size
- Use `.cursorignore` to exclude large files
- Break requests into smaller chunks

## Integration

### Git Integration

Cursor integrates with Git for version control:

- View diffs in editor
- Stage/unstage changes
- Commit with AI-generated messages
- Resolve merge conflicts

### Extensions

Cursor supports VS Code extensions:

- Install from Extensions marketplace
- Configure extension settings
- Use extension-specific features
- Manage extension updates

### Terminal Integration

Built-in terminal support:

- Multiple terminal tabs
- Split terminal views
- Integrated shell commands
- Terminal AI assistance

## Usage Monitoring

**Always check your usage dashboard** before starting large refactoring tasks:

<https://cursor.com/dashboard?tab=usage>

Monitor:

- Daily/weekly/monthly request counts
- Token consumption per model
- Subscription limits and remaining quota
- Billing and payment information

## Tips & Tricks

1. **Master `@` context** - Use `@Files`, `@Code`, `@Codebase`, `@Web`, `@Git`, `@Docs` for precise context control
2. **Multi-cursor editing** - `Alt+Click` to add cursors, then use AI
3. **Code selection** - Select code before using `Ctrl+K` for context
4. **Command history** - Use arrow keys in chat to repeat previous prompts
5. **Workspace context** - Open relevant files before using Composer
6. **Incremental changes** - Make small, focused edits rather than large rewrites
7. **Review mode** - Use diff view to review all Composer changes before accepting
8. **Combine @ references** - Mix multiple `@` symbols in one prompt for rich context

## Resources

- **Dashboard**: <https://cursor.com/dashboard?tab=usage>
- **Documentation**: <https://docs.cursor.com>
- **Settings**: File → Preferences → Settings
- **Keyboard Shortcuts**: File → Preferences → Keyboard Shortcuts
