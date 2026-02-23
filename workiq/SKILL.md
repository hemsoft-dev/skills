---
name: workiq
description: V1.0 - Expert in Microsoft Work IQ CLI and MCP server for querying M365 data (emails, calendar, Teams, documents, people) using natural language. Use when working with WorkIQ installation, authentication, configuration, querying M365 data, or setting up WorkIQ as an MCP server.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the workiq directory (path contains 'workiq'), verify that history logging occurred.
            
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
            Before stopping, if workiq was used (check if any files in workiq directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in workiq directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
---

# Work IQ Skill

Query your Microsoft 365 data with natural language — emails, calendar, meetings, documents, Teams messages, and people.

## What Is Work IQ?

**Microsoft Work IQ** (Public Preview) is a CLI tool and MCP (Model Context Protocol) server by Microsoft
that connects AI assistants to your Microsoft 365 Copilot data. It's the intelligence layer behind M365 Copilot —
understanding your emails, calendar, files, chats, and the people you work with.

- **npm package**: [`@microsoft/workiq`](https://www.npmjs.com/package/@microsoft/workiq) (v0.2.8+)
- **GitHub**: [github.com/microsoft/work-iq-mcp](https://github.com/microsoft/work-iq-mcp)
- **Status**: Public Preview — features and APIs may change

## What You Can Query

| Data Type | Example Natural Language Questions |
|-----------|-----------------------------------|
| **Emails** | "What did John say about the proposal?" / "Summarize emails from Sarah about the budget" |
| **Meetings** | "What's on my calendar tomorrow?" / "What meetings do I have this week?" |
| **Documents** | "Find my recent PowerPoint presentations" / "Find documents I worked on yesterday" |
| **Teams** | "Summarize today's messages in the Engineering channel" |
| **People** | "Who is working on Project Alpha?" / "What did my manager say about the deadline?" |

## Installation

### Option A: Global Install

```powershell
npm install -g @microsoft/workiq
```

### Option B: npx (no install)

```powershell
npx -y @microsoft/workiq mcp
```

### Option C: GitHub Copilot CLI Plugin (recommended for Copilot CLI users)

```bash
# Inside GitHub Copilot CLI
/plugin marketplace add github/copilot-plugins
/plugin install workiq@copilot-plugins
```

### Option D: VS Code MCP Server

Click [Install in VS Code](https://vscode.dev/redirect/mcp/install?name=workiq&config=%7B%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22%40microsoft%2Fworkiq%22%2C%22mcp%22%5D%7D)
or add manually in `.vscode/mcp.json`:

```json
{
  "workiq": {
    "command": "npx",
    "args": ["-y", "@microsoft/workiq", "mcp"],
    "tools": ["*"]
  }
}
```

## Authentication & Tenant Admin Consent

Work IQ accesses Microsoft 365 tenant data and **requires admin consent** from the tenant.

- On first use, a consent dialog appears in the browser
- If you are NOT a tenant admin, ask your admin to grant access
- Admin instructions: [ADMIN-INSTRUCTIONS.md](https://github.com/microsoft/work-iq-mcp/blob/main/ADMIN-INSTRUCTIONS.md)
- Reference: [Microsoft User and Admin Consent Overview](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/user-admin-consent-overview)

For personal/home M365 accounts (not enterprise tenants), authentication typically completes with no admin needed.

## CLI Reference

### Commands

| Command | Description |
|---------|-------------|
| `workiq accept-eula` | Accept the EULA (required on first use) |
| `workiq ask` | Ask a question in interactive mode or with `-q` flag |
| `workiq mcp` | Start MCP stdio server for agent communication |
| `workiq version` | Show version information |

### Global Options

| Option | Description | Default |
|--------|-------------|---------|
| `-t, --tenant-id <tenant-id>` | Entra tenant ID for authentication | `common` |
| `--version` | Show version information | |
| `-?, -h, --help` | Show help and usage information | |

### `workiq ask` Options

| Option | Description |
|--------|-------------|
| `-q, --question <question>` | The question to ask (non-interactive) |

## Usage Examples

```powershell
# First time setup — accept EULA
workiq accept-eula

# Check version
workiq version

# Start interactive session
workiq ask

# Ask a single question
workiq ask -q "What meetings do I have tomorrow?"
workiq ask -q "Summarize emails from Sarah about the budget"
workiq ask -q "Find my recent documents about Q4 planning"
workiq ask -q "What did my manager say about the project deadline?"
workiq ask -q "Summarize today's messages in the Engineering Teams channel"
workiq ask -q "Who is working on Project Alpha?"

# Use a specific Entra tenant
workiq ask -t "your-tenant-id" -q "Show my emails from today"

# Start as MCP server (for IDE/agent integration)
workiq mcp

# Run MCP server without global install
npx -y @microsoft/workiq mcp
```

## MCP Server Configuration

When using Work IQ as an MCP server (e.g., in Claude, VS Code, Cursor, or other agents):

```json
{
  "mcpServers": {
    "workiq": {
      "command": "npx",
      "args": ["-y", "@microsoft/workiq", "mcp"],
      "tools": ["*"]
    }
  }
}
```

Or if installed globally:

```json
{
  "mcpServers": {
    "workiq": {
      "command": "workiq",
      "args": ["mcp"]
    }
  }
}
```

## Platform Support

| Platform | Supported |
|----------|-----------|
| Windows x64 | ✅ |
| Windows ARM64 | ✅ |
| Linux x64 | ✅ |
| Linux ARM64 | ✅ |
| macOS x64 | ✅ |
| macOS ARM64 | ✅ |
| WSL | ✅ (requires browser for sign-in) |

**WSL browser setup** (if needed):

```bash
sudo apt install xdg-utils
sudo apt install wslu
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Admin consent required" | Contact your M365 tenant admin or see [ADMIN-INSTRUCTIONS.md](https://github.com/microsoft/work-iq-mcp/blob/main/ADMIN-INSTRUCTIONS.md) |
| No data returned | Ensure your M365 Copilot license is active and has indexed data |
| Auth loop / browser not opening in WSL | Install `xdg-utils` and `wslu` |
| Wrong tenant | Use `-t your-tenant-id` to specify the correct Entra tenant ID |
| EULA not accepted | Run `workiq accept-eula` before first use |
| MCP server not discovered | Verify JSON config uses `npx -y @microsoft/workiq mcp` |

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

Get the current time with: `Get-Date -Format "HH:mm"` — never guess the timestamp.
