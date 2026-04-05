---
name: aspire
description: "V2.0 - Expert in Aspire 13.x multi-language distributed app orchestration with C# and TypeScript AppHost authoring, Aspire CLI, integrations, dashboard, deployment, and AI agent workflows. Use when creating, running, debugging, or deploying Aspire apps in any language."
---

# Aspire

Expert in Aspire — the multi-language, code-first toolchain for building, running, and deploying distributed applications. Aspire orchestrates apps in C#, Java, Python, JavaScript, TypeScript, Go, and more.

**Note**: Aspire moved from `dotnet/aspire` to `microsoft/aspire` — it is no longer .NET-only.

## Key Concepts

- **AppHost**: The orchestrator that defines your distributed app's architecture in code. Can be written in **C#** (`apphost.cs` / `AppHost.cs`) or **TypeScript** (`apphost.ts`).
- **Service Defaults**: Shared configuration (OpenTelemetry, health checks, resilience) applied to service projects.
- **Integrations**: Packages that add resources (Postgres, Redis, RabbitMQ, Azure services, JS/TS apps) to the AppHost.
- **Dashboard**: Built-in OpenTelemetry web UI for logs, traces, metrics, and resource status.
- **Aspire CLI**: Cross-platform CLI (`aspire`) for creating, running, managing, and publishing Aspire apps.
- **Resources**: The building blocks — services, containers, databases, frontends, executables — anything Aspire orchestrates.

## Prerequisites

| AppHost Language | Runtime Required | Container Runtime |
|-----------------|-----------------|-------------------|
| **C# AppHost** | .NET SDK 10.0.100+ | Docker Desktop / Podman |
| **TypeScript AppHost** | Node.js 22+ | Docker Desktop / Podman |

Both AppHost languages can orchestrate apps in **any** language. The choice only affects the orchestration layer.

## Aspire CLI Installation

```powershell
# Windows (PowerShell)
irm https://aspire.dev/install.ps1 | iex

# macOS/Linux (Bash)
curl -sSL https://aspire.dev/install.sh | bash

# Verify
aspire --version
# Expected: 13.2.0+{commitSHA}
```

Installs to `~/.aspire/bin/aspire`.

## Aspire CLI Command Reference

### App Commands

| Command | Status | Purpose |
|---------|--------|---------|
| `aspire new` | Stable | Create project from starter template (interactive) |
| `aspire init` | Stable | Add Aspire to existing codebase |
| `aspire run` | Stable | Run AppHost interactively (foreground, with dashboard) |
| `aspire start` | Stable | Start AppHost in background |
| `aspire stop` | Stable | Stop running AppHost (`--all` for all) |
| `aspire ps` | Stable | List running AppHosts |
| `aspire add` | Stable | Add hosting integration package |
| `aspire update` | Preview | Update Aspire packages in project |
| `aspire restore` | Stable | Restore dependencies and generate SDK code |

### Resource Management

| Command | Status | Purpose |
|---------|--------|---------|
| `aspire resource <name> <cmd>` | Stable | Execute command on resource (start/stop/restart) |
| `aspire wait <resource>` | Stable | Block until resource reaches target status (healthy/up/down) |

### Monitoring & Diagnostics

| Command | Status | Purpose |
|---------|--------|---------|
| `aspire describe` | Stable | Show resource details from running AppHost |
| `aspire logs` | Stable | Stream logs from resources |
| `aspire otel` | Preview | View OpenTelemetry data (logs, spans, traces) |
| `aspire export` | Stable | Export telemetry/resource data to zip |

### Deployment

| Command | Status | Purpose |
|---------|--------|---------|
| `aspire publish` | Preview | Generate deployment artifacts (Bicep, docker-compose, Helm) |
| `aspire deploy` | Preview | Deploy to deployment targets |
| `aspire do <step>` | Preview | Execute specific pipeline step |

### Tools & Configuration

| Command | Status | Purpose |
|---------|--------|---------|
| `aspire agent init` | Stable | Set up AI agent environment (skill file, MCP server) |
| `aspire agent mcp` | Stable | Start MCP server for AI agents |
| `aspire doctor` | Stable | Diagnose environment issues |
| `aspire certs` | Stable | Manage HTTPS dev certificates |
| `aspire config` | Stable | Manage CLI settings and feature flags |
| `aspire secret` | Stable | Manage AppHost user secrets |
| `aspire docs` | Stable | Browse/search Aspire docs from terminal |
| `aspire mcp` | Stable | List/call MCP tools from running resources |
| `aspire cache` | Stable | Manage CLI disk cache |

### CLI Global Options

- `--non-interactive` — Disable prompts (for scripts/CI)
- `--format Json` — Machine-readable output
- `--nologo` — Suppress banner
- `-l, --log-level <level>` — Set log level (Trace/Debug/Information/Warning/Error/Critical)

## AppHost Patterns

### TypeScript AppHost (`apphost.ts`)

```typescript
// apphost.ts — TypeScript AppHost (Node.js 22+, no .NET required)
import { createBuilder } from './.modules/aspire.js';

const builder = await createBuilder();

const cache = await builder.addRedis("cache");

const api = await builder
    .addNodeApp("api", "./api", "src/index.ts")
    .withReference(cache)
    .waitFor(cache)
    .withHttpEndpoint({ env: "PORT" })
    .withExternalHttpEndpoints();

await builder
    .addViteApp("frontend", "./frontend")
    .withReference(api)
    .waitFor(api);

await builder.build().run();
```

### TypeScript AppHost — JavaScript/TypeScript Resource Methods

```typescript
// Vite-based apps (React, Vue, Svelte)
const frontend = await builder
    .addViteApp("frontend", "./packages/web")
    .withExternalHttpEndpoints()
    .withReference(api)
    .waitFor(api);

// Node.js applications
const api = await builder
    .addNodeApp("api", "./packages/api", "src/server.js")
    .withNpm()                           // or .withYarn() or .withPnpm()
    .withHttpHealthCheck({ path: "/health" });

// Generic JavaScript app with custom run script
const worker = await builder
    .addJavaScriptApp("worker", "./packages/worker")
    .withNpm()
    .withRunScript("start");             // runs `npm run start`

// Pass arguments to scripts
await builder.addViteApp("frontend", "./frontend")
    .withArgs(["--no-open"]);

// Or use a custom script name
await builder.addViteApp("frontend", "./frontend")
    .withRunScript("dev:no-open");       // runs `npm run dev:no-open`

// Bundle frontend for production deployment
await app.publishWithContainerFiles(frontend, "./static");
```

### C# AppHost (`apphost.cs` or `AppHost.cs`)

```csharp
// apphost.cs — single-file AppHost (no .csproj needed)
var builder = DistributedApplication.CreateBuilder(args);

var db = builder.AddPostgres("db");
var api = builder.AddProject<Projects.Api>("api")
    .WithReference(db);

builder.AddProject<Projects.Web>("web")
    .WithReference(api);

builder.Build().Run();
```

### C# AppHost — Multi-Language Orchestration

```csharp
// Vite frontend from C# AppHost
builder.AddViteApp("frontend", "../frontend")
    .WithHttpEndpoint(env: "PORT")
    .WithReference(api);

// Node.js app
builder.AddNodeApp("api", "./api", "src/index.ts")
    .WithReference(cache)
    .WaitFor(cache)
    .WithHttpEndpoint(env: "PORT");

// Python
builder.AddPythonApp("worker", "../worker", "main.py")
    .WithReference(db);

// Docker container
builder.AddContainer("service", "myimage", "latest")
    .WithHttpEndpoint(targetPort: 8080);

// Generic executable
builder.AddExecutable("tool", "mytool", "../tools")
    .WithArgs("--port", "8080");
```

### Adding Common Resources (both AppHost languages)

Resources are available in both C# and TypeScript AppHosts. Syntax examples shown in C#:

```csharp
// Databases
var postgres = builder.AddPostgres("pg").AddDatabase("mydb");
var sqlserver = builder.AddSqlServer("sql").AddDatabase("mydb");
var mongodb = builder.AddMongoDB("mongo").AddDatabase("mydb");

// Caching
var redis = builder.AddRedis("cache");
var garnet = builder.AddGarnet("cache");

// Messaging
var rabbitmq = builder.AddRabbitMQ("messaging");
var kafka = builder.AddKafka("kafka");

// Azure Services
var storage = builder.AddAzureStorage("storage");
var cosmos = builder.AddAzureCosmosDB("cosmos");
var servicebus = builder.AddAzureServiceBus("sb");
var keyvault = builder.AddAzureKeyVault("kv");
```

TypeScript equivalent:

```typescript
const postgres = await builder.addPostgres("pg").addDatabase("mydb");
const redis = await builder.addRedis("cache");
const rabbitmq = await builder.addRabbitMQ("messaging");
```

### Service Discovery & References

When you call `withReference` (TS) or `WithReference` (C#), Aspire automatically injects configuration (connection strings, endpoints, env vars) so services communicate seamlessly.

```typescript
// TypeScript: withReference injects API_HTTP / API_HTTPS env vars
const api = await builder.addNodeApp("api", "./api", "server.js").withNpm();
await builder.addViteApp("frontend", "./frontend")
    .withReference(api);  // Frontend gets api endpoint injected
```

```csharp
// C#: WithReference injects connection string or endpoint
var api = builder.AddProject<Projects.Api>("api")
    .WithReference(db)           // Connection string injected
    .WithReference(redis);       // Connection string injected

var web = builder.AddProject<Projects.Web>("web")
    .WithReference(api)          // HTTP endpoint discovered via "api" name
    .WaitFor(api);               // Wait for api to be healthy before starting
```

### Volumes & Persistence

```csharp
var db = builder.AddPostgres("pg")
    .WithDataVolume("pg-data");           // Named volume persists across restarts
    .WithLifetime(ContainerLifetime.Persistent);  // Container survives AppHost restarts
```

## Common Workflows

### Create New Project

```powershell
# TypeScript starter (React + Express + TypeScript AppHost)
aspire new aspire-ts-starter -n MyApp -o ./myapp

# C# starter
aspire new aspire-starter -n MyApp -o ./myapp
```

### Add Aspire to Existing Project

```powershell
# TypeScript AppHost (Node.js 22+ required, .NET NOT required)
aspire init --language typescript

# C# AppHost (.NET SDK 10.0 required)
aspire init --language csharp

# Interactive (asks which language)
aspire init

# After init, add JavaScript hosting integration
aspire add javascript
```

### What `aspire init --language typescript` Creates

```
apphost.ts              # Orchestration code
.modules/               # Generated SDK (managed by CLI — don't edit)
aspire.config.json      # Configuration
package.json            # AppHost dependencies
tsconfig.json           # TypeScript configuration
```

### Development Loop

```powershell
aspire run                    # Start everything + dashboard (foreground)
# OR for background:
aspire start                  # Start in background
aspire describe               # Check resource status
aspire logs api               # Stream logs from specific resource
aspire stop                   # Stop when done
```

### Agent-Driven Development

```powershell
# Set up AI agent environment (creates skill file + MCP server config)
aspire agent init

# Background execution for agents
aspire start --isolated       # Isolated parallel worktrees
aspire wait api --status healthy
aspire describe --format Json # Structured output for agents
aspire logs api --format Json # Structured log output
```

### Adding Integrations

```powershell
aspire add javascript         # JavaScript/TypeScript hosting support
aspire add redis              # Add Redis integration
aspire add postgres           # Add PostgreSQL integration
aspire add                    # Browse available integrations interactively
```

### CI/CD Pipeline

```powershell
aspire restore                # Restore + generate SDK code
aspire publish                # Generate Bicep/Helm/docker-compose
aspire deploy                 # Deploy to targets
```

## Deployment Targets

Aspire publish generates artifacts based on the deployment environment:

| Environment | Output | API |
|-------------|--------|-----|
| Docker Compose | docker-compose.yml | `AddDockerComposeEnvironment()` |
| Azure | Bicep/ARM templates | `AddAzureEnvironment()` |
| Kubernetes | Helm charts | `AddKubernetesEnvironment()` |

## AppHost Structure

### File-based AppHost (C#)

```
apphost.cs              # Single-file orchestrator
apphost.run.json        # Run configuration
```

### Project-based AppHost (C#)

```xml
<!-- AppHost.csproj -->
<Project Sdk="Aspire.AppHost.Sdk/13.2">
    <PropertyGroup>
        <OutputType>Exe</OutputType>
        <TargetFramework>net10.0</TargetFramework>
    </PropertyGroup>
    <ItemGroup>
        <ProjectReference Include="..\Api\Api.csproj" />
        <ProjectReference Include="..\Web\Web.csproj" />
    </ItemGroup>
</Project>
```

### TypeScript AppHost

```
apphost.ts              # TypeScript orchestrator
.modules/               # Generated SDK (don't edit)
aspire.config.json      # Configuration
package.json            # Node dependencies
tsconfig.json           # TypeScript config
```

## OpenTelemetry for Node.js

When using Aspire with Node.js/TypeScript services, add OpenTelemetry instrumentation:

```typescript
// telemetry.ts — import FIRST in your app entry point
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-grpc';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { resourceFromAttributes } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME } from '@opentelemetry/semantic-conventions';

const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? 'http://localhost:4317';
const resource = resourceFromAttributes({ [ATTR_SERVICE_NAME]: 'api' });

const sdk = new NodeSDK({
    resource,
    traceExporter: new OTLPTraceExporter({ url: otlpEndpoint }),
    metricReader: new PeriodicExportingMetricReader({
        exporter: new OTLPMetricExporter({ url: otlpEndpoint }),
    }),
    instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

Required packages:

```bash
npm install @opentelemetry/api @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-grpc \
  @opentelemetry/exporter-metrics-otlp-grpc
```

## MCP Server Integration

```powershell
# Start the Aspire MCP server (for AI agents)
aspire agent mcp

# List MCP tools from running resources
aspire mcp list

# Call an MCP tool
aspire mcp call <tool-name> --args '{"key": "value"}'
```

The MCP server gives AI agents runtime access to resource status, logs, traces, and commands.

## Troubleshooting

```powershell
aspire doctor                 # Check environment health
aspire --version              # Verify CLI version
aspire cache clear            # Clear cached templates/packages
aspire certs --trust          # Trust HTTPS dev certificates
aspire config list            # Show current configuration
```

## Aspire vs Docker Compose

| Feature | Aspire | Docker Compose |
|---------|--------|----------------|
| Service discovery | Automatic | Manual URL config |
| Dependencies | Code-based `withReference` | YAML `depends_on` |
| Observability | Built-in OpenTelemetry dashboard | Requires Prometheus/Grafana |
| Config injection | Automatic connection strings | Manual env vars |
| Deployment | Same model → Bicep/Helm/Compose | Compose only |

Aspire can also **generate** Docker Compose during `aspire publish`.

## Documentation

- Official docs: <https://aspire.dev>
- CLI reference: <https://aspire.dev/reference/cli/overview/>
- Integrations catalog: <https://aspire.dev/integrations/>
- API reference: <https://aspire.dev/reference/overview/>
- Samples: <https://aspire.dev/reference/samples/>
- GitHub: <https://github.com/microsoft/aspire>
- TypeScript quickstart: <https://aspire.dev/get-started/first-app-typescript-apphost/>
- Add to existing app (TS): <https://aspire.dev/get-started/add-aspire-existing-app-typescript-apphost/>
- JS support in Aspire 13: <https://aspire.dev/whats-new/aspire-13/#javascript-as-a-first-class-citizen>

Use `aspire docs search <topic>` to search docs from the terminal.
