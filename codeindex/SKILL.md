---
name: codeindex
description: "V1.0 - Commands: Init, Index, Query, Status, Watch, UI. Use when working with the local Code Index install, reducing token usage with indexed code retrieval, or explaining the Windows-specific Code Index setup and limitations on this machine."
compatibility: "Requires C:\\Users\\User\\.local\\bin\\codeindex.exe. This local Windows build works as a CLI but currently falls back to mock embeddings, and MCP integration with Copilot CLI/OpenCode is not reliable here."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the codeindex directory (path contains 'codeindex'), verify that history logging occurred.
            
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
            Before stopping, if codeindex was used (check if any files in codeindex directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in codeindex directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Code Index

Use this skill when the user wants to explore a repository through the local `codeindex` install instead of spending tokens on broad file dumps, noisy grep output, or repeated full-file reads.

## Local state on this machine

- Installed CLI: `C:\Users\User\.local\bin\codeindex.exe`
- Installed MCP binary: `C:\Users\User\.local\bin\codeindex-mcp-server.exe`
- Installed version: `codeindex 0.1.0`
- This Windows build was patched locally so the CLI works here.
- Local ONNX embeddings are **not** active in this build. It falls back to a deterministic mock embedding provider, so free-text semantic search is weaker than structured lookups.
- MCP wiring to GitHub Copilot CLI and OpenCode was tested during setup and removed again because both clients timed out during startup probing. Treat `codeindex` here as a **CLI-first tool**, not a stable shared MCP backend.

## Why use it to save tokens

`codeindex` pre-indexes files, regions, and dependency relationships into `.codeindex\index.db`, then returns targeted results instead of forcing the model to inspect large parts of the repo.

Use it to:

1. Find exact definitions with `:symbol`
2. List indexed regions in a file with `:file`
3. Expand dependency context with `:deps`
4. Narrow scope before reading code bodies

For the lowest token usage, prefer:

```powershell
codeindex query "<query>" --no-code --format compact
```

That returns pointers, signatures, and ranking without injecting raw source unless you actually need it.

## Preferred workflow

From the repository root:

```powershell
codeindex init
codeindex index
codeindex status
```

Refresh while actively editing:

```powershell
codeindex watch
```

Token-efficient query patterns:

```powershell
codeindex query ":symbol LoginHandler" --top 3 --no-code --format compact
codeindex query ":file src/auth.rs" --no-code --format compact
codeindex query ":deps src/auth.rs::login" --depth 2 --no-code --format compact
```

Only use free-text search after structured lookups:

```powershell
codeindex query "where is authentication handled" --top 5 --no-code --format compact
```

## Guidance for this environment

When helping the user:

1. Prefer `:symbol`, then `:file`, then `:deps`, then natural language.
2. Use `--no-code` first; only drop it when the top results still need raw source.
3. Use `status` before assuming an index exists.
4. If the repo is uninitialized, run `init` and `index` from the repo root.
5. Explain that natural-language queries on this machine are less trustworthy because the build is using mock embeddings instead of the intended local ONNX model.

## Commands worth recommending

| Command | Best use |
|---|---|
| `codeindex init` | Create `.codeindex\` config/state in a repo |
| `codeindex index` | Build or refresh the index |
| `codeindex status` | Confirm the index exists |
| `codeindex stats` | Inspect index size and region counts |
| `codeindex query` | Primary token-saving entry point |
| `codeindex watch` | Keep an active repo indexed during edits |
| `codeindex ui` | Inspect results interactively |
| `codeindex gc` | Clean stale index data |

## What not to recommend here

- Do **not** describe this install as a reliable Copilot CLI/OpenCode MCP integration.
- Do **not** oversell natural-language semantic retrieval on this machine.
- Do **not** send huge repo snapshots when `codeindex query` can narrow the target first.

## Escalation guidance

If the user specifically wants a robust MCP-shared indexing backend for Copilot CLI or OpenCode, explain that `codeindex` was tested here and still timed out in both clients. For MCP-first workflows, suggest evaluating `seek`, `ygrep`, or `Zoekt + zoekt-mcp` instead.
