---
name: agent-framework
description: V1.0 - Expert in Microsoft Agent Framework for building AI agents and multi-agent workflows in C# and Python with Agent Framework Toolkit support.
---

# Microsoft Agent Framework

Expert in Microsoft's comprehensive framework for building, orchestrating, and deploying AI agents with multi-agent workflows in both .NET and Python.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Framework Overview

Microsoft Agent Framework is the successor to Semantic Kernel and AutoGen, providing:

- **Multi-language support**: Full implementations for C#/.NET and Python
- **Graph-based workflows**: Connect agents and deterministic functions with streaming, checkpointing, and human-in-the-loop
- **Multiple agent providers**: Azure OpenAI, OpenAI, Anthropic, Google (via A2A), and more
- **Observability**: Built-in OpenTelemetry integration
- **Middleware system**: Request/response processing, exception handling, custom pipelines
- **Type safety**: Structured outputs and durable workflows

## Installation

### .NET

```bash
dotnet add package Microsoft.Agents.AI --prerelease
dotnet add package Microsoft.Agents.AI.OpenAI --prerelease
dotnet add package Azure.AI.OpenAI --prerelease
dotnet add package Azure.Identity
```

### Python

```bash
pip install agent-framework --pre
```

## Agent Framework Toolkit (Recommended)

The Agent Framework Toolkit by rwjdk provides opinionated wrappers that simplify configuration and reduce boilerplate.

**NuGet Packages** (all at `AgentFrameworkToolkit.*` namespace):

- `AgentFrameworkToolkit` - Core toolkit
- `AgentFrameworkToolkit.AzureOpenAI` - Azure OpenAI provider
- `AgentFrameworkToolkit.OpenAI` - OpenAI provider
- `AgentFrameworkToolkit.Anthropic` - Anthropic/Claude provider
- `AgentFrameworkToolkit.Google` - Google/Gemini provider
- `AgentFrameworkToolkit.Mistral` - Mistral AI provider
- `AgentFrameworkToolkit.XAI` - xAI/Grok provider
- `AgentFrameworkToolkit.GitHub` - GitHub Models provider
- `AgentFrameworkToolkit.OpenRouter` - OpenRouter provider
- `AgentFrameworkToolkit.Cohere` - Cohere provider
- `AgentFrameworkToolkit.Tools.ModelContextProtocol` - MCP tools support

**Key Features**:

- `AgentFactory`: Simplified agent creation with provider-specific options
- `AIToolsFactory`: Create tools from classes using `[AITool]` attributes
- `EmbeddingFactory`: Generate embeddings (where supported)
- Provider-specific configuration (reasoning effort, tool calling middleware, etc.)

**Installation**:

```bash
dotnet add package AgentFrameworkToolkit.AzureOpenAI --prerelease
```

## Quick Start Examples

### Basic Agent (Azure OpenAI with Toolkit)

```csharp
using AgentFrameworkToolkit.AzureOpenAI;

AzureOpenAIAgentFactory agentFactory = new("<endpoint>", "<apiKey>");

AzureOpenAIAgent agent = agentFactory.CreateAgent(new AgentOptions
{
    Model = OpenAIChatModels.Gpt5Mini,
    ReasoningEffort = OpenAIReasoningEffort.Low,
    Tools = [AIFunctionFactory.Create(WeatherTool.GetWeather)],
    RawToolCallDetails = details => { Console.WriteLine(details.ToString()); }
});

var response = await agent.RunAsync<WeatherReport>("What is the weather like in Paris?");
WeatherReport weatherReport = response.Result;
```

### Basic Agent (Python - Azure OpenAI)

```python
import asyncio
from agent_framework.azure import AzureOpenAIResponsesClient
from azure.identity import AzureCliCredential

async def main():
    agent = AzureOpenAIResponsesClient(
        credential=AzureCliCredential()
    ).create_agent(
        name="HaikuBot",
        instructions="You are an upbeat assistant that writes beautifully."
    )
    
    result = await agent.run("Write a haiku about Microsoft Agent Framework.")
    print(result)

if __name__ == "__main__":
    asyncio.run(main())
```

### Creating Tools from Classes (Toolkit)

```csharp
// 1. Define tool class with [AITool] attributes
public class MyTools
{
    [AITool]
    public string GetWeather(string location)
    {
        return $"Weather in {location}: Sunny, 72°F";
    }

    [AITool]
    public string GetTime()
    {
        return DateTime.Now.ToString();
    }
}

// 2. Get tools via factory
IList<AITool> tools = aiToolsFactory.GetTools(typeof(MyTools));
// or with instance
IList<AITool> tools = aiToolsFactory.GetTools(new MyTools());
```

## Provider Configuration

### Azure OpenAI

**Environment Variables**:

- `AZURE_OPENAI_ENDPOINT` - Resource URI
- `AZURE_OPENAI_RESPONSES_DEPLOYMENT_NAME` - Model deployment name
- `AZURE_OPENAI_API_VERSION` - API version (optional)
- `AZURE_OPENAI_API_KEY` - API key (optional if using Azure CLI)

**Authentication**: Azure CLI (`az login`) or API key

### Anthropic

**Environment Variables**:

- `ANTHROPIC_API_KEY` - API key
- `ANTHROPIC_DEPLOYMENT_NAME` - Model name (e.g., "claude-3-5-sonnet-20241022")
- For Azure Foundry: `ANTHROPIC_RESOURCE` - Foundry resource name

**Models**: Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku

### Google (via A2A Protocol)

Microsoft Agent Framework supports Google models via the Agent-to-Agent (A2A) protocol for multi-agent interoperability. For direct Gemini API access, use the Agent Framework Toolkit's Google provider.

### OpenAI

**Environment Variables**:

- `OPENAI_API_KEY` - API key

**Models**: GPT-4o, GPT-4o-mini, GPT-5-mini, o1, o3-mini, o4-mini

## Multi-Agent Workflows

### Orchestration Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| **Sequential** | Pipeline with stages | Research → Write → Review |
| **Concurrent** | Parallel execution | Multiple experts analyze simultaneously |
| **Group Chat** | Manager-orchestrated collaboration | Star topology with central coordinator |
| **Magentic** | Dynamic planner-based allocation | Adaptive task assignment |
| **Handoff** | Dynamic routing and delegation | Context-based agent switching |

### Sequential Workflow Example (C#)

```csharp
using Microsoft.Agents.AI.Workflows;

var workflow = new WorkflowBuilder(frenchAgent)
    .AddEdge(frenchAgent, spanishAgent)
    .AddEdge(spanishAgent, englishAgent)
    .Build();

await using var run = await InProcessExecution.StreamAsync(
    workflow, 
    new ChatMessage(ChatRole.User, "Hello world!")
);

await foreach (var evt in run.WatchStreamAsync())
{
    if (evt is AgentResponseUpdateEvent update)
    {
        Console.WriteLine($"{update.ExecutorId}: {update.Data}");
    }
}
```

### Concurrent Workflow Example (Python)

```python
from agent_framework import ConcurrentBuilder

workflow = ConcurrentBuilder().participants([
    researcher_agent,
    marketer_agent,
    legal_agent
]).build()

async for event in workflow.run_stream("Launch new electric bike"):
    if isinstance(event, WorkflowOutputEvent):
        print("Final aggregated:", event.data)
```

## Advanced Features

### Human-in-the-Loop

Workflows support approval steps where human intervention is required before proceeding.

### Checkpointing & Resumption

Long-running workflows can be paused, saved, and resumed later:

```csharp
// Save checkpoint
var checkpoint = await workflow.CreateCheckpointAsync();

// Resume from checkpoint
var workflow = await Workflow.ResumeFromCheckpointAsync(checkpoint);
```

### Structured Outputs

Use type-safe outputs instead of text parsing:

```csharp
var response = await agent.RunAsync<WeatherReport>(question);
WeatherReport report = response.Result;
```

### Middleware

Add cross-cutting concerns without modifying agent logic:

```csharp
agent.AddMiddleware(async (context, next) =>
{
    Console.WriteLine($"Request: {context.Message}");
    await next();
    Console.WriteLine($"Response: {context.Response}");
});
```

### Tool Calling Middleware (Toolkit)

```csharp
var agent = agentFactory.CreateAgent(new AgentOptions
{
    RawToolCallDetails = details => 
    {
        Console.WriteLine($"Tool: {details.ToolName}");
        Console.WriteLine($"Args: {details.Arguments}");
    }
});
```

## Project Setup Best Practices

### .NET Project Structure

```
MyAgentProject/
├── Agents/
│   ├── ResearchAgent.cs
│   ├── WriterAgent.cs
│   └── ReviewAgent.cs
├── Tools/
│   ├── WebSearchTool.cs
│   └── DataAnalysisTool.cs
├── Workflows/
│   └── ContentPipeline.cs
├── Program.cs
└── MyAgentProject.csproj
```

### Configuration Management

Use `IConfiguration` for settings:

```csharp
var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;

var endpoint = config["AzureOpenAI:Endpoint"];
var apiKey = config["AzureOpenAI:ApiKey"];
```

### Dependency Injection

Register agents and factories:

```csharp
builder.Services.AddSingleton<AzureOpenAIAgentFactory>(sp =>
    new AzureOpenAIAgentFactory(endpoint, apiKey));
```

## DevUI

The Agent Framework includes a Developer UI for testing and debugging:

```bash
# Install DevUI package
pip install agent-framework-devui --pre

# Launch DevUI
agent-framework-devui
```

**Features**:

- Interactive agent testing
- Workflow visualization
- Real-time streaming
- Debug inspection

## Observability & Telemetry

Built-in OpenTelemetry support:

```csharp
// .NET
using Microsoft.Extensions.Telemetry;

builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddAgentFrameworkInstrumentation());
```

```python
# Python
from agent_framework.telemetry import configure_telemetry

configure_telemetry(
    service_name="my-agent-app",
    endpoint="http://localhost:4318"
)
```

## Migration Guides

### From Semantic Kernel

- Replace `Kernel` with `ChatClientAgent` or workflow builders
- Convert `SKFunction` to `AIFunction`
- Update plugins to tools using `AIFunctionFactory`

### From AutoGen

- Replace `AssistantAgent` with `ChatAgent`
- Convert group chat to `GroupChatBuilder` pattern
- Update termination conditions to workflow edges

## Common Patterns

### Multi-Turn Conversations

```csharp
var thread = agent.GetNewThread();
var messages = new List<ChatMessage>();

while (true)
{
    var userInput = Console.ReadLine();
    messages.Add(new ChatMessage(ChatRole.User, userInput));
    
    var response = await agent.RunAsync(messages, thread);
    messages.Add(new ChatMessage(ChatRole.Assistant, response.Text));
    
    Console.WriteLine(response.Text);
}
```

### Error Handling

```csharp
try
{
    var response = await agent.RunAsync(query);
}
catch (AgentException ex)
{
    Console.WriteLine($"Agent error: {ex.Message}");
}
catch (ToolExecutionException ex)
{
    Console.WriteLine($"Tool failed: {ex.ToolName} - {ex.Message}");
}
```

### Rate Limiting

```csharp
var rateLimiter = new RateLimiter(requestsPerMinute: 60);
agent.AddMiddleware(async (context, next) =>
{
    await rateLimiter.WaitAsync();
    await next();
});
```

## Resources

- **Official Docs**: <https://learn.microsoft.com/en-us/agent-framework/>
- **GitHub**: <https://github.com/microsoft/agent-framework>
- **Agent Framework Toolkit**: <https://github.com/rwjdk/AgentFrameworkToolkit>
- **Samples**: <https://github.com/rwjdk/MicrosoftAgentFrameworkSamples>
- **NuGet**: Search "AgentFrameworkToolkit" for provider packages
- **Discord**: Join the official Microsoft Agent Framework community
- **Udemy Course**: [AI in C# using the Microsoft Agent Framework](https://www.udemy.com/course/ai-in-c-sharp-using-the-microsoft-agent-framework/)

## Troubleshooting

### Common Issues

**"Agent not found" errors**: Ensure deployment name matches environment variable

**Tool execution failures**: Verify tool methods are public and have `[AITool]` attribute

**Streaming not working**: Check if provider supports streaming (Responses API required)

**Authentication errors**: Run `az login` for Azure CLI auth or verify API keys

### Performance Optimization

- Use streaming for real-time responses
- Enable caching for repeated queries
- Batch concurrent operations
- Set appropriate timeout values
- Monitor token usage via telemetry

## When to Use This Skill

Use this skill when:

- Building AI agents or chatbots
- Creating multi-agent workflows
- Integrating LLMs into applications
- Implementing agentic AI patterns
- Working with Microsoft Agent Framework or Agent Framework Toolkit
- Migrating from Semantic Kernel or AutoGen
- Setting up agent-based architectures
- Configuring multiple LLM providers
- Implementing human-in-the-loop workflows
- Building graph-based orchestration systems
