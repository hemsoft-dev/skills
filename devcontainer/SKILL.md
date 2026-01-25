---
name: devcontainer
description: V1.0 - Expert in devcontainer.json configuration, features, lifecycle management, best practices, and troubleshooting for building consistent development environments across all platforms.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the devcontainer directory (path contains 'devcontainer'), verify that history logging occurred.
            
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
            Before stopping, if devcontainer was used (check if any files in devcontainer directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in devcontainer directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Dev Container Expert

Configure, build, and troubleshoot development containers for consistent environments across all platforms.

## Core Concepts

### What is a Dev Container?

A development container is a running Docker container with:

- A complete development environment
- Preconfigured tools, runtimes, and extensions
- Consistent experience across local, cloud, and team setups
- Defined via `.devcontainer/devcontainer.json`

### Key Benefits

- **Consistency**: Same environment for entire team
- **Isolation**: Project dependencies don't interfere with each other
- **Portability**: Works on Windows, macOS, Linux
- **Onboarding**: New developers productive in minutes
- **GitHub Copilot Workspace**: Optimized for AI-powered development

## Configuration Structure

### Basic devcontainer.json

```json
{
  "name": "Project Name",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  
  "customizations": {
    "vscode": {
      "extensions": ["dbaeumer.vscode-eslint"]
    }
  },
  
  "postCreateCommand": "npm install",
  "remoteUser": "vscode"
}
```

### Property Categories

**Required**:

- `name` - Container display name
- `image` OR `dockerFile` OR `build` - Container source

**Common**:

- `features` - Add dev container features
- `customizations` - IDE/editor settings
- `postCreateCommand` - Run after container creation
- `remoteUser` - Non-root user for development

**Advanced**:

- `mounts` - Persistent volumes
- `forwardPorts` - Port management
- `containerEnv` - Environment variables
- `runArgs` - Docker run arguments

## Dev Container Features

### What are Features?

Composable, reusable units that add tools/runtimes to containers.

**Official Features**: <https://containers.dev/features>

**Common Examples**:

```json
{
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "lts"
    },
    "ghcr.io/devcontainers/features/python:1": {
      "version": "3.11"
    },
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/common-utils:2": {
      "installZsh": true,
      "installOhMyZsh": true
    }
  }
}
```

### Feature Selection Strategy

**Prefer Features Over**:

- Custom Dockerfiles for standard tools
- Manual installation scripts
- Complex base images

**Use Custom Dockerfile When**:

- Highly specialized setup required
- Company-specific base image needed
- Legacy dependencies unavailable as features

## Lifecycle Commands

### Execution Order

1. **`onCreateCommand`** - Runs once after container creation
2. **`updateContentCommand`** - Runs on content/config changes
3. **`postCreateCommand`** - Runs after create (most common)
4. **`postStartCommand`** - Runs each time container starts
5. **`postAttachCommand`** - Runs after attaching to container

### Best Practices

```json
{
  "postCreateCommand": "npm install && npm run prepare",
  "postStartCommand": "npm run dev:background",
  "postAttachCommand": "echo 'Welcome to the project!'"
}
```

**Use**:

- `postCreateCommand` - Install dependencies
- `postStartCommand` - Start background services
- `postAttachCommand` - Show welcome message

## Persistent Data

### Shell History

```json
{
  "mounts": [
    "source=devcontainer-zsh-history,target=/home/vscode/.zsh_history,type=volume",
    "source=devcontainer-bash-history,target=/home/vscode/.bash_history,type=volume"
  ]
}
```

### VS Code Server Data

Automatically persisted by mounting:

- `~/.vscode-server/extensions`
- `~/.vscode-server-insiders/extensions`

### Custom Persistent Volumes

```json
{
  "mounts": [
    "source=project-npm-cache,target=/home/vscode/.npm,type=volume",
    "source=project-build-cache,target=/workspace/.next,type=volume"
  ]
}
```

## VS Code Customization

### Extensions

```json
{
  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "GitHub.copilot",
        "GitHub.copilot-chat"
      ]
    }
  }
}
```

**Always Include**:

- Linting/formatting extensions
- Language-specific extensions
- GitHub Copilot for AI assistance

### Settings

```json
{
  "customizations": {
    "vscode": {
      "settings": {
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "terminal.integrated.defaultProfile.linux": "zsh"
      }
    }
  }
}
```

**Best Practices**:

- Set `formatOnSave` for consistency
- Configure terminal defaults
- Set project-specific linting rules

## Port Management

### Forward Ports

```json
{
  "forwardPorts": [3000, 5432]
}
```

### Port Attributes

```json
{
  "portsAttributes": {
    "3000": {
      "label": "Application",
      "onAutoForward": "notify"
    },
    "5432": {
      "label": "PostgreSQL",
      "onAutoForward": "silent"
    }
  }
}
```

**Options**:

- `onAutoForward`: "notify", "silent", "ignore", "openBrowser"
- `elevateIfNeeded`: true/false (for ports < 1024)

## Base Images

### Official Microsoft Images

**Recommended**:

- `mcr.microsoft.com/devcontainers/base:ubuntu` - Ubuntu base
- `mcr.microsoft.com/devcontainers/typescript-node:1-22-bookworm` - Node.js
- `mcr.microsoft.com/devcontainers/python:1-3.11-bookworm` - Python
- `mcr.microsoft.com/devcontainers/go:1-1.21-bookworm` - Go
- `mcr.microsoft.com/devcontainers/dotnet:1-8.0-bookworm` - .NET

**Find More**: <https://mcr.microsoft.com/product/devcontainers/catalog>

### Custom Dockerfile

```json
{
  "name": "Custom Container",
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".",
    "args": {
      "NODE_VERSION": "20"
    }
  }
}
```

## Docker-in-Docker (DinD)

### When to Use

**Required for**:

- Building Docker images inside container
- Running Docker Compose
- Supabase local development
- Container orchestration testing

### Configuration

```json
{
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {
      "version": "latest",
      "moby": true
    }
  }
}
```

**⚠️ Security Note**: DinD requires `--privileged` flag - use judiciously

## Stack-Specific Recipes

### Node.js + TypeScript

```json
{
  "name": "Node.js TypeScript",
  "image": "mcr.microsoft.com/devcontainers/typescript-node:1-20-bookworm",
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode"
      ]
    }
  },
  "postCreateCommand": "npm install"
}
```

### Python + Data Science

```json
{
  "name": "Python Data Science",
  "image": "mcr.microsoft.com/devcontainers/python:1-3.11-bookworm",
  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
      "installZsh": true
    }
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-toolsai.jupyter"
      ]
    }
  },
  "postCreateCommand": "pip install -r requirements.txt"
}
```

### Next.js + Supabase

```json
{
  "name": "Next.js + Supabase",
  "image": "mcr.microsoft.com/devcontainers/typescript-node:1-20-bookworm",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "postCreateCommand": "npm install && npx supabase start",
  "forwardPorts": [3000, 54321],
  "portsAttributes": {
    "3000": {"label": "Next.js"},
    "54321": {"label": "Supabase Studio"}
  }
}
```

## Troubleshooting

### Container Won't Build

**Check**:

1. Docker Desktop running?
2. Check logs: View → Output → Dev Containers
3. Rebuild without cache: F1 → "Rebuild Container Without Cache"
4. Validate JSON: Check `.devcontainer/devcontainer.json` syntax

### Extensions Not Loading

**Solutions**:

1. Add to `customizations.vscode.extensions` array
2. Rebuild container
3. Check extension compatibility with architecture (arm64/amd64)

### Port Forwarding Issues

**Check**:

1. Port not already in use on host
2. Application actually listening on `0.0.0.0` not `localhost`
3. Firewall/antivirus blocking port

### Slow File Operations (Windows/macOS)

**Solutions**:

1. Clone in WSL2 (Windows) or VM (macOS)
2. Use named volumes for dependencies: `node_modules`, `.next`, etc.
3. Adjust bind mount `consistency`: `cached` or `delegated`

## Resources

- **Specification**: <https://containers.dev/>
- **Features Catalog**: <https://containers.dev/features>
- **Templates**: <https://containers.dev/templates>
- **VS Code Docs**: <https://code.visualstudio.com/docs/devcontainers/containers>
- **GitHub Copilot Workspace**: <https://github.com/features/copilot>
