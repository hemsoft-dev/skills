```markdown
---
name: ollama
description: V1.0 - Local LLM runtime for running open-source models. Use for model management, installation, and integration with AI agents like Goose.
---

# Ollama

Run large language models locally with Ollama.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Installation

```powershell
winget install --id Ollama.Ollama -e --source winget
```

**Location:** `%LOCALAPPDATA%\Programs\Ollama\ollama.exe`

Verify:

```powershell
ollama --version
```

## Model Management

### List Models

```powershell
ollama list
```

### Pull Model

```powershell
ollama pull {model-name}
```

### Remove Model

```powershell
ollama rm {model-name}
```

### Run Model Interactively

```powershell
ollama run {model-name}
```

## Tool-Calling Capable Models

**CRITICAL:** Not all models support function/tool calling. For AI agent integration (Goose, etc.), use these models:

### Recommended for RTX 5090 (32GB VRAM)

| Model | Size | Tool Support | Notes |
|-------|------|--------------|-------|
| `qwen3:14b` | 9.3GB | ✅ | Best balance of size and capability |
| `qwen2.5:7b` | 4.7GB | ✅ | Lighter, good for testing |
| `qwen2.5-coder:32b` | 19GB | ✅ | Heavy but excellent for coding |
| `hermes3:8b` | 5GB | ✅ | Specifically trained for function calling |
| `llama3.1:8b` | 5GB | ✅ | Good general purpose |
| `mistral-nemo:12b` | 7GB | ✅ | Strong tool support |
| `deepseek-r1:14b` | 9GB | ✅ | Newer reasoning model |

### Models WITHOUT Tool Support

| Model | Notes |
|-------|-------|
| `nemotron-3-nano` | Does NOT support function calling |
| `gemini-*` via Ollama | Often rate-limited (uses API proxy) |

## Goose Integration

Ollama works with Goose AI agent. Key learnings:

1. **Provider name:** Use `ollama` in Goose config
2. **Tool calling required:** Model must support tools for extensions to work
3. **Web search:** Requires Tavily MCP extension (not just API key)

### Goose Config Example

```yaml
GOOSE_PROVIDER: ollama
GOOSE_MODEL: qwen3:14b
OLLAMA_HOST: localhost
extensions:
  tavily:
    name: Tavily Web Search
    cmd: npx
    args: ["-y", "tavily-mcp"]
    enabled: true
    envs:
      TAVILY_API_KEY: "{your-api-key}"
    type: stdio
    timeout: 300
```

## Troubleshooting

### Model Not Responding to Tools

- Verify model supports tool calling (see table above)
- Check with: `ollama show {model-name}` for capabilities

### Out of Memory

- Use smaller quantization: `ollama pull {model}:q4_0`
- Try smaller model variant

### Rate Limiting (Gemini models)

- Gemini via Ollama uses API proxy with rate limits
- Switch to locally-run models like qwen3 or llama3.1

## Resources

- **Official Site:** <https://ollama.com>
- **Model Library:** <https://ollama.com/library>
- **GitHub:** <https://github.com/ollama/ollama>
```
