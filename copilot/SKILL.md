---
name: copilot
description: V1.3 - Expert in GitHub Copilot CLI for AI-powered coding assistance, command execution, and interactive development workflows. Defaults to copilot-free for quick prompts.
compatibility: Requires @github/copilot npm package (npm install -g @github/copilot)
metadata:
  author: skills-agent
  version: "1.2"
---

# GitHub Copilot CLI

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert in using the full GitHub Copilot CLI - an AI-powered coding assistant that runs directly in your terminal for interactive development, code generation, debugging, and automation.

## Quick Start (Recommended)

**For most tasks, use `copilot-free`** - a helper function with free-tier model and auto-approval:

```powershell
copilot-free "Generate a password validator function"
copilot-free "What is 7 + 8?"
copilot-free "Explain how JWT tokens work"
```

This uses GPT-5 Mini (free), auto-approves permissions, and provides clean output without stats.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Installation

**ISetup (One-Time)

Add the helper function to your PowerShell profile:

```powershell
# Quick free-tier prompts with auto-approval (silent output)
function copilot-free { copilot --allow-all --model gpt-5-mini --silent --prompt $args }
```

**Location:** `$PROFILE.CurrentUserAllHosts` (works across all terminals)

**Already added if you followed the installation steps.** to your PowerShell profile for quick access:

```powershell
# Quick free-tier prompts with auto-approval (silent output)
function copilot-free { copilot --allow-all --model gpt-5-mini --silent --prompt $args }
```

**Usage:**

```powershell
copilot-free "Generate a password validator function"
copilot-free "What is the capital of France?"
```

## Core Modes

### 1. Interactive Mode (Default)

Start an interactive session with the AI coding assistant.

```powershell
# Start interactive mode
copilot

# Start with a specific prompt
copilot -i "Fix the bug in main.js"

# Start with specific model
copilot --model gpt-5

# Start with permissions pre-approved
copilot --allow-all
copilot --yolo  # Same as --allow-all
```

### 2. Non-Interactive Mode (Prompt)

Execute a single prompt and exit.

```powershell
**Default: Use `copilot-free` for quick tasks**

```powershell
# Recommended for most prompts (free tier, auto-approved, clean output)
copilot-free "Generate random password"
copilot-free "Explain this error message"
```

**Advanced: Direct copilot usage for specific needs**

```powershell
# Different model
copilot -p "Complex refactoring task" --model claude-sonnet-4.5 --allow-all --silent

# Share results to markdown file
copilot -p "Document this API" --share ./output.md --allow-all

# Share to secret GitHub gist
copilot -p "Review this code" --share-gist --allow-all

Resume and manage previous sessions.

```powershell
# Resume most recent session
copilot --continue

# Resume with session picker
copilot --resume

# Resume specific session by ID
copilot --resume abc123

# Resume with auto-approval
copilot --continue --allow-all-tool
```powershell
gh copilot alias
```

## Target Types

| Target | Use Case | Example |
|--------|----------|---------|
| `shell` | General shell commands | "convert images to webp format" |
| `git` | Git operations | "squash last 3 commits" |
| `gh` | GitHub CLI operations | "list my open pull requests" |

## Common Use Cases

Available Models

| Model | Use Case |
|-------|----------|
| `claude-sonnet-4.5` | Balanced performance and capability (default) |
| `claude-haiku-4.5` | Fast, cost-effective |
| `claude-opus-4.5` | Most capable for complex tasks |
| `gpt-5.2` | Latest GPT model |
| `gpt-5.1-codex-max` | Specialized for coding |
| `gemini-3-pro-preview` | Google's latest model |
Permission Management

### Tool Permissions

```powershell
# Allow all tools automatically (required for non-interactive)
copilot --allow-all-tools

# Allow specific tools
copilot --allow-tool write --allow-tool 'shell(git:*)'

# Deny specific tools
copilot --deny-tool 'shell(git push)'

# Make specific tools available
copilot --available-tools read write shell

# Exclude specific tools
copilot --excluded-tools dangerous_tool
```

### File Path Permissions

```powershell
# Add specific directories
copilot --add-dir ~/projects --add-dir /tmp

# Allow all paths (disable verification)
copilot --allow-all-paths

# Prevent access to temp directory
copilot --disallow-temp-dir
```

### URL Permissions

```powershell
# Allow specific URLs/domains
copilot --allow-url github.com --allow-url api.example.com

# Allow all URLs
copilot --allow-all-urls

# Deny specific URLs (takes precedence)
copilot --deny-url malicious-site.com
```

## MCP Server Integration

Copilot CLI includes built-in MCP (Model Context Protocol) server support.

```Interactive Commands

When in interactive mode, use these commands:

| Command | Description |
|---------|-------------|
| `/nvironment Variables

| Variable | Description |
|----------|-------------|
| `COPILOT_ALLOW_ALL` | Enable all tool permissions |
| `GITHUB_TOKEN` | GitHub authentication token |
| `NO_COLOR` | Disable color output |

## ExampleTasks (Default: copilot-free)

```powershell
# Generate code snippets
copilot-free "Generate password generator script"

# Explain errors
copilot-free "Why does Array.prototype.map return undefined?"

# Quick documentation
copilot-free "Explain what this regex does: ^[a-zA-Z0-9]+$"
```

### Interactive Development Sessions

```powershell
copilot -i --allow-all --add-dir ./src
# Then in interactive mode:
# "Add validation to the user input function"
# "Write tests for the new validation"
# "Update documentation"
```

### Advanced with Specific Models

```powershell
# Complex code review with export
copilot -p "Review and document all functions in utils.js" --model claude-sonnet-4.5 --allow-tool read write --share ./review.md

# Debugging session
copilot -i "Debug why the API returns 500 errors" --model claude-opus-4.5
```powershell
copilot -i "Debug why the API returns 500 errors" --allow-all
```

## Notes

- Copilot CLI requires GitHub authentication
- Supports multiple AI models (Claude, GPT, Gemini)
- Built-in MCP server support for extended tool capabilities
- Interactive and non-interactive modes for different workflows
- Session persistence allows continuing previous conversations
- Use `--yolo` as shorthand for `--allow-all` (all permissions)
copilot --additional-mcp-config @./mcp-config.json

# Disable specific MCP server

copilot --disable-mcp-server github-mcp-server

# Disable all built-in MCPs

copilot --disable-builtin-mcps

```

## Common Use Cases

### Quick Questions & Code Snippets (Use copilot-free)

```powershell
# Quick code generation
copilot-free "Create a React component for user profile"

# Explain concepts
copilot-free "Explain how async/await works in JavaScript"

# Generate functions
copilot-free "Generate a password validator function"

# Commit message generation
copilot-free "Generate commit message for staged changes"

# Debug help
copilot-free "Explain this error: TypeError cannot read property"
```

### Interactive Development (Use copilot -i)

```powershell
# Complex multi-step tasks
copilot -i "Add error handling to the API endpoint" --allow-all

# Merge conflict resolution
copilot -i "Help me resolve this merge conflict" --allow-all

# Refactoring sessions
copilot -i "Refactor this component to use hooks" --allow-all
```

### Advanced Tasks (Use full copilot)

```powershell
# Code review with specific model
copilot -p "Review the code in src/utils" --model claude-sonnet-4.5 --allow-tool read --silent

# Documentation generation with export
copilot -p "Document the API endpoints" --share ./docs.md --allow-all

# Automation scripts with file output
copilot -p "Create script to backup database" --allow-all --silent > backup.sh
```

## Best Practices

1. **Default to copilot-free** - Use for quick prompts, questions, and simple code generation (free tier)
2. **Interactive mode for complex tasks** - Use `copilot -i --allow-all` for multi-step development
3. **Choose appropriate models** - Free tier (gpt-5-mini) for most tasks, claude-sonnet for complexity
4. **Resume sessions** - Use `--continue` to pick up where you left off in interactive mode
5. **Share results** - Use `--share` or `--share-gist` to document outcomes
6. **Silent mode for scripting** - Already included in copilot-free; outputs only the response
7. **Explain before executing** - Use `explain` to understand commands before running them
8. **Shell-out for automation** - Use `-s` flag to save commands for scripts
9. **Learn from suggestions** - Review generated commands to improve your CLI knowledge

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Extension not found | Run `gh extension install github/gh-copilot` |
| Authentication error | Ensure GitHub CLI is authenticated: `gh auth login` |
| Deprecated warning | Check for newer Copilot CLI versions |
| No suggestions | Try rephrasing or adding more context |

## Examples by Scenario

**Docker Management:**

```powershell
gh copilot suggest "stop all running containers"
gh copilot suggest "remove unused docker images"
gh copilot explain 'docker-compose up -d --build'
```

**PowerShell/Windows:**

```powershell
gh copilot suggest "list all services starting with 'docker'"
gh copilot suggest "check windows version and build"
gh copilot suggest "export registry key to file"
```

**Data Processing:**

```powershell
gh copilot suggest "count lines in all .txt files"
gh copilot suggest "merge multiple CSV files"
gh copilot suggest "extract column from JSON file"
```

## Notes

- Copilot CLI requires GitHub authentication via `gh auth login`
- Suggestions are AI-generated and should be reviewed before execution
- The extension provides an interactive, conversational experience
- Commands can be refined through follow-up prompts
- Works best with clear, specific task descriptions
