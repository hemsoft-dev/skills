---
name: relias-assistant
description: V1.0 - Expert in the Relias Assistant (Yakob) project - a Slack-integrated AI assistant for Relias engineering teams. Knows architecture, tech stack, capabilities, identity (logos, names), launch status, documentation locations, and how to navigate the private GitHub repository.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the relias-assistant directory (path contains 'relias-assistant'), verify that history logging occurred.
            
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
            Before stopping, if relias-assistant was used (check if any files in relias-assistant directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in relias-assistant directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
              - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
              - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Relias Assistant Skill

Expert knowledge about the Relias Assistant (codename: Yakob) project - a Slack-integrated AI assistant for
engineering teams at Relias.

## Quick Reference

| Property | Value |
|----------|-------|
| **Official Name** | Relias Assistant |
| **Codename** | Yakob |
| **Slack Handle** | @Relias Assistant |
| **Slash Command** | `/ra` |
| **Repository** | `relias-engineering/relias-assistant` (private) |
| **JIRA Epic** | [PE-681](https://relias.atlassian.net/browse/PE-681) |
| **Primary Language** | C# (.NET 10.0) |
| **Status** | Active Development |
| **Lead Developer** | Franz Hemmer |

## What is Relias Assistant?

Relias Assistant (Yakob) is a Slack-integrated AI assistant designed to enhance productivity for engineering teams at
Relias. It provides:

- **Intelligent Q&A** - Answers questions about development practices, tools, and resources
- **Documentation Lookup** - Searches Confluence pages, JIRA tickets, and GitHub repositories
- **Knowledge Access** - Retrieves information from vector-stored proprietary documentation (employee handbook,
developer onboarding)
- **Thread-based Conversations** - Maintains context in Slack threads
- **Centralized Information** - Single access point for engineering team knowledge

## Identity & Branding

### Logos & Icons

- **Primary Logo**: `assets/yakob-logo.png` (1MB PNG)
- **Slack Icons**: `assets/slack/rae-icon-v1.png` through `rae-icon-v7.png` (7 versions available)

### Names & Handles

- **Full Name**: Relias Assistant
- **Codename**: Yakob
- **Slack Display Name**: "Relias Assistant"
- **Slack Mention**: @Relias Assistant
- **Slash Command**: `/ra`

## Tech Stack & Architecture

### Core Technologies

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Runtime** | .NET 10.0, C# | Primary application framework |
| **AI Services** | Azure OpenAI via `Microsoft.Extensions.AI` | LLM integration for chat responses |
| **Messaging** | Slack Socket Mode | Real-time Slack event handling |
| **Search** | Azure AI Search | Vector store for semantic search |
| **Infrastructure** | Azure Container Apps, Bicep | Cloud hosting and IaC |
| **Frontend Support** | TypeScript, Playwright MCP | Browser automation capabilities |

### Architecture Pattern (4-Layer Modular)

```text
Console (host/startup) → Slack (channel adapter) → AI (orchestration/tools) → Common (utilities/telemetry)
```

| Layer | Assembly | Responsibility |
|-------|----------|----------------|
| **Console** | `Relias.Assistant.Console` | Entry point, configuration loading, service initialization |
| **Slack** | `Relias.Assistant.Slack` | Socket Mode connection, thread handling, message formatting |
| **AI** | `Relias.Assistant.AI` | Azure OpenAI client, tool functions (Confluence, JIRA, GitHub, Vector Store, Web Search, Cortex, Slack Skill) |
| **Common** | `Relias.Assistant.Common` | Logging, telemetry abstraction, shared utilities |

### Key Integrations

- **Confluence** - Documentation search and page retrieval
- **JIRA** - Ticket lookup and metadata extraction
- **GitHub** - Repository and code search within `relias-engineering` org
- **Vector Store** - Semantic search across proprietary docs (employee handbook, dev documentation)
- **Web Search** - Tavily integration for external information
- **Cortex** - Internal Developer Portal integration
- **Slack Skill** - Message search capabilities

## Information Lookup Memo

When asked about Relias Assistant, consult these locations in the repository:

### Core Documentation

| Question Type | Primary Source | Secondary Sources |
|---------------|----------------|-------------------|
| **What is it? Overview** | `README.md` | `AGENTS.md` (Quick Reference section) |
| **Current status, roadmap** | `TODO.md` | JIRA Epic PE-681 (via atlassian skill) |
| **Architecture & design** | `AGENTS.md` (Architecture section) | `docs/THREADING-ARCHITECTURE.md`, `docs/decision-records/` |
| **Setup & deployment** | `README.md` (Getting Started), `CONFIGURATION.md` | `docs/DEPLOYMENT-GUIDE.md`, `AZURE.md` |
| **Tech stack details** | `Relias.Assistant.sln`, `Directory.Build.props`, `package.json` | `README.md` (Architecture section) |
| **Testing & quality** | `README.md` (Testing section), `tests/` directory | Integration test files (e.g., `*IntegrationTests.cs`) |
| **Terminology** | `VERBIAGE.md` | `AGENTS.md` |
| **Contributors & history** | `README.md` (Contributors), `History/` directory | Git commit history |
| **Troubleshooting** | `docs/TROUBLESHOOTING-CONTAINER-APP-CONFIG.md` | `README.md` (Configuration) |

### Identity & Branding Assets

| Asset Type | Location |
|------------|----------|
| **Primary Logo** | `assets/yakob-logo.png` |
| **Slack Icons** | `assets/slack/rae-icon-v[1-7].png` |
| **Slack App Config** | `assets/slack/app-manfiest.json` |
| **Slack Display Name** | `assets/slack/app-manfiest.json` → `display_information.name` |

### Configuration & Settings

| Config Type | Location |
|-------------|----------|
| **App Settings** | `appsettings.json` (template), `appsettings.Development.json` (local) |
| **Environment Template** | `.env.template` |
| **Docker Configuration** | `Dockerfile`, `docker-compose.yml` |
| **Azure Infrastructure** | `.iac/` directory (Bicep files) |
| **Code Quality** | `.editorconfig`, `stylecop.json`, `SonarLint.xml`, `.markdownlint.json` |

## Accessing the Repository

This is a **private repository** in the `relias-engineering` organization. Use GitHub CLI to access it:

### View Repository Info

```powershell
gh repo view relias-engineering/relias-assistant --json name,description,owner,url,primaryLanguage,languages
```

### List Directory Contents

```powershell
# List root directory
gh api /repos/relias-engineering/relias-assistant/contents --jq '.[] | "\(.type)\t\(.name)"' | Sort-Object

# List specific directory (e.g., docs/)
gh api /repos/relias-engineering/relias-assistant/contents/docs --jq '.[] | "\(.type)\t\(.name)"' | Sort-Object
```

### Read File Contents

```powershell
# Read a file (e.g., README.md)
gh api /repos/relias-engineering/relias-assistant/contents/README.md --jq '.content' | ForEach-Object {
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
}

# Read first N lines only
gh api /repos/relias-engineering/relias-assistant/contents/AGENTS.md --jq '.content' | ForEach-Object {
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
} | Select-Object -First 100
```

### Search Repository

```powershell
# Search code for a term
gh api "/search/code?q=Microsoft.Extensions.AI+repo:relias-engineering/relias-assistant" --jq '.items[] | "\(.path):\(.name)"'

# Search issues/PRs
gh issue list --repo relias-engineering/relias-assistant
gh pr list --repo relias-engineering/relias-assistant
```

## Common Questions & Answers

### Q: What is Relias Assistant?

A: Relias Assistant (codename: Yakob) is a Slack-integrated AI assistant designed to enhance productivity for
engineering teams at Relias. It provides intelligent responses, documentation lookup, code search, and centralized
access to various information sources including Confluence, JIRA, GitHub, and proprietary knowledge bases.

### Q: Does it have a logo/icon/bio image?

A: Yes! The primary logo is located at `assets/yakob-logo.png` in the repository. There are also 7 different Slack icon
versions available at `assets/slack/rae-icon-v[1-7].png`.

### Q: What can it do? What are its capabilities?

A: Relias Assistant can:

- Answer questions about development practices, tools, and resources
- Search Confluence documentation and return formatted results with links
- Retrieve detailed JIRA ticket information by key/ID
- Search GitHub repositories and code in the relias-engineering organization
- Access vector-stored knowledge bases for company-specific information (employee handbook, dev docs)
- Perform web searches using Tavily
- Query Cortex Internal Developer Portal
- Search Slack message history
- Maintain context in thread-based conversations
- Format responses with Markdown support

### Q: What is its history?

A: Check the `History/` directory in the repository for interaction logs. For development history, review the
`README.md` (Contributors section) and git commit history. The project is tracked under JIRA Epic
[PE-681](https://relias.atlassian.net/browse/PE-681).

### Q: Is it launched yet?

A: The bot is in **active development**. Check `TODO.md` for current status and pending tasks. To verify deployment
status, consult `AZURE.md` and the deployment guide at `docs/DEPLOYMENT-GUIDE.md`.

### Q: Who do I talk to if I have a feature request or want a new feature?

A: Contact **Franz Hemmer** (lead developer) or create a ticket in the **Productivity Engineering (PE)** JIRA project.
The main epic is [PE-681](https://relias.atlassian.net/browse/PE-681).

### Q: What is its full name?

A: **Relias Assistant** (codename: Yakob)

### Q: What is the @ name on Slack for it?

A: **@Relias Assistant** or use the slash command **`/ra`**

## Best Practices for Using This Skill

### When to Use This Skill

- User asks "What is Relias Assistant?"
- Questions about Yakob project identity, branding, or capabilities
- Need to find documentation or configuration in the relias-assistant repository
- Questions about architecture, tech stack, or design decisions
- Looking for logos, icons, or branding assets
- Need to understand current status, roadmap, or launch plans
- Feature requests or contributor information
- Troubleshooting or setup questions

### Integration with Other Skills

This skill works well with:

- **atlassian** - For deeper JIRA epic and ticket analysis (PE-681)
- **github** - For repository operations, PRs, releases
- **azure** - For deployment and infrastructure questions
- **slack** - For Slack workspace and channel information

### Lookup Strategy

1. **Start with README.md** - Most overview questions answered here
2. **Check AGENTS.md** - For architecture and AI-specific instructions
3. **Consult TODO.md** - For current status and pending work
4. **Use GitHub CLI** - Don't store large files; fetch content on demand
5. **Reference sections** - Use Information Lookup Memo table above

## Contributors

- **Franz Hemmer** - Lead Developer (Slack bot, AI integrations, RAG, Confluence, JIRA connectors)
- **Furkan Karabalut** - GitHub Integration
- **Sagar Thakore** - Developer Documentation Pipeline

## Notes

- **Versioning**: Project uses git commit count for automatic version incrementing (e.g., `1.0.193`)
- **Configuration Priority**: CLI args > env vars > user secrets > `appsettings.Development.json` > `appsettings.json`
- **Required Config**: `AzureOpenAI:Key`, `AzureOpenAI:Url`, `Slack:AppLevelToken`, `Slack:BotToken`
- **License**: Proprietary - Relias Learning, LLC
