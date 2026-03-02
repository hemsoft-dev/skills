---
name: langflow
description: V1.1 - Visual platform for building AI agents and workflows. Use when creating, running, or managing LangFlow projects.
---

# LangFlow

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Visual low-code platform for building AI-powered agents and workflows with LangChain.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Installation

LangFlow is installed in a dedicated virtual environment at `~/.langflow/` due to its large dependency tree (591 packages).

**Location:** `C:\Users\User\.langflow\.venv`
**Version:** 1.7.2
**Python:** 3.12

### Install from Scratch

```powershell
# Requires uv (install via: pipx install uv)
$langflowDir = "$env:USERPROFILE\.langflow"
New-Item -ItemType Directory -Path $langflowDir -Force | Out-Null
Set-Location $langflowDir
uv venv .venv --python 3.12
.\.venv\Scripts\Activate.ps1
uv pip install langflow -U
deactivate
```

### Upgrade

```powershell
Set-Location "$env:USERPROFILE\.langflow"
.\.venv\Scripts\Activate.ps1
uv pip install langflow -U
deactivate
```

## Running LangFlow

### Option 1: Launcher Script

```powershell
& "$env:USERPROFILE\.langflow\Start-LangFlow.ps1"
```

### Option 2: Manual

```powershell
Set-Location "$env:USERPROFILE\.langflow"
.\.venv\Scripts\Activate.ps1
langflow run
```

**URL:** <http://127.0.0.1:7860>

## Key Features

- Visual drag-and-drop workflow builder
- Supports all major LLMs (OpenAI, Anthropic, Google, Ollama, etc.)
- Vector database integrations (Chroma, Pinecone, Milvus, etc.)
- Built-in MCP server support
- Export flows as JSON or deploy as API
- LangSmith/LangFuse observability integration

## Configuration

**Data directory:** `~/.langflow/` (flows, settings, etc.)

### Environment Variables

```powershell
# Optional: Set API keys before running
$env:OPENAI_API_KEY = "sk-..."
$env:ANTHROPIC_API_KEY = "sk-ant-..."
```

## TODO

- [ ] **API Key Configuration** - Determine which API key(s) to configure for default LLM access
- [ ] Document flow export/import workflow
- [ ] Document MCP server deployment

## Resources

- **GitHub:** <https://github.com/langflow-ai/langflow>
- **Docs:** <https://docs.langflow.org>
- **Desktop App:** <https://www.langflow.org/desktop> (includes all dependencies)
