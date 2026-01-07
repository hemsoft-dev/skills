---
name: devcontainer-manager
description: V1.1 - Expert in architecting and maintaining high-performance, multi-stack .devcontainer environments with support for Bun, Supabase (DinD), and GitHub Copilot Workspace.
---

# Dev Container Manager

Manage and optimize development containers for seamless local and cloud-based (GitHub Copilot Workspace) development.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Core Principles

1. **Feature-First Modularity**: Prefer [Dev Container Features](https://containers.dev/features) over custom Dockerfiles. This allows for "mix-and-match" stacks (e.g., Bun + Python + Go) without maintaining complex base images.
2. **Environment Parity**: Ensure the container environment matches production-like constraints while providing developer-friendly tools.
3. **Cloud-Agent Readiness**: Optimize for GitHub Copilot Workspace by ensuring the container can autonomously run builds and tests.

## Stack-Specific Recipes

### Bun & Next.js
- **Feature**: `ghcr.io/devcontainers/features/node:1` (as a base if needed) or `ghcr.io/devcontainers/features/common-utils:1`.
- **Bun Installation**: Use `ghcr.io/devcontainers/features/bun:1` or install via `postCreateCommand`.
- **Performance**: On Windows, ensure the project is in the WSL 2 filesystem.
- **HMR**: Ensure `watch` settings in `next.config.js` are compatible with container polling if filesystem events are missed.

### Supabase (Local Development)
- **Requirement**: Docker-in-Docker (DinD) is mandatory for the Supabase CLI to manage its own containers.
- **Feature**: `ghcr.io/devcontainers/features/docker-in-docker:2`.
- **Lifecycle**: Use `postCreateCommand` to run `supabase start` or `supabase db reset`.

### GitHub Copilot Workspace Integration
- **Custom Instructions**: Do NOT use the `github.copilot.chat.codeGeneration.instructions` setting in `devcontainer.json` as it is being deprecated. Instead, place a `copilot-instructions.md` file in the `.github/` or `.vscode/` directory. VS Code and Copilot will detect it automatically.
- **Verification**: Ensure `postCreateCommand` or `updateContentCommand` includes `bun install && bun run build` so the agent can verify its own changes.

## Best Practices

- **Non-Root User**: Always use a non-root user (default: `vscode`).
- **Persistence**: Use named volumes to persist shell history and VS Code server data:
  ```json
  "mounts": [
    "source=devcontainer-history,target=/home/vscode/.bash_history,type=volume",
    "source=devcontainer-zsh-history,target=/home/vscode/.zsh_history,type=volume"
  ]
  ```
- **Line Endings**: Include a `.gitattributes` file in the repo root to force `* text=auto eol=lf`.
- **Extensions**: Pre-install essential extensions via `customizations.vscode.extensions`.
- **Host-Side Validation**: Avoid setting `editor.defaultFormatter` in `devcontainer.json` if the extension is not installed on the host machine, as it triggers JSON schema warnings. The `extensions` list ensures it is available in the container; users can set it as the default once the container is active or install it locally to sync validation.

## Workflow

1. **Analyze**: Identify the project's runtime (Bun, Node, .NET), database (Supabase, Postgres), and tools.
2. **Scaffold**: Create `.devcontainer/devcontainer.json`.
3. **Configure Features**: Add required features (DinD, Bun, etc.).
4. **Set Lifecycle Scripts**: Define `postCreateCommand` for dependency installation.
5. **Verify**: Ensure the container builds and the environment is functional.
