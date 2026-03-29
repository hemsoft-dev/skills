---
name: aspire
description: "V1.0 - Expert in .NET Aspire 13.x distributed app orchestration, AppHost composition, Aspire CLI, integrations, dashboard, deployment, and AI agent workflows. Use when creating, running, debugging, or deploying Aspire apps."
---

# Aspire

Expert in .NET Aspire — the code-first tool for composing, debugging, and deploying distributed applications.

## Key Concepts

- **AppHost**: The orchestrator project that defines your distributed app's architecture in code. Uses `Aspire.AppHost.Sdk`.
- **Service Defaults**: Shared configuration (OpenTelemetry, health checks, resilience) applied to all service projects.
- **Integrations**: NuGet packages that add resources (Postgres, Redis, RabbitMQ, Azure services) to the AppHost.
- **Dashboard**: Built-in web UI for logs, traces, metrics, and resource status at `https://localhost:{port}`.
- **Aspire CLI**: Cross-platform CLI (`aspire`) for creating, running, managing, and publishing Aspire apps.

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

Installs to `~/.aspire/bin/aspire`. Requires .NET SDK 10.0.100+.

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

### Minimal AppHost (C#)

```csharp
// AppHost.csproj must use: <Project Sdk="Aspire.AppHost.Sdk/13.1">
var builder = DistributedApplication.CreateBuilder(args);

var db = builder.AddPostgres("db");
var api = builder.AddProject<Projects.Api>("api")
    .WithReference(db);

builder.AddProject<Projects.Web>("web")
    .WithReference(api);

builder.Build().Run();
```

### Single-File AppHost

```csharp
// apphost.cs — no .csproj needed, aspire init can create this
var builder = DistributedApplication.CreateBuilder(args);
var api = builder.AddProject("api", "../Api/Api.csproj");
builder.Build().Run();
```

### Adding Common Resources

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

### Multi-Language Support

```csharp
// Python
builder.AddPythonApp("worker", "../worker", "main.py")
    .WithReference(db);

// Node.js / npm
builder.AddNpmApp("frontend", "../frontend")
    .WithReference(api);

// Generic executable
builder.AddExecutable("tool", "mytool", "../tools")
    .WithArgs("--port", "8080");

// Docker container
builder.AddContainer("service", "myimage", "latest")
    .WithHttpEndpoint(targetPort: 8080);
```

### Service Discovery & References

```csharp
// WithReference wires up service discovery automatically
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
    .WithDataVolume("pg-data");  // Named volume persists across restarts
```

## Common Workflows

### Create New Project

```powershell
aspire new aspire-starter     # Interactive template selection
aspire new aspire-starter -n MyApp --output ./myapp
```

### Add Aspire to Existing Project

```powershell
aspire init                   # Analyzes solution, adds AppHost
```

### Development Loop

```powershell
aspire run                    # Start everything + dashboard
# OR for background:
aspire start                  # Start in background
aspire describe               # Check resource status
aspire logs api               # Stream logs from specific resource
aspire stop                   # Stop when done
```

### Agent-Driven Development

```powershell
# Set up AI agent environment
aspire agent init             # Creates skill file + MCP server config

# Background execution for agents
aspire start --isolated       # Isolated parallel worktrees
aspire wait api --status healthy
aspire describe --format Json # Structured output for agents
aspire logs api --format Json # Structured log output
```

### CI/CD Pipeline

```powershell
aspire restore                # Restore + generate SDK code
aspire publish                # Generate Bicep/Helm/docker-compose
aspire deploy                 # Deploy to targets
```

### Adding Integrations

```powershell
aspire add redis              # Add Redis integration
aspire add postgres           # Add PostgreSQL integration
aspire add                    # Browse available integrations interactively
```

## Deployment Targets

Aspire publish generates artifacts based on the deployment environment resource:

| Environment | Output | API |
|-------------|--------|-----|
| `AzureEnvironmentResource` | Bicep/ARM templates | `builder.AddAzureEnvironment()` |
| `DockerComposeEnvironmentResource` | docker-compose.yml | `builder.AddDockerComposeEnvironment()` |
| `KubernetesEnvironmentResource` | Helm charts | `builder.AddKubernetesEnvironment()` |

## Aspire SDK in Project Files

```xml
<!-- AppHost .csproj -->
<Project Sdk="Aspire.AppHost.Sdk/13.1">
    <PropertyGroup>
        <OutputType>Exe</OutputType>
        <TargetFramework>net10.0</TargetFramework>
    </PropertyGroup>

    <!-- Projects are orchestrated, not referenced normally -->
    <ItemGroup>
        <ProjectReference Include="..\Api\Api.csproj" />
        <ProjectReference Include="..\Web\Web.csproj" />
    </ItemGroup>
</Project>
```

To exclude a project from Aspire orchestration:

```xml
<ProjectReference Include="..\Shared\Shared.csproj" IsAspireProjectResource="false" />
```

To customize generated type names (when projects share the same name):

```xml
<ProjectReference Include="..\Svc1\Api.csproj" AspireProjectMetadataTypeName="Service1Api" />
<ProjectReference Include="..\Svc2\Api.csproj" AspireProjectMetadataTypeName="Service2Api" />
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

## Documentation

- Official docs: <https://aspire.dev>
- CLI reference: <https://aspire.dev/reference/cli/overview/>
- Integrations catalog: <https://aspire.dev/integrations/>
- API reference: <https://aspire.dev/reference/overview/>
- Samples: <https://aspire.dev/reference/samples/>
- GitHub: <https://github.com/microsoft/aspire>

Use `aspire docs search <topic>` to search docs from the terminal.
