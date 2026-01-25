---
name: browser-use
description: V1.4 - Expert in browser-use Python library for AI-powered browser automation. Use when you need to automate web tasks, fill forms, scrape websites, interact with web pages, or control browsers programmatically with AI agents. Automatically executes browser-use tasks via PowerShell scripts - no code required from user. Uses isolated virtual environment in skill folder - no global Python packages. Supports GEMINI_API_KEY mapping for Google provider compatibility.
dependencies: python>=3.11, browser-use, playwright
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the browser-use directory (path contains 'browser-use'), verify that history logging occurred.
            
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
            Before stopping, if browser-use was used (check if any files in browser-use directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in browser-use directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Browser-Use

Browser-use is a Python library that enables AI agents to control browsers for automation tasks. It uses Playwright under the hood and supports multiple LLM providers.

## ALWAYS: Execute Tasks Automatically

**When a user requests browser automation, automatically execute the task using Invoke-BrowserUseTask.ps1.**

### Execution Workflow

1. **Extract task description** from user's natural language request
2. **Determine LLM provider** by checking available API keys in `.env` file (default: BrowserUse)
3. **Execute script** automatically - do NOT ask user to run scripts manually
4. **Return results** to user

### Automatic Task Execution

**CRITICAL: Execute tasks automatically - user should never need to write code or run scripts manually.**

When user requests browser automation (e.g., "scrape this website", "fill out this form", "find prices"), immediately run:

```powershell
& "$env:USERPROFILE\.claude\skills\browser-use\scripts\Invoke-BrowserUseTask.ps1" -Task "{USER_TASK_DESCRIPTION}"
```

**LLM Provider Selection:**

- Check `.env` file in current directory for available API keys
- If `BROWSER_USE_API_KEY` exists → Use `BrowserUse` (default, fastest)
- Else if `OPENAI_API_KEY` exists → Use `OpenAI` with `-LlmProvider OpenAI`
- Else if `ANTHROPIC_API_KEY` exists → Use `Anthropic` with `-LlmProvider Anthropic`
- Else if `GOOGLE_API_KEY` exists → Use `Google` with `-LlmProvider Google`
- Else if `DEEPSEEK_API_KEY` exists → Use `DeepSeek` with `-LlmProvider DeepSeek`
- Default to `BrowserUse` if no keys found (will prompt for key if needed)

**For stealth/CAPTCHA avoidance:**

- Add `-UseCloud` flag if user mentions CAPTCHA, stealth, or production use

**Example User Requests:**

- "Find the price of iPhone 15 on Amazon" → Execute with task: "Find the price of iPhone 15 on Amazon"
- "Fill out this job application form" → Execute with task: "Fill out this job application form"
- "Scrape product listings from this website" → Execute with task: "Scrape product listings from this website"
- "Compare prices of laptops on Best Buy and Newegg" → Execute with task: "Compare prices of laptops on Best Buy and Newegg"

**DO NOT:**

- Ask user to write Python code
- Ask user to run scripts manually
- Create temporary Python files unless absolutely necessary
- Require user to understand the underlying implementation

**DO:**

- Execute tasks automatically via Invoke-BrowserUseTask.ps1
- Handle all script execution internally
- Present results clearly to user
- Handle errors gracefully with helpful messages

## Installation

**Uses isolated virtual environment in skill folder - no global Python packages installed.**

Run the installation script to set up browser-use in an isolated venv:

```powershell
.\scripts\Install-BrowserUse.ps1
.\scripts\Install-BrowserUse.ps1 -IncludeCli  # Install with CLI support
```

This creates a `venv/` folder in the browser-use skill directory with all dependencies isolated from your system Python.

## Basic Usage

```python
import asyncio
from browser_use import Agent
from browser_use.llm import ChatOpenAI

async def main():
    agent = Agent(
        task="Compare the price of gpt-4o and DeepSeek-V3",
        llm=ChatOpenAI(model="gpt-4o-mini", temperature=1.0),
    )
    await agent.run()

asyncio.run(main())
```

## Supported LLM Providers

- OpenAI (`ChatOpenAI`) - Default model: `gpt-4o-mini`
- Anthropic (`ChatAnthropic`) - Default model: `claude-3-7-sonnet-latest` (valid models: `claude-3-7-sonnet-latest`, `claude-3-7-sonnet-20250219`, `claude-sonnet-4-5`, `claude-opus-4-5`, etc.)
- Google (`ChatGoogle`) - Default model: `gemini-2.0-flash-exp`
- DeepSeek (`ChatDeepSeek`) - Default model: `deepseek-chat`
- Grok (`ChatGrok`) - Default model: `grok-beta`
- Novita (`ChatNovita`) - Default model: `novita-llama-3.1-70b`
- Azure OpenAI (`ChatAzureOpenAI`) - Default model: `gpt-4o`
- BrowserUse (`ChatBrowserUse`) - Optimized model (default, fastest)

**API Key Configuration:**

Set API keys in `.env` file or system environment variables:

```bash
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
GOOGLE_API_KEY=          # Or use GEMINI_API_KEY (automatically mapped)
GEMINI_API_KEY=          # Automatically mapped to GOOGLE_API_KEY for browser-use compatibility
DEEPSEEK_API_KEY=
GROK_API_KEY=
NOVITA_API_KEY=
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_KEY=
BROWSER_USE_API_KEY=     # Required for BrowserUse provider or cloud mode
```

**Note:** `GEMINI_API_KEY` is automatically mapped to `GOOGLE_API_KEY` by `Invoke-BrowserUseTask.ps1` for compatibility with browser-use's Google provider.

## CLI Usage

Interactive CLI (similar to `claude` code):

```bash
browser-use
```

## MCP Integration

Browser-use supports Model Context Protocol (MCP) for integration with Claude Desktop and other MCP-compatible clients.

### As MCP Server

Add to Claude Desktop configuration:

```json
{
  "mcpServers": {
    "browser-use": {
      "command": "uvx",
      "args": ["browser-use[cli]", "--mcp"],
      "env": {
        "OPENAI_API_KEY": "sk-..."
      }
    }
  }
}
```

### Connect External MCP Servers

Agents can connect to multiple external MCP servers to extend capabilities:

```python
from browser_use import Agent, Controller
from browser_use.mcp.client import MCPClient
from browser_use.llm import ChatOpenAI

controller = Controller()

# Connect to MCP servers
filesystem_client = MCPClient(
    server_name="filesystem",
    command="npx",
    args=["-y", "@modelcontextprotocol/server-filesystem", "/path/to/documents"]
)

await filesystem_client.connect()
await filesystem_client.register_to_controller(controller)

agent = Agent(
    task="Your task",
    llm=ChatOpenAI(model="gpt-4o"),
    controller=controller
)
```

## Common Use Cases

- Form filling and submission
- Web scraping and data extraction
- Job application automation
- Shopping cart automation
- Social media interactions
- QA testing
- Document creation (Google Docs, etc.)

## Browser Configuration

Use real browser profiles for authentication:

- Reuse existing Chrome profile with saved logins
- Sync auth profile: `curl -fsSL https://browser-use.com/profile.sh | BROWSER_USE_API_KEY=XXXX sh`

## Cloud Version

For production use, Browser Use Cloud provides:

- Scalable browser infrastructure
- Stealth browser fingerprinting
- Proxy rotation
- High-performance parallel execution
- CAPTCHA avoidance

Enable cloud mode:

```python
from browser_use import Browser

browser = Browser(use_cloud=True)
```

## Best Practices

1. Use `ChatBrowserUse()` LLM for optimized browser automation (3-5x faster than other models)
2. For production, use Browser Use Cloud for scalability and stealth
3. Use real browser profiles when authentication is required
4. Custom tools can be added to extend agent capabilities
5. For CAPTCHA handling, use Browser Use Cloud's stealth browsers

## PowerShell Scripts

All scripts are located in `scripts/` subfolder and can be executed directly.

### Install-BrowserUse.ps1

Installs browser-use package and Chromium browser.

```powershell
.\scripts\Install-BrowserUse.ps1
.\scripts\Install-BrowserUse.ps1 -IncludeCli  # Install with CLI support
```

### Test-BrowserUse.ps1

Verifies browser-use installation and basic functionality.

```powershell
.\scripts\Test-BrowserUse.ps1
```

### Invoke-BrowserUseTask.ps1

**PRIMARY SCRIPT FOR AUTOMATIC TASK EXECUTION** - Use this script automatically when users request browser automation.

Executes a browser-use agent task with specified LLM provider.

**Automatic execution (use this format):**

```powershell
& "$env:USERPROFILE\.claude\skills\browser-use\scripts\Invoke-BrowserUseTask.ps1" -Task "{TASK_DESCRIPTION}"
```

**Manual usage examples:**

```powershell
# Basic usage with Browser Use optimized model
.\scripts\Invoke-BrowserUseTask.ps1 -Task "Find the number of stars of the browser-use repo"

# With OpenAI
.\scripts\Invoke-BrowserUseTask.ps1 -Task "Compare prices" -LlmProvider OpenAI -Model "gpt-4o-mini"

# With Browser Use Cloud (stealth mode)
.\scripts\Invoke-BrowserUseTask.ps1 -Task "Fill form" -UseCloud

# Custom .env file location
.\scripts\Invoke-BrowserUseTask.ps1 -Task "Scrape data" -EnvFile "C:\path\to\.env"
```

**Supported LLM Providers:** OpenAI, Anthropic, Google, DeepSeek, BrowserUse (default), Grok, Novita, AzureOpenAI

**Script Path:** `$env:USERPROFILE\.claude\skills\browser-use\scripts\Invoke-BrowserUseTask.ps1`

**Important Notes:**

- **Browser Window Behavior:** The browser window appearing and disappearing is normal - it's the agent navigating and completing tasks. The window closes automatically when the task completes.
- **Unicode Encoding Errors:** On Windows, you may see `UnicodeEncodeError` messages in the logs (emojis/special characters). These are cosmetic logging issues and do not affect functionality - the agent continues working normally.
- **Model Names:** Use valid model names for each provider. For Anthropic, use `claude-3-7-sonnet-latest` or `claude-sonnet-4-5` (not `claude-3-5-sonnet` which is deprecated).
- **Task Results:** The agent provides detailed results including product recommendations, prices, and specifications. Results are printed to console and can be captured via output redirection.

### Start-BrowserUseCli.ps1

Starts the interactive browser-use CLI (requires `browser-use[cli]`).

```powershell
.\scripts\Start-BrowserUseCli.ps1
.\scripts\Start-BrowserUseCli.ps1 -EnvFile "C:\path\to\.env"
```

### New-BrowserUseScript.ps1

Creates a ready-to-use browser-use Python script template.

```powershell
# Basic template
.\scripts\New-BrowserUseScript.ps1 -OutputPath my-agent.py

# With specific LLM provider
.\scripts\New-BrowserUseScript.ps1 -OutputPath my-agent.py -LlmProvider OpenAI -Model "gpt-4o"

# With Browser Use Cloud
.\scripts\New-BrowserUseScript.ps1 -OutputPath my-agent.py -UseCloud
```

## Resources

- Documentation: <https://docs.browser-use.com>
- Cloud: <https://cloud.browser-use.com>
- GitHub: <https://github.com/browser-use/browser-use>
- Examples: <https://github.com/browser-use/browser-use/tree/main/examples>
