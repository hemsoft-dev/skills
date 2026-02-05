````skill
---
name: copilot-sdk
description: V1.2 - Expert in GitHub Copilot SDK for integrating Copilot Agent into applications. Supports Node.js/TypeScript, Python, Go, and .NET with multi-turn conversations, tool execution, and full lifecycle control.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the copilot-sdk directory (path contains 'copilot-sdk'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if copilot-sdk was used (check if any files in copilot-sdk directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in copilot-sdk directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}"
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# GitHub Copilot CLI SDK

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert guidance for integrating GitHub Copilot Agent into applications using the GitHub Copilot CLI SDK. The SDK provides programmatic access to the same agentic execution loop that powers GitHub Copilot CLI.

## Overview

The GitHub Copilot SDK is currently in **Technical Preview** and provides language-specific SDKs for:

- **Node.js/TypeScript**: `@github/copilot-sdk`
- **Python**: `github-copilot-sdk` (also available as `copilot` on PyPI)
- **Go**: `github.com/github/copilot-sdk-go`
- **.NET**: `GitHub.Copilot.SDK`

## Key Features

All SDKs provide a consistent API with:

- **Multi-turn conversations**: Maintain session history for context-aware interactions
- **Tool execution**: Define custom tools that the model can invoke during conversations
- **Full lifecycle control**: Manage client and session lifecycles programmatically
- **JSON-RPC communication**: All SDKs communicate with Copilot CLI server via JSON-RPC
- **Real-time streaming**: Support for streaming events and responses
- **Session history**: Access conversation history via `get_messages()` or similar methods
- **Custom agents, skills, and tools**: Extend functionality with custom implementations
- **MCP server integration**: Connect to Model Context Protocol servers
- **BYOK support**: Bring Your Own Key for data security

## Prerequisites

### Required Subscription

A GitHub Copilot subscription is required to use the GitHub Copilot SDK:

- GitHub Copilot Pro
- GitHub Copilot Pro+
- GitHub Copilot Business
- GitHub Copilot Enterprise

Free tier of Copilot CLI includes limited usage.

### Required Installation

The Copilot CLI must be installed separately. The SDKs communicate with the Copilot CLI in server mode.

**Installation options:**

- Follow the [Copilot CLI installation guide](https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli)
- Install via GitHub CLI: `gh copilot`
- Ensure `copilot` is available in your PATH

## Installation

### Node.js/TypeScript

```bash
npm install @github/copilot-sdk
```

**Package**: `@github/copilot-sdk` (version 0.1.9+)

### Python

```bash
pip install github-copilot-sdk
# or
pip install copilot
```

**Requirements**: Python ≥3.8 (supports 3.8-3.12)

### Go

```bash
go get github.com/github/copilot-sdk-go
```

### .NET

```bash
dotnet add package GitHub.Copilot.SDK
```

## Architecture

The SDK architecture follows this pattern:

```
Your Application
↓
SDK Client
↓ JSON-RPC
Copilot CLI (server mode)
```

The SDK manages the CLI process lifecycle automatically. You can also connect to an external CLI server for advanced use cases.

## Basic Usage Examples

### Node.js/TypeScript

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();
await client.start();

const session = await client.createSession({
  model: "gpt-5", // or "claude-sonnet-4.5" (default)
});

await session.send({
  prompt: "Hello, world!",
});

// Access session history
const messages = await session.getMessages();

// Clean up
await session.close();
await client.stop();
```

### Python

```python
import asyncio
from copilot import CopilotClient

async def main():
    client = CopilotClient()
    await client.start()
    
    session = await client.create_session({"model": "gpt-5"})
    await session.send({"prompt": "What is 2+2?"})
    
    # Access session history
    messages = await session.get_messages()
    
    # Clean up
    await session.close()
    await client.stop()

asyncio.run(main())
```

### Go

```go
import (
    "github.com/github/copilot-sdk-go/copilot"
)

client := copilot.NewClient()
defer client.Stop()

err := client.Start()
if err != nil {
    log.Fatal(err)
}

session, err := client.CreateSession(copilot.SessionConfig{
    Model: "gpt-5",
})
if err != nil {
    log.Fatal(err)
}

_, err = session.Send(copilot.Message{
    Prompt: "Hello, world!",
})
```

### .NET

```csharp
using GitHub.Copilot.SDK;

var client = new CopilotClient();
await client.StartAsync();

var session = await client.CreateSessionAsync(new SessionConfig
{
    Model = "gpt-5"
});

await session.SendAsync(new Message
{
    Prompt = "Hello, world!"
});

await session.CloseAsync();
await client.StopAsync();
```

## Advanced Features

### Custom Tools

Define custom tools that the agent can invoke:

```typescript
const customTool = {
  name: "calculate",
  description: "Performs mathematical calculations",
  parameters: {
    type: "object",
    properties: {
      expression: { type: "string" }
    }
  },
  execute: async (params) => {
    return { result: eval(params.expression) };
  }
};

await session.addTool(customTool);
```

### Tool Configuration

By default, SDK operates with `--allow-all` equivalent, enabling all first-party tools:

- File system operations
- Git operations
- Web requests
- Shell commands

You can customize tool availability by configuring SDK client options to enable/disable specific tools.

### Model Selection

All models available via Copilot CLI are supported. The SDK exposes a method to return available models at runtime:

```typescript
const models = await client.getAvailableModels();
// Returns: ["claude-sonnet-4.5", "gpt-5", ...]
```

**Default model**: Claude Sonnet 4.5

### Connecting to External CLI Server

For advanced use cases, you can connect to an external CLI server:

```typescript
const client = new CopilotClient({
  serverUrl: "http://localhost:8080",
  // or use stdio transport
});
```

See the [Getting Started Guide](https://github.com/github/copilot-sdk/blob/main/docs/getting-started.md#connecting-to-an-external-cli-server) for details.

### Streaming Responses

All SDKs support real-time streaming:

```typescript
const stream = await session.sendStream({
  prompt: "Explain quantum computing",
});

for await (const chunk of stream) {
  console.log(chunk.content);
}
```

## Billing & Usage

- Each prompt counts towards your premium request quota
- Billing follows the same model as Copilot CLI
- See [Requests in GitHub Copilot](https://docs.github.com/en/copilot/concepts/billing/copilot-requests) for details
- Model multipliers apply (e.g., "Claude Sonnet 4.5 (1x)")

## Security Considerations

### Trusted Directories

When using the SDK, Copilot CLI will ask to trust directories. Only trust directories you control.

### Tool Approval

By default, tools require approval. You can configure automatic approval:

- `--allow-all-tools`: Allow all tools
- `--allow-tool 'shell(git)'`: Allow specific tools
- `--deny-tool 'shell(rm)'`: Deny specific tools

### BYOK (Bring Your Own Key)

Configure the SDK to use your own encryption keys for data security. Refer to individual SDK documentation for BYOK setup instructions.

## Resources

### Official Documentation

- **Main Repository**: <https://github.com/github/copilot-sdk>
- **Getting Started Guide**: <https://github.com/github/copilot-sdk/blob/main/docs/getting-started.md>
- **Cookbook**: <https://github.com/github/copilot-sdk/tree/main/cookbook>
- **Samples**: <https://github.com/github/copilot-sdk/tree/main/samples>

### Language-Specific Documentation

- **Node.js**: <https://github.com/github/copilot-sdk/tree/main/nodejs>
- **Python**: <https://github.com/github/copilot-sdk/tree/main/python>
- **Go**: <https://github.com/github/copilot-sdk/tree/main/go>
- **.NET**: <https://github.com/github/copilot-sdk/tree/main/dotnet>

### Additional Resources

- **GitHub Blog**: [Build an agent into any app with the GitHub Copilot SDK](https://github.blog/news-insights/company-news/build-an-agent-into-any-app-with-the-github-copilot-sdk)
- **Changelog**: [Copilot SDK in technical preview](https://github.blog/changelog/2026-01-14-copilot-sdk-in-technical-preview)
- **Custom Instructions**: <https://github.com/github/awesome-copilot/blob/main/collections/copilot-sdk.md>
- **Copilot CLI Docs**: <https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli>

## Common Use Cases

### Code Generation

```typescript
await session.send({
  prompt: "Create a REST API endpoint for user authentication",
});
```

### Code Review

```typescript
await session.send({
  prompt: "Review the changes in this PR and report any issues",
  context: { prUrl: "https://github.com/owner/repo/pull/123" },
});
```

### File Operations

```typescript
await session.send({
  prompt: "Refactor the authentication module to use async/await",
});
```

### Git Operations

```typescript
await session.send({
  prompt: "Create a branch, make changes, and open a PR",
});
```

## Troubleshooting

### CLI Not Found

Ensure Copilot CLI is installed and available in PATH:

```bash
which copilot  # Linux/Mac
where copilot  # Windows
```

### Authentication Issues

Verify your GitHub Copilot subscription is active and properly authenticated.

### Model Availability

Check available models:

```typescript
const models = await client.getAvailableModels();
console.log(models);
```

### Session Management

Always properly close sessions and stop clients:

```typescript
try {
  // ... use session
} finally {
  await session.close();
  await client.stop();
}
```

## Status & Limitations

- **Status**: Technical Preview (not production-ready)
- **Subject to change**: API may change before general availability
- **Feedback**: Report issues via [GitHub Issues](https://github.com/github/copilot-sdk/issues)

## Best Practices

1. **Always close sessions**: Properly clean up sessions and clients
2. **Handle errors**: Implement proper error handling for network and API errors
3. **Monitor usage**: Track your premium request quota
4. **Use appropriate models**: Choose models based on task complexity
5. **Secure tool access**: Be careful with automatic tool approval
6. **Test in isolated environments**: Use VMs or containers for testing

## Related Concepts

- **GitHub Copilot CLI**: The command-line interface that powers the SDK
- **Model Context Protocol (MCP)**: Protocol for connecting to external data sources
- **Custom Agents**: Specialized agent configurations for specific tasks
- **Skills**: Enhancements for specialized task performance
- **Hooks**: Execute custom commands at key points during execution
````
