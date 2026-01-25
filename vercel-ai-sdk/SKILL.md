---
name: vercel-ai-sdk
description: V1.0 - Expert in Vercel AI SDK for building AI-powered applications with Next.js, React, and TypeScript supporting multiple LLM providers.
dependencies: bun or npm/pnpm, Next.js 14+, React 18+
compatibility: Requires Node.js 18+ or Bun, supports Next.js App Router and Pages Router
---

# Vercel AI SDK

Expert in Vercel's AI SDK for building AI-powered applications with streaming, tool calling, and multi-provider support in TypeScript/JavaScript.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Overview

Vercel AI SDK is a TypeScript-first framework for building AI applications with:

- **Multi-provider support**: OpenAI, Anthropic, Google, Mistral, xAI, and more
- **Streaming-first**: Real-time text and object streaming
- **Tool calling**: Function execution with type-safe schemas
- **UI integration**: React hooks and components
- **Edge runtime**: Deploy to Vercel Edge Functions
- **Agent abstraction**: Reusable agent configurations (v6+)
- **MCP support**: Model Context Protocol integration (v6+)

## Installation

### Basic Setup

```bash
# With Bun (recommended)
bun add ai @ai-sdk/openai @ai-sdk/anthropic @ai-sdk/google

# With npm
npm install ai @ai-sdk/openai @ai-sdk/anthropic @ai-sdk/google
```

### Provider Packages

```bash
# Core SDK
bun add ai

# Providers
bun add @ai-sdk/openai          # OpenAI
bun add @ai-sdk/anthropic       # Anthropic Claude
bun add @ai-sdk/google          # Google Gemini
bun add @ai-sdk/mistral         # Mistral AI
bun add @ai-sdk/xai             # xAI Grok
bun add @ai-sdk/openrouter      # OpenRouter

# React integration
bun add ai @ai-sdk/react

# MCP support (v6+)
bun add @ai-sdk/mcp
```

## Quick Start

### Basic Text Generation

```typescript
import { generateText } from 'ai';
import { openai } from '@ai-sdk/openai';

const result = await generateText({
  model: openai('gpt-4o'),
  prompt: 'Explain quantum computing in simple terms.',
});

console.log(result.text);
```

### Streaming Text

```typescript
import { streamText } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';

const result = streamText({
  model: anthropic('claude-3-5-sonnet-20241022'),
  prompt: 'Write a short story about AI.',
});

for await (const chunk of result.textStream) {
  process.stdout.write(chunk);
}
```

### System Prompts

```typescript
const result = await generateText({
  model: openai('gpt-4o'),
  system: 'You are an expert TypeScript developer specializing in Next.js and React.',
  prompt: 'How do I implement streaming in Next.js?',
});
```

## Tool Calling

### Defining Tools

```typescript
import { generateText, tool } from 'ai';
import { z } from 'zod';

const result = await generateText({
  model: openai('gpt-4o'),
  tools: {
    weather: tool({
      description: 'Get current weather for a location',
      parameters: z.object({
        location: z.string().describe('City name'),
        unit: z.enum(['celsius', 'fahrenheit']).default('celsius'),
      }),
      execute: async ({ location, unit }) => {
        // Call weather API
        const data = await fetchWeather(location);
        return {
          temperature: unit === 'celsius' ? data.tempC : data.tempF,
          condition: data.condition,
        };
      },
    }),
    calculator: tool({
      description: 'Perform mathematical calculations',
      parameters: z.object({
        expression: z.string().describe('Math expression to evaluate'),
      }),
      execute: async ({ expression }) => {
        return { result: eval(expression) };
      },
    }),
  },
  prompt: 'What is the weather in Paris and what is 25 + 37?',
  maxSteps: 5,
});
```

### Tool Results

```typescript
console.log(result.text);           // Final response
console.log(result.toolCalls);      // Array of tool invocations
console.log(result.toolResults);    // Tool execution results
console.log(result.steps);          // Full reasoning steps
```

## Agent Abstraction (v6+)

### Creating Reusable Agents

```typescript
import { Agent } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';

const codeReviewAgent = new Agent({
  name: 'code-reviewer',
  model: anthropic('claude-3-5-sonnet-20241022'),
  instructions: `You are a senior code reviewer.
    - Check for security issues
    - Verify TypeScript types
    - Suggest performance improvements
    - Ensure consistent code style`,
  tools: {
    analyzeDependencies: tool({
      description: 'Analyze npm dependencies for vulnerabilities',
      parameters: z.object({
        packageJson: z.string(),
      }),
      execute: async ({ packageJson }) => {
        // Run security audit
        return { vulnerabilities: [], warnings: [] };
      },
    }),
  },
});

// Use agent
const review = await codeReviewAgent.run('Review this PR: ...');
```

### Agent with State

```typescript
const conversationAgent = new Agent({
  model: openai('gpt-4o'),
  instructions: 'You are a helpful assistant.',
  initialState: {
    conversationHistory: [],
    userPreferences: {},
  },
  onStateChange: (newState) => {
    // Persist state
    saveToDatabase(newState);
  },
});
```

## Next.js Integration

### API Route (App Router)

```typescript
// app/api/chat/route.ts
import { streamText } from 'ai';
import { openai } from '@ai-sdk/openai';

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: openai('gpt-4o'),
    messages,
  });

  return result.toDataStreamResponse();
}
```

### Client Component with useChat

```typescript
// app/chat/page.tsx
'use client';

import { useChat } from '@ai-sdk/react';

export default function ChatPage() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat',
  });

  return (
    <div>
      {messages.map((message) => (
        <div key={message.id}>
          <strong>{message.role}:</strong> {message.content}
        </div>
      ))}
      
      <form onSubmit={handleSubmit}>
        <input
          value={input}
          onChange={handleInputChange}
          disabled={isLoading}
          placeholder="Ask me anything..."
        />
        <button type="submit" disabled={isLoading}>
          Send
        </button>
      </form>
    </div>
  );
}
```

### Server Actions

```typescript
// app/actions.ts
'use server';

import { generateText } from 'ai';
import { openai } from '@ai-sdk/openai';

export async function generateResponse(prompt: string) {
  const result = await generateText({
    model: openai('gpt-4o'),
    prompt,
  });

  return result.text;
}
```

## Structured Output

### Generate Objects

```typescript
import { generateObject } from 'ai';
import { z } from 'zod';

const result = await generateObject({
  model: openai('gpt-4o'),
  schema: z.object({
    title: z.string(),
    summary: z.string(),
    tags: z.array(z.string()),
    sentiment: z.enum(['positive', 'negative', 'neutral']),
  }),
  prompt: 'Analyze this article: ...',
});

console.log(result.object);
// { title: "...", summary: "...", tags: [...], sentiment: "positive" }
```

### Streaming Objects

```typescript
import { streamObject } from 'ai';

const result = streamObject({
  model: openai('gpt-4o'),
  schema: z.object({
    characters: z.array(z.object({
      name: z.string(),
      role: z.string(),
      backstory: z.string(),
    })),
  }),
  prompt: 'Create 3 fantasy characters',
});

for await (const partialObject of result.partialObjectStream) {
  console.log(partialObject);
  // Incrementally receive object as it's generated
}
```

## Provider Configuration

### OpenAI

```typescript
import { openai } from '@ai-sdk/openai';

const model = openai('gpt-4o', {
  temperature: 0.7,
  maxTokens: 2000,
});

// Reasoning models
const reasoningModel = openai('o1', {
  reasoning_effort: 'low', // 'low', 'medium', 'high'
});
```

### Anthropic Claude

```typescript
import { anthropic } from '@ai-sdk/anthropic';

const model = anthropic('claude-3-5-sonnet-20241022', {
  temperature: 0.8,
  maxTokens: 4096,
});

// Environment variables
// ANTHROPIC_API_KEY=your-api-key
```

### Google Gemini

```typescript
import { google } from '@ai-sdk/google';

const model = google('gemini-2.0-flash-exp', {
  temperature: 0.9,
  topP: 0.95,
});

// Environment variables
// GOOGLE_GENERATIVE_AI_API_KEY=your-api-key
```

### xAI Grok

```typescript
import { xai } from '@ai-sdk/xai';

const model = xai('grok-2-1212', {
  temperature: 0.7,
});

// Environment variables
// XAI_API_KEY=your-api-key
```

## MCP (Model Context Protocol) v6+

### Connecting to MCP Server

```typescript
import { createMCPClient } from '@ai-sdk/mcp';

const mcpClient = createMCPClient({
  server: 'stdio',
  command: 'node',
  args: ['./mcp-servers/github-server.js'],
});

// Get tools from MCP server
const tools = await mcpClient.getTools();

const result = await generateText({
  model: openai('gpt-4o'),
  tools,
  prompt: 'Create a GitHub issue for bug #123',
});
```

### Custom MCP Server

```typescript
// mcp-servers/custom-server.ts
import { MCPServer } from '@ai-sdk/mcp';

const server = new MCPServer({
  tools: {
    database: {
      description: 'Query database',
      parameters: z.object({
        query: z.string(),
      }),
      execute: async ({ query }) => {
        // Execute DB query
        return results;
      },
    },
  },
  resources: {
    docs: {
      uri: 'docs://api',
      description: 'API documentation',
      read: async () => {
        return apiDocs;
      },
    },
  },
});

server.start();
```

## Prompt Management (with Langfuse)

### Version Control for Prompts

```typescript
import { Langfuse } from 'langfuse';

const lf = new Langfuse({
  publicKey: process.env.LANGFUSE_PUBLIC_KEY,
  secretKey: process.env.LANGFUSE_SECRET_KEY,
});

// Fetch versioned prompt
const prompt = await lf.getPrompt('code-review-agent-v2');

const result = await generateText({
  model: openai('gpt-4o'),
  system: prompt.prompt,
  prompt: 'Review this code...',
  experimental_telemetry: {
    isEnabled: true,
    metadata: {
      langfusePrompt: prompt.toJSON(),
    },
  },
});
```

### Creating Prompt Templates

```typescript
// In Langfuse UI or API
{
  "name": "code-review-agent",
  "version": 2,
  "prompt": "You are a senior code reviewer...\n{context}",
  "variables": ["context"],
}

// Use in code
const compiledPrompt = prompt.compile({ context: prContext });
```

## Multi-Agent Workflows

### Sequential Agents

```typescript
import { Agent } from 'ai';

const researchAgent = new Agent({
  model: openai('gpt-4o'),
  instructions: 'Research and gather information',
});

const writerAgent = new Agent({
  model: anthropic('claude-3-5-sonnet-20241022'),
  instructions: 'Write engaging content',
});

const editorAgent = new Agent({
  model: openai('gpt-4o'),
  instructions: 'Edit and refine content',
});

// Workflow
const research = await researchAgent.run('Research AI trends 2026');
const draft = await writerAgent.run(`Write article based on: ${research}`);
const final = await editorAgent.run(`Edit this: ${draft}`);
```

### Concurrent Agents

```typescript
const [technical, marketing, legal] = await Promise.all([
  technicalAgent.run('Analyze technical feasibility'),
  marketingAgent.run('Analyze market opportunity'),
  legalAgent.run('Identify legal compliance issues'),
]);

const summary = await coordinatorAgent.run(`
  Technical: ${technical}
  Marketing: ${marketing}
  Legal: ${legal}
  
  Provide executive summary.
`);
```

### Agent Handoff

```typescript
const supportAgent = new Agent({
  model: openai('gpt-4o'),
  instructions: 'Handle customer support',
  tools: {
    escalateToBilling: tool({
      description: 'Escalate to billing specialist',
      parameters: z.object({
        issue: z.string(),
      }),
      execute: async ({ issue }) => {
        return billingAgent.run(issue);
      },
    }),
  },
});
```

## Context Management

### Handling Long Conversations

```typescript
import { anthropic } from '@ai-sdk/anthropic';

const result = await generateText({
  model: anthropic('claude-3-5-sonnet-20241022'),
  messages: conversationHistory,
  experimental_context: {
    // Auto-clear old tool uses
    clear_tool_uses: {
      enabled: true,
      keep_recent: 10,
      token_threshold: 150000,
    },
  },
});

// Check if context exceeded
if (result.finishReason === 'model_context_window_exceeded') {
  // Truncate history and retry
  const truncated = conversationHistory.slice(-20);
  // Retry with truncated history
}
```

## Observability & Telemetry

### Built-in Telemetry

```typescript
const result = await generateText({
  model: openai('gpt-4o'),
  prompt: 'Explain TypeScript',
  experimental_telemetry: {
    isEnabled: true,
    functionId: 'explain-typescript',
    metadata: {
      userId: 'user-123',
      environment: 'production',
    },
  },
});

console.log(result.usage);
// { promptTokens: 10, completionTokens: 150, totalTokens: 160 }
```

### Custom Logging

```typescript
const result = await streamText({
  model: openai('gpt-4o'),
  prompt: 'Generate code',
  onChunk: ({ chunk }) => {
    console.log('Chunk:', chunk);
  },
  onFinish: ({ usage, text }) => {
    console.log('Finished:', { usage, length: text.length });
  },
});
```

## Error Handling

### Graceful Degradation

```typescript
import { generateText } from 'ai';
import { openai } from '@ai-sdk/openai';
import { anthropic } from '@ai-sdk/anthropic';

async function generateWithFallback(prompt: string) {
  try {
    return await generateText({
      model: openai('gpt-4o'),
      prompt,
    });
  } catch (error) {
    console.warn('OpenAI failed, trying Anthropic:', error);
    return await generateText({
      model: anthropic('claude-3-5-sonnet-20241022'),
      prompt,
    });
  }
}
```

### Rate Limiting

```typescript
import pLimit from 'p-limit';

const limit = pLimit(3); // Max 3 concurrent requests

const results = await Promise.all(
  prompts.map((prompt) =>
    limit(() =>
      generateText({
        model: openai('gpt-4o'),
        prompt,
      })
    )
  )
);
```

## Best Practices

### 1. Use Streaming for Better UX

Always prefer streaming for user-facing applications:

```typescript
// Good
const result = streamText({ model, prompt });

// Less ideal for UI
const result = await generateText({ model, prompt });
```

### 2. Type-Safe Tools with Zod

Define strict schemas for reliability:

```typescript
const tool = tool({
  parameters: z.object({
    email: z.string().email(),
    amount: z.number().positive(),
  }),
  execute: async ({ email, amount }) => {
    // TypeScript knows the exact types
  },
});
```

### 3. Separate System from User Prompts

```typescript
// Good
const result = await generateText({
  model: openai('gpt-4o'),
  system: 'You are a helpful assistant.',
  prompt: userInput,
});

// Avoid mixing in user message
```

### 4. Version Your Prompts

Use Langfuse or similar to track prompt changes:

```typescript
const prompt = await lf.getPrompt('assistant-v3');
// Track which version was used
```

### 5. Handle Context Window Limits

```typescript
if (messages.length > 50) {
  messages = messages.slice(-30); // Keep recent context
}
```

### 6. Monitor Token Usage

```typescript
const result = await generateText({ model, prompt });
console.log(`Used ${result.usage.totalTokens} tokens`);

if (result.usage.totalTokens > 50000) {
  console.warn('High token usage detected');
}
```

## GitHub Examples & Repositories

### Official Vercel Examples

1. **vercel/ai** - Core SDK with examples
   - <https://github.com/vercel/ai>
   - Official repo with API docs and usage examples

2. **vercel/ai-chatbot** - Full-featured chatbot template
   - <https://github.com/vercel/ai-chatbot>
   - Next.js App Router, shadcn/ui, Postgres persistence

3. **vercel-labs/ai-sdk-gateway-demo** - AI Gateway integration
   - <https://github.com/vercel-labs/ai-sdk-gateway-demo>
   - Shows multi-provider setup

4. **vercel-labs/ai-sdk-starter-xai** - xAI Grok starter
   - <https://github.com/vercel-labs/ai-sdk-starter-xai>
   - Streaming, tools, modern UI

5. **vercel-labs/ai-sdk-starter-braintrust** - Agent with tracing
   - <https://github.com/vercel-labs/ai-sdk-starter-braintrust>
   - Tool integration, observability

### Community Examples

1. **callstackincubator/flows-ai** - Workflow orchestration
   - <https://github.com/callstackincubator/flows-ai>
   - Multi-agent workflows, sequential/parallel patterns

2. **K-Mistele/swarm** - Multi-agent swarm system
   - <https://github.com/K-Mistele/swarm>
   - Agent collaboration, handoffs, streaming

3. **joshmu/ts-swarm** - Minimalist agent library
   - <https://github.com/joshmu/ts-swarm>
   - Simple agent patterns, task delegation

4. **peterdresslar/vercel-ai-sdk-examples** - Collection of examples
   - <https://github.com/peterdresslar/vercel-ai-sdk-examples>
   - Various use cases and patterns

5. **upstash/degree-guru** - RAG chatbot
    - <https://github.com/upstash/degree-guru>
    - Vector DB, embeddings, web scraping

## Common Patterns

### Chatbot with Memory

```typescript
const messages = [
  { role: 'system', content: 'You are a helpful assistant.' },
  ...conversationHistory,
  { role: 'user', content: userMessage },
];

const result = await generateText({
  model: openai('gpt-4o'),
  messages,
});

conversationHistory.push(
  { role: 'user', content: userMessage },
  { role: 'assistant', content: result.text }
);
```

### Function Calling Loop

```typescript
let result = await generateText({
  model: openai('gpt-4o'),
  tools,
  prompt: 'What is the weather in Paris?',
  maxSteps: 5, // Automatically handles multiple tool calls
});

console.log(result.text); // Final answer after tool calls
```

### RAG (Retrieval-Augmented Generation)

```typescript
import { embed } from 'ai';
import { openai } from '@ai-sdk/openai';

// Embed query
const { embedding } = await embed({
  model: openai.embedding('text-embedding-3-small'),
  value: userQuery,
});

// Search vector DB
const relevantDocs = await vectorDB.search(embedding);

// Generate with context
const result = await generateText({
  model: openai('gpt-4o'),
  system: 'Answer based on provided context.',
  prompt: `Context: ${relevantDocs}\n\nQuestion: ${userQuery}`,
});
```

## Troubleshooting

### Common Issues

**API key errors**: Ensure environment variables are set:

- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_GENERATIVE_AI_API_KEY`
- `XAI_API_KEY`

**Streaming not working**: Check you're using `toDataStreamResponse()` in API routes

**Tool not executing**: Verify tool schema matches parameters and `maxSteps` is set

**Context window exceeded**: Truncate message history or use context management

**Type errors**: Ensure `zod` is installed and schemas are properly defined

## When to Use This Skill

Use this skill when:

- Building AI-powered web applications
- Creating chatbots or conversational interfaces
- Implementing tool calling and function execution
- Working with Next.js and React
- Building multi-agent systems
- Needing multi-provider LLM support
- Implementing streaming responses
- Creating RAG applications
- Using TypeScript/Bun for AI development
- Building production AI applications with Vercel
