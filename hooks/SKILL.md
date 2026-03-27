---
name: hooks
description: "V1.0 - Commands: lookup, suggest, configure, explain. Expert knowledge base on GitHub Copilot hooks — types, configuration, implementation patterns across projects, and best practices. Use when working with Copilot hooks, agent hooks, Git hooks, session hooks, or SKILL.md hook frontmatter."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the hooks directory (path contains 'hooks'), verify that history logging occurred.
            
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
            Before stopping, if hooks was used (check if any files in hooks directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in hooks directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Hooks — GitHub Copilot Hooks Expert

Expert knowledge base on every type of hook in the GitHub Copilot ecosystem. Use this skill to look up hook types, get configuration examples, suggest the right hook for a task, or explain how hooks work across different project types.

## Commands

| Command | Purpose |
| --- | --- |
| `lookup` | Find the right hook type for a specific need |
| `suggest` | Recommend hooks to add to a project or skill |
| `configure` | Generate correct hook configuration for a target project |
| `explain` | Deep-dive explanation of how a specific hook type works |

## The Three Hook Ecosystems in Copilot

There are **three distinct hook systems** that developers conflate. Understanding the boundaries is critical.

| # | System | Where Configured | When It Runs | Runner |
| --- | --- | --- | --- | --- |
| 1 | **Git Hooks** | `.git/hooks/` or `.husky/` | Git events (commit, push, merge) | Git / Husky |
| 2 | **Copilot Coding-Agent Hooks** | `.github/hooks/hooks.json` | Copilot agent lifecycle events | GitHub Copilot (cloud or CLI) |
| 3 | **SKILL.md Frontmatter Hooks** | SKILL.md `hooks:` YAML | Agent tool use and session events | Claude Code / agent runtime |

---

## 1. Git Hooks (Traditional)

### What They Are

Git hooks are scripts that Git executes before or after events such as `commit`, `push`, and `merge`. They live in `.git/hooks/` (or `.husky/_/` when using Husky).

### Available Git Hook Types

| Hook | Trigger | Common Use |
| --- | --- | --- |
| `pre-commit` | Before a commit is created | Lint, format, run quick tests |
| `prepare-commit-msg` | After default message, before editor opens | Auto-fill commit message templates |
| `commit-msg` | After message is entered | Enforce conventional commits format |
| `post-commit` | After commit is created | Notifications, logging |
| `pre-push` | Before push to remote | Run full test suite, prevent force-push |
| `pre-rebase` | Before rebase starts | Prevent rebasing published commits |
| `post-merge` | After a merge completes | Reinstall dependencies, rebuild |
| `post-checkout` | After checkout/switch | Rebuild, clear caches |
| `pre-receive` | Server-side, before accepting push | Enforce policies (server hook) |
| `post-receive` | Server-side, after accepting push | Deploy, notify CI (server hook) |

### Implementation by Project Type

#### Node.js / JavaScript / TypeScript Projects

**Recommended tool: Husky + lint-staged**

```json
// package.json
{
  "scripts": {
    "prepare": "husky"
  },
  "lint-staged": {
    "*.{js,ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{md,json,yaml}": ["prettier --write"]
  }
}
```

```sh
# .husky/pre-commit
npx lint-staged
```

**Setup commands:**

```sh
npm install --save-dev husky lint-staged
npx husky init
echo "npx lint-staged" > .husky/pre-commit
```

#### Python Projects

**Recommended tool: pre-commit framework**

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
  - repo: https://github.com/psf/black
    rev: 24.4.2
    hooks:
      - id: black
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.8
    hooks:
      - id: ruff
        args: [--fix]
```

**Setup commands:**

```sh
pip install pre-commit
pre-commit install
pre-commit run --all-files  # initial run
```

#### .NET / C# Projects

**Recommended tool: Husky.Net**

```sh
dotnet tool install --global Husky
dotnet husky install
dotnet husky add pre-commit -c "dotnet format --verify-no-changes"
```

Or manual `.git/hooks/pre-commit`:

```sh
#!/bin/sh
dotnet format --verify-no-changes
if [ $? -ne 0 ]; then
  echo "Code formatting issues detected. Run 'dotnet format' to fix."
  exit 1
fi
```

#### PowerShell-Heavy Projects

**Direct `.git/hooks/pre-commit` wrapper:**

```sh
#!/bin/sh
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ".git/hooks/pre-commit.ps1"
POWERSHELL_EXIT=$?

pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ".git/hooks/pre-commit-markdown.ps1"
MARKDOWN_EXIT=$?

if [ $POWERSHELL_EXIT -ne 0 ] || [ $MARKDOWN_EXIT -ne 0 ]; then
  exit 1
fi
exit 0
```

#### Rust Projects

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: cargo-fmt
        name: cargo fmt
        entry: cargo fmt --
        language: system
        types: [rust]
      - id: cargo-clippy
        name: cargo clippy
        entry: cargo clippy -- -D warnings
        language: system
        types: [rust]
        pass_filenames: false
```

#### Go Projects

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: go-fmt
        name: go fmt
        entry: gofmt -l -w
        language: system
        types: [go]
      - id: go-vet
        name: go vet
        entry: go vet ./...
        language: system
        pass_filenames: false
```

### Husky vs Core Git Hooks — Key Trap

When Husky is installed, Git's `core.hooksPath` is set to `.husky/_`. This means `.git/hooks/pre-commit` is **never executed**. If you need both:

1. Wire your custom hook **inside** `.husky/pre-commit`
2. Or call `.git/hooks/pre-commit-markdown.ps1` from the Husky hook

The `copilot-hooks` skill's install script detects this and handles it automatically.

---

## 2. Copilot Coding-Agent Hooks (GitHub)

### What They Are

These are hooks that run during the **GitHub Copilot coding agent lifecycle** — the cloud-based agent that opens PRs, or the CLI agent (`copilot` / `gh copilot`). Configured via `.github/hooks/hooks.json`.

### Configuration File

**Location:** `.github/hooks/hooks.json` at the repository root.

```json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [
      {
        "type": "command",
        "windows": "sh ./.github/scripts/auto-commit.sh",
        "bash": ".github/scripts/auto-commit.sh",
        "timeoutSec": 10
      }
    ],
    "Stop": [
      {
        "type": "command",
        "windows": "sh ./.github/scripts/auto-commit.sh",
        "bash": ".github/scripts/auto-commit.sh",
        "timeoutSec": 10
      }
    ]
  }
}
```

### Available Copilot Agent Hook Events

| Event | When It Fires | Typical Use |
| --- | --- | --- |
| `sessionEnd` | Copilot agent session is ending | Auto-commit, push, cleanup |
| `Stop` | Agent is stopping (legacy/compat name) | Same as sessionEnd — register both for compatibility |

### Hook Entry Fields

| Field | Required | Description |
| --- | --- | --- |
| `type` | Yes | Must be `"command"` |
| `bash` | Yes* | Command to run on Linux/macOS |
| `windows` | No | Command to run on Windows (overrides `bash`) |
| `timeoutSec` | No | Max seconds before the hook is killed (default varies) |

### Critical Implementation Rules

1. **Register both `Stop` and `sessionEnd`** — Some clients fire `Stop`, others fire `sessionEnd`. Wire the same command under both for compatibility.
2. **Use `--no-verify` on commits** — Prevents recursive pre-commit failures during session shutdown.
3. **On Windows, use `sh` prefix** — `"windows": "sh ./.github/scripts/auto-commit.sh"` avoids routing through `C:\Windows\System32\bash.exe` which depends on WSL.
4. **Disable interactive prompts** — Set `GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE=Never`, and `GIT_ASKPASS=echo`.
5. **Guard against duplicate invocations** — Both `Stop` and `sessionEnd` may fire in some builds. Use a lock file with a short time window.
6. **Never block session termination** — Exit 0 even on failure. Log errors as informational output.
7. **Use fast-fail SSH options** — `ssh -o BatchMode=yes -o ConnectTimeout=5` prevents hanging on credentials negotiation.

### Auto-Commit Script Pattern

The proven pattern (used by `copilot-hooks` skill):

```sh
#!/bin/sh
# Guard duplicate invocation within 30s window
LOCK_FILE="/tmp/copilot-session-hook-$(git rev-parse --show-toplevel 2>/dev/null | tr '/:\\' '_').lock"
if [ -f "$LOCK_FILE" ]; then
    NOW=$(date +%s); LAST=$(cat "$LOCK_FILE" 2>/dev/null || echo 0)
    [ $((NOW - LAST)) -lt 30 ] && echo "Skipped (duplicate)" && exit 0
fi
date +%s > "$LOCK_FILE" || true

export GIT_TERMINAL_PROMPT=0
export GCM_INTERACTIVE=Never
[ -z "$GIT_ASKPASS" ] && export GIT_ASKPASS=echo

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0

git add -A && git commit -m "auto-commit: $(date '+%Y-%m-%d %H:%M:%S')" --no-verify
BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
REMOTE=$(git remote | head -n 1)
[ -n "$REMOTE" ] && [ -n "$BRANCH" ] && \
  GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5" git push 2>/dev/null

exit 0
```

---

## 3. SKILL.md Frontmatter Hooks (Agent Skills)

### What They Are

Hooks defined in the YAML frontmatter of a `SKILL.md` file. These are processed by the **agent runtime** (Claude Code, Copilot CLI agent, etc.) and fire during the AI session, not during Git operations.

### Available Hook Events

| Event | When It Fires | Purpose |
| --- | --- | --- |
| `PostToolUse` | After the agent uses a tool (read, write, edit, terminal, etc.) | Validate output, enforce logging, check quality |
| `Stop` | Before the agent ends the session | Ensure work is saved, history logged, retrospective done |

### Hook Configuration Structure

```yaml
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"       # Regex matching tool names
      hooks:
        - type: prompt                   # "prompt" is the only supported type
          prompt: |
            Instructions for the agent to follow after the matched tool is used.
  Stop:
    - matcher: "*"                       # Wildcard matches all
      hooks:
        - type: prompt
          prompt: |
            Instructions to execute before the session ends.
```

### Hook Entry Fields

| Field | Required | Description |
| --- | --- | --- |
| `matcher` | Yes | Regex or `"*"` wildcard to match tool names or events |
| `hooks[].type` | Yes | Must be `"prompt"` — injects a prompt into the agent's context |
| `hooks[].prompt` | Yes | The instruction text given to the agent |

### Matcher Patterns

| Pattern | Matches |
| --- | --- |
| `"*"` | Everything |
| `"Read\|Write\|Edit"` | Read, Write, or Edit tools |
| `"Terminal"` | Terminal/shell tool usage |
| `"Read"` | Only file read operations |
| `"Write\|Edit"` | Only file modification operations |

### Common SKILL.md Hook Patterns

#### History Tracking (Most Common)

```yaml
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the {skill-name} directory,
            verify that history logging occurred.
            Check if History/{YYYY-MM-DD}.md exists with format:
            "## HH:MM - {Action Taken}" and one-line summary.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, verify history entry exists.
            If missing: return {"decision": "block", "reason": "..."}
            If present: return {"decision": "approve"}
```

#### Quality Gate Hook

```yaml
hooks:
  PostToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            After writing or editing code, verify:
            1. No TODO comments were left unresolved
            2. All functions have documentation
            3. Error handling is present
            If issues found, list them and suggest fixes.
```

#### Auto-Test Hook

```yaml
hooks:
  PostToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            After modifying source code, check if corresponding tests exist.
            If test file exists, remind to run tests.
            If no tests exist, suggest creating them.
```

#### Commit Message Enforcement Hook

```yaml
hooks:
  PostToolUse:
    - matcher: "Terminal"
      hooks:
        - type: prompt
          prompt: |
            If a git commit was just executed, verify the commit message
            follows conventional commits format: type(scope): description
            Valid types: feat, fix, docs, style, refactor, test, chore
```

### Stop Hook Response Format

Stop hooks can return structured decisions:

```json
{"decision": "approve"}
```

```json
{"decision": "block", "reason": "Explanation of why the session should not end yet."}
```

---

## Decision Matrix — Which Hook System to Use

| Goal | Hook System | Configuration |
| --- | --- | --- |
| Lint code before every commit | Git Hooks | `.husky/pre-commit` or `.git/hooks/pre-commit` |
| Enforce commit message format | Git Hooks | `.git/hooks/commit-msg` |
| Auto-commit when Copilot session ends | Copilot Agent Hooks | `.github/hooks/hooks.json` → `sessionEnd` |
| Track skill usage history | SKILL.md Hooks | `hooks.PostToolUse` in frontmatter |
| Block agent from stopping without saving | SKILL.md Hooks | `hooks.Stop` in frontmatter |
| Run tests before push | Git Hooks | `.git/hooks/pre-push` |
| Validate agent output quality | SKILL.md Hooks | `hooks.PostToolUse` matcher `"Write\|Edit"` |
| Auto-push after Copilot agent work | Copilot Agent Hooks | `.github/hooks/hooks.json` → `sessionEnd` |
| Rebuild after branch switch | Git Hooks | `.git/hooks/post-checkout` |

---

## Quick Setup Recipes

### Recipe: Add Copilot Session-End Auto-Commit to Any Repo

1. Create `.github/hooks/hooks.json` with both `Stop` and `sessionEnd` entries
2. Create `.github/scripts/auto-commit.sh` with the proven pattern above
3. Restart the Copilot session (hooks are loaded at session start)

### Recipe: Add Pre-Commit Markdown Linting to Any Repo

Use the `copilot-hooks` skill:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File copilot-hooks/scripts/1-Install-CopilotHooks.ps1
```

### Recipe: Add History Tracking Hooks to a SKILL.md

Copy the `PostToolUse` + `Stop` hook block from the Common SKILL.md Hook Patterns section above, replacing `{skill-name}` with the actual skill name.

---

## Troubleshooting

| Problem | Cause | Fix |
| --- | --- | --- |
| Pre-commit hook not running | Husky overrides `core.hooksPath` | Wire hook inside `.husky/pre-commit` instead |
| Session-end hook not firing | Config loaded at session start | Restart the Copilot session |
| `bash.exe` error on Windows | Routes through WSL bash | Use `"windows": "sh ./.github/scripts/..."` |
| Duplicate auto-commits | Both `Stop` and `sessionEnd` fire | Add lock-file guard with 30s window |
| Push hangs on session end | Waiting for SSH credentials | Set `BatchMode=yes`, `ConnectTimeout=5` |
| SKILL.md hooks not triggering | Frontmatter YAML syntax error | Validate YAML indentation, use `\|` for multiline |
| Hook blocked but session ended anyway | Agent runtime ignores block | This is expected — block is advisory in some runtimes |

## Key References

- Agent Skills Specification: <https://agentskills.io/specification>
- GitHub Docs — Custom Instructions: <https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot>
- Husky: <https://typicode.github.io/husky/>
- pre-commit framework: <https://pre-commit.com/>
- Git Hooks documentation: <https://git-scm.com/docs/githooks>
- Copilot Hooks skill (local): See `copilot-hooks/SKILL.md` in this skills repo
