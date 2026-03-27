---
name: hooks
description: "V1.0 - Commands: lookup, suggest, configure, explain. Expert knowledge base on Copilot and Claude Code agent hooks — all 28+ hook events, 4 hook types (command, http, prompt, agent), matchers, decision control, SKILL.md frontmatter hooks, .github/hooks/hooks.json, and settings.json hook configuration. Use when working with agent hooks, session hooks, pre/post tool use hooks, stop hooks, or any agent lifecycle automation."
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

# Hooks — Copilot & Claude Code Agent Hooks Expert

Expert knowledge base on every type of **agent hook** in the Copilot and Claude Code ecosystem. This skill covers SKILL.md frontmatter hooks, `.github/hooks/hooks.json` Copilot coding-agent hooks, and Claude Code settings-based hooks. It does NOT cover Git hooks (pre-commit, etc.) — see the `copilot-hooks` skill for those.

## Commands

| Command | Purpose |
| --- | --- |
| `lookup` | Find the right hook event for a specific need |
| `suggest` | Recommend hooks to add to a project or skill |
| `configure` | Generate correct hook configuration for a target |
| `explain` | Deep-dive on how a specific hook event or type works |

## Where Agent Hooks Are Defined

There are three distinct places to define agent hooks. Each has different scope and use cases.

| Location | Scope | Format | Use Case |
| --- | --- | --- | --- |
| **SKILL.md frontmatter** | Active while the skill is in use | YAML `hooks:` block | History tracking, quality gates, stop guards on a per-skill basis |
| **`.github/hooks/hooks.json`** | Repository-wide Copilot coding agent | JSON | Session-end auto-commit, auto-push, cleanup |
| **Claude Code settings** | User, project, or local scope | JSON in `settings.json` | Pre-tool-use validation, permission automation, linting, security policies |

### SKILL.md Frontmatter Hooks

Defined in the YAML frontmatter of a `SKILL.md` file. Scoped to the skill's lifetime — only active when the skill is being used. All hook events are supported. For subagents, `Stop` hooks are automatically converted to `SubagentStop`.

### `.github/hooks/hooks.json` (Copilot Coding Agent)

A JSON file at the repo root that registers shell commands on Copilot agent lifecycle events like `sessionEnd` and `Stop`. These fire when the cloud-based Copilot coding agent (or the CLI agent) ends a session.

### Claude Code Settings Hooks

Defined in JSON settings files at various scopes:

| File | Scope | Shareable |
| --- | --- | --- |
| `~/.claude/settings.json` | All your projects | No (local to machine) |
| `.claude/settings.json` | Single project | Yes (commit to repo) |
| `.claude/settings.local.json` | Single project | No (gitignored) |
| Managed policy settings | Organization-wide | Yes (admin-controlled) |
| Plugin `hooks/hooks.json` | When plugin is enabled | Yes (bundled with plugin) |

---

## The Four Hook Types

Every hook handler is one of four types:

| Type | How It Works | Best For |
| --- | --- | --- |
| `command` | Runs a shell command; receives JSON on stdin, returns via exit code + stdout | Scripts, linting, auto-commit, file ops |
| `http` | POSTs JSON to a URL; reads response body | External services, webhooks, APIs |
| `prompt` | Single-turn LLM evaluation; returns `{ok: true/false}` | Quick quality checks, stop validation |
| `agent` | Spawns a subagent with tool access (Read, Grep, Glob); up to 50 turns | Deep verification requiring file inspection |

### Command Hook Fields

| Field | Required | Description |
| --- | --- | --- |
| `type` | Yes | `"command"` |
| `command` | Yes | Shell command to execute |
| `timeout` | No | Seconds before canceling (default: 600) |
| `async` | No | If `true`, runs in background without blocking |
| `shell` | No | `"bash"` (default) or `"powershell"` (Windows) |
| `statusMessage` | No | Custom spinner message while hook runs |
| `once` | No | If `true`, runs only once per session then removed (skills only) |

### HTTP Hook Fields

| Field | Required | Description |
| --- | --- | --- |
| `type` | Yes | `"http"` |
| `url` | Yes | URL to POST to |
| `timeout` | No | Seconds before canceling (default: 600) |
| `headers` | No | Key-value pairs; supports `$VAR_NAME` interpolation |
| `allowedEnvVars` | No | List of env vars allowed in header interpolation |

### Prompt Hook Fields

| Field | Required | Description |
| --- | --- | --- |
| `type` | Yes | `"prompt"` |
| `prompt` | Yes | Prompt text; use `$ARGUMENTS` for hook input JSON |
| `model` | No | Model to use (defaults to fast model) |
| `timeout` | No | Seconds (default: 30) |

### Agent Hook Fields

| Field | Required | Description |
| --- | --- | --- |
| `type` | Yes | `"agent"` |
| `prompt` | Yes | Prompt describing what to verify; use `$ARGUMENTS` |
| `model` | No | Model to use (defaults to fast model) |
| `timeout` | No | Seconds (default: 60) |

---

## All 28 Hook Events

### Quick Reference Table

| Event | When It Fires | Can Block? | Supports Matchers? |
| --- | --- | --- | --- |
| `SessionStart` | Session begins or resumes | No | Yes (`startup`, `resume`, `clear`, `compact`) |
| `InstructionsLoaded` | CLAUDE.md or rules file loaded | No | Yes (`session_start`, `nested_traversal`, etc.) |
| `UserPromptSubmit` | User submits a prompt | Yes | No |
| `PreToolUse` | Before a tool call executes | Yes (allow/deny/ask) | Yes (tool name: `Bash`, `Edit`, `Write`, etc.) |
| `PermissionRequest` | Permission dialog appears | Yes (allow/deny) | Yes (tool name) |
| `PostToolUse` | After a tool succeeds | No (feedback only) | Yes (tool name) |
| `PostToolUseFailure` | After a tool fails | No (feedback only) | Yes (tool name) |
| `Notification` | Agent sends a notification | No | Yes (`permission_prompt`, `idle_prompt`, etc.) |
| `SubagentStart` | Subagent spawned | No (context only) | Yes (agent type) |
| `SubagentStop` | Subagent finishes | Yes | Yes (agent type) |
| `TaskCreated` | Task being created | Yes | No |
| `TaskCompleted` | Task being marked complete | Yes | No |
| `Stop` | Agent finishes responding | Yes | No |
| `StopFailure` | Turn ends due to API error | No | Yes (error type) |
| `TeammateIdle` | Teammate about to go idle | Yes | No |
| `ConfigChange` | Config file changes | Yes (except policy) | Yes (config source) |
| `CwdChanged` | Working directory changes | No | No |
| `FileChanged` | Watched file changes on disk | No | Yes (filename) |
| `WorktreeCreate` | Worktree being created | Yes (returns path) | No |
| `WorktreeRemove` | Worktree being removed | No | No |
| `PreCompact` | Before context compaction | No | Yes (`manual`, `auto`) |
| `PostCompact` | After compaction completes | No | Yes (`manual`, `auto`) |
| `SessionEnd` | Session terminates | No | Yes (exit reason) |
| `Elicitation` | MCP server requests input | Yes | Yes (MCP server name) |
| `ElicitationResult` | User responds to elicitation | Yes | Yes (MCP server name) |

### Hook Type Support by Event

Not all events support all four hook types:

**All four types (command, http, prompt, agent):**
`PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `Stop`, `SubagentStop`, `UserPromptSubmit`, `TaskCreated`, `TaskCompleted`

**Command and HTTP only:**
`ConfigChange`, `CwdChanged`, `Elicitation`, `ElicitationResult`, `FileChanged`, `InstructionsLoaded`, `Notification`, `PostCompact`, `PreCompact`, `SessionEnd`, `StopFailure`, `SubagentStart`, `TeammateIdle`, `WorktreeCreate`, `WorktreeRemove`

**Command only:**
`SessionStart`

---

## Exit Code Behavior

| Exit Code | Meaning | Behavior |
| --- | --- | --- |
| **0** | Success | Action proceeds; stdout parsed for JSON |
| **2** | Blocking error | Action blocked; stderr fed to agent as error |
| **Other** | Non-blocking error | stderr shown in verbose mode; execution continues |

---

## Matcher Patterns

The `matcher` field is a regex that filters when hooks fire. Use `"*"`, `""`, or omit entirely to match everything.

| Event | What Matcher Filters | Example Values |
| --- | --- | --- |
| `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest` | Tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| `SessionStart` | How session started | `startup`, `resume`, `clear`, `compact` |
| `SessionEnd` | Why session ended | `clear`, `resume`, `logout`, `other` |
| `Notification` | Notification type | `permission_prompt`, `idle_prompt` |
| `SubagentStart`, `SubagentStop` | Agent type | `Bash`, `Explore`, `Plan` |
| `ConfigChange` | Config source | `user_settings`, `project_settings`, `skills` |
| `FileChanged` | Filename (basename) | `.envrc`, `.env` |
| `StopFailure` | Error type | `rate_limit`, `server_error` |
| `InstructionsLoaded` | Load reason | `session_start`, `nested_traversal` |
| `Elicitation`, `ElicitationResult` | MCP server name | Your configured server names |
| `PreCompact`, `PostCompact` | Trigger | `manual`, `auto` |

Events that **do not support matchers** (always fire): `UserPromptSubmit`, `Stop`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`, `CwdChanged`.

### Matching MCP Tools

MCP tools follow the pattern `mcp__<server>__<tool>`. Use regex:

- `mcp__memory__.*` — all tools from memory server
- `mcp__.*__write.*` — any write tool from any server

---

## Decision Control Patterns

Different events use different mechanisms to control behavior:

| Events | Pattern | Key Fields |
| --- | --- | --- |
| `UserPromptSubmit`, `PostToolUse`, `PostToolUseFailure`, `Stop`, `SubagentStop`, `ConfigChange` | Top-level `decision` | `decision: "block"`, `reason` |
| `PreToolUse` | `hookSpecificOutput` | `permissionDecision` (allow/deny/ask), `permissionDecisionReason`, `updatedInput` |
| `PermissionRequest` | `hookSpecificOutput` | `decision.behavior` (allow/deny), `updatedInput`, `updatedPermissions` |
| `TeammateIdle`, `TaskCreated`, `TaskCompleted` | Exit code 2 or `continue: false` | stderr for feedback; JSON to stop entirely |
| `Elicitation` | `hookSpecificOutput` | `action` (accept/decline/cancel), `content` |

### Universal JSON Output Fields

These work across all events:

| Field | Default | Description |
| --- | --- | --- |
| `continue` | `true` | If `false`, Claude stops entirely |
| `stopReason` | none | Message to user when `continue` is false |
| `suppressOutput` | `false` | Hide stdout from verbose mode |
| `systemMessage` | none | Warning shown to user |

---

## Common Configuration Patterns

### Pattern 1: History Tracking (SKILL.md Frontmatter)

The most common pattern in this skills repo. Tracks usage in History files.

```yaml
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the {skill-name} directory,
            verify that History/{YYYY-MM-DD}.md exists with an entry:
            "## HH:MM - {Action Taken}" and a one-line summary.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, verify history entry exists for {skill-name}.
            If missing: return {"decision": "block", "reason": "History entry missing."}
            If present: return {"decision": "approve"}
```

### Pattern 2: Block Dangerous Commands (PreToolUse)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/block-dangerous.sh"
          }
        ]
      }
    ]
  }
}
```

The script reads stdin JSON, inspects `tool_input.command`, and returns:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Destructive command blocked"
  }
}
```

### Pattern 3: Auto-Lint After File Writes (PostToolUse)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/lint-check.sh"
          }
        ]
      }
    ]
  }
}
```

### Pattern 4: Quality Gate Before Stop (prompt type)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Evaluate if Claude should stop: $ARGUMENTS. Check if all tasks are complete and tests pass.",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

The LLM responds: `{"ok": true}` to allow, or `{"ok": false, "reason": "Tests not passing"}` to block.

### Pattern 5: Deep Verification Before Stop (agent type)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Verify all unit tests pass. Run the test suite and check results. $ARGUMENTS",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

### Pattern 6: Session-End Auto-Commit (.github/hooks/hooks.json)

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

**Critical rules for session-end hooks:**

1. Register both `Stop` and `sessionEnd` for compatibility across clients
2. Use `--no-verify` on commits to avoid recursive pre-commit failures
3. On Windows, prefix with `sh` to avoid WSL bash routing
4. Set `GIT_TERMINAL_PROMPT=0` and `GCM_INTERACTIVE=Never`
5. Guard duplicate invocations with a lock file (30s window)
6. Exit 0 on failure — never block session termination

### Pattern 7: Async Background Tests (PostToolUse)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/run-tests-async.sh",
            "async": true,
            "timeout": 300
          }
        ]
      }
    ]
  }
}
```

Runs tests in background while Claude continues working. Results delivered on next turn.

### Pattern 8: Auto-Approve Known Safe Commands (PermissionRequest)

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/auto-approve-safe.sh"
          }
        ]
      }
    ]
  }
}
```

Returns:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow"
    }
  }
}
```

### Pattern 9: Task Completion Gate (TaskCompleted)

```bash
#!/bin/bash
# Block task completion if tests fail
if ! npm test 2>&1; then
  echo "Tests not passing. Fix before completing task." >&2
  exit 2
fi
exit 0
```

### Pattern 10: Environment Setup on Session Start (SessionStart)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/setup-env.sh"
          }
        ]
      }
    ]
  }
}
```

SessionStart hooks can persist env vars via `$CLAUDE_ENV_FILE`:

```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=development' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

### Pattern 11: PowerShell Hook on Windows

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "shell": "powershell",
            "command": "Write-Host 'File written successfully'"
          }
        ]
      }
    ]
  }
}
```

---

## Decision Matrix — Which Hook Event to Use

| Goal | Hook Event | Type |
| --- | --- | --- |
| Block dangerous shell commands | `PreToolUse` (matcher: `Bash`) | command |
| Auto-approve safe operations | `PermissionRequest` | command |
| Lint files after writes | `PostToolUse` (matcher: `Write\|Edit`) | command |
| Run tests in background after edits | `PostToolUse` (async) | command |
| Validate all tasks done before stopping | `Stop` | prompt or agent |
| Track skill usage history | `PostToolUse` + `Stop` | prompt |
| Auto-commit on session end | `SessionEnd` / `Stop` | command |
| Set up environment variables | `SessionStart` | command |
| Enforce commit message format | `PreToolUse` (matcher: `Bash`) | command |
| Block task completion until tests pass | `TaskCompleted` | command |
| Prevent teammate from going idle early | `TeammateIdle` | command |
| Audit config changes | `ConfigChange` | command |
| React to directory changes | `CwdChanged` | command |
| Watch for file modifications | `FileChanged` (matcher: filename) | command |
| Log MCP server operations | `PreToolUse` (matcher: `mcp__.*`) | command |
| Validate user prompts before processing | `UserPromptSubmit` | command or prompt |

---

## Troubleshooting

| Problem | Cause | Fix |
| --- | --- | --- |
| Hook not firing | Wrong matcher or wrong event | Use `/hooks` menu to verify config; check matcher regex |
| Stop hook runs infinitely | Hook keeps blocking without checking `stop_hook_active` | Check `stop_hook_active` field in input; skip if `true` |
| JSON parse errors | Shell profile prints text on startup | Clean `.bashrc`/`.zshrc` or use `shell: "powershell"` |
| Async hook results not appearing | Results delivered on next turn | Wait for next user interaction |
| Session-end hook not firing | Config loaded at session start | Restart the Copilot session |
| `bash.exe` error on Windows | Routes through WSL bash | Use `"windows": "sh ./.github/scripts/..."` or `shell: "powershell"` |
| Duplicate auto-commits | Both `Stop` and `sessionEnd` fire | Add lock-file guard with 30s time window |
| `permissionDecision` ignored | Using deprecated top-level `decision` for PreToolUse | Use `hookSpecificOutput.permissionDecision` instead |
| Hook blocked but action continued | Event doesn't support blocking | Check the "Can Block?" column in the events table |
| Policy hooks can't be disabled | `disableAllHooks` doesn't affect managed hooks | Only managed-level `disableAllHooks` can disable managed hooks |

## Debugging

Run `claude --debug` to see hook execution details. Toggle verbose mode with `Ctrl+O`. Use `/hooks` command to browse all configured hooks and their sources.

## Key References

- Claude Code Hooks Reference (official): <https://docs.anthropic.com/en/docs/claude-code/hooks>
- Agent Skills Specification: <https://agentskills.io/specification>
- Copilot Hooks skill (local, for Git hooks + session-end): See `copilot-hooks/SKILL.md`
- Skill Creator skill (local, for adding hooks to new skills): See `skill-creator/SKILL.md`
