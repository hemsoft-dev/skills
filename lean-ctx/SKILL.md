---
name: lean-ctx
description: "V1.0 - Commands: status, audit, bootstrap. Expert in lean-ctx MCP context engineering layer — tool mapping, read modes, knowledge persistence, session memory, code graphs, and repo AGENTS.md bootstrapping. Use when working with lean-ctx tools, optimizing token usage, or ensuring repos are properly configured for lean-ctx."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the lean-ctx directory (path contains 'lean-ctx'), verify that history logging occurred.

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
            Before stopping, if lean-ctx was used (check if any files in lean-ctx directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in lean-ctx directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}
---

# lean-ctx — Context Engineering Layer

Expert reference for the lean-ctx MCP tool suite. lean-ctx replaces native
file/shell/search tools with cached, compressed, token-efficient equivalents
and adds persistent cross-session knowledge.

## Commands

### `status`

Show lean-ctx availability and session metrics. Run `ctx_metrics` and
`ctx_knowledge(action: "status")` to report cache hit rates, token savings,
and knowledge base size.

### `audit`

Check if the current repo's AGENTS.md has a proper lean-ctx section. Look for
the `<!-- lean-ctx -->` marker. Report what's present, what's missing, and
what's outdated. Does NOT modify files — report only.

### `bootstrap`

Ensure the current repo has a complete lean-ctx section in AGENTS.md. If
AGENTS.md doesn't exist, create it. If the lean-ctx section is missing or
incomplete, inject the canonical section (see Template below). Preserve all
existing content outside the lean-ctx markers.

---

## Tool Reference

### Core I/O (use INSTEAD of native equivalents)

| lean-ctx tool | Replaces | Key advantage |
|---------------|----------|---------------|
| `ctx_read(path, mode)` | `cat`, `view`, `Read`, `head`, `tail` | Cached; re-reads cost ~13 tokens; 10 compression modes |
| `ctx_multi_read(paths, mode)` | Multiple `view` calls | Batch read in one call |
| `ctx_edit(path, old, new)` | `Edit` (when Read unavailable) | Search-and-replace with preimage guards |
| `ctx_search(pattern, path)` | `grep`, `rg`, `Select-String` | Compact, .gitignore-aware, deterministic order |
| `ctx_tree(path, depth)` | `ls`, `dir`, `find`, `glob` | Compact directory maps with file counts |
| `ctx_shell(command)` | `bash`, `powershell`, terminal | 95+ compression patterns for git/npm/cargo output |

### ctx_read Modes

| Mode | When to use |
|------|-------------|
| `auto` | Unsure — system selects optimal mode |
| `full` | Files you plan to edit (first read) |
| `diff` | Re-reads after editing (changed lines only) |
| `map` | Context-only files (deps + exports) |
| `signatures` | API surface only |
| `aggressive` | Maximum compression (large context-only files) |
| `entropy` | Highlight high-information fragments |
| `task` | Task-filtered (IB-filtered relevant content) |
| `reference` | Quote-friendly minimal excerpts |
| `lines:N-M` | Specific line range |

**Anti-pattern**: NEVER use `full` for files you won't edit — use `map` or `signatures`.

### Knowledge Persistence

`ctx_knowledge` provides cross-session memory. Key actions:

| Action | Purpose | Example |
|--------|---------|---------|
| `recall` | Search stored knowledge | `recall(query: "auth token pattern")` |
| `remember` | Store a new fact | `remember(category: "conventions", key: "slug", value: "...")` |
| `pattern` | Record a recurring pattern | `pattern(pattern_type: "naming", value: "...")` |
| `feedback` | Upvote/downvote a fact | `feedback(key: "slug", value: "up")` |
| `relate` | Link two facts | `relate(key: "a", query: "category/b", value: "depends-on")` |
| `status` | Show knowledge base stats | `status()` |
| `search` | Full-text search | `search(query: "token")` |

**Categories**: `architecture`, `api`, `testing`, `deployment`, `conventions`, `dependencies`

**Prime directive**: Every session MUST recall before acting and remember after
completing work. A failed approach is as valuable as a working one if the reason
is captured.

### Session Memory

`ctx_session` provides cross-session continuity:

| Action | Purpose |
|--------|---------|
| `load` | Restore previous session context (~400 tokens) |
| `save` | Persist current session state |
| `task` | Record current task description |
| `finding` | Record a discovery |
| `decision` | Record a decision with rationale |
| `resume` | Resume from last checkpoint |
| `episodes` | List past session episodes |

### Code Intelligence

| Tool | Purpose |
|------|---------|
| `ctx_graph(action)` | Build/query unified code graph |
| `ctx_impact(action)` | Graph-based impact analysis |
| `ctx_symbol(name)` | Read a specific symbol by name |
| `ctx_outline(path)` | List all symbols in a file |
| `ctx_callgraph(direction)` | Caller/callee analysis |
| `ctx_architecture(action)` | Cluster and dependency analysis |
| `ctx_smells(action)` | Code smell detection (8 rules) |

### Context Management

| Tool | Purpose |
|------|---------|
| `ctx_overview(task)` | Task-relevant project map (use at session start) |
| `ctx_preload(task)` | Cache task-relevant files proactively |
| `ctx_compress` | Checkpoint context when conversation grows large |
| `ctx_fill(budget)` | Budget-aware auto-compression per file |
| `ctx_plan` | Compute optimal context plan with scoring |
| `ctx_compile` | Build minimal context package |

### Metrics & Observability

| Tool | Purpose |
|------|---------|
| `ctx_metrics` | Session token stats, cache rates, per-tool savings |
| `ctx_cost(action)` | Cost attribution per agent/tool |
| `ctx_gain` | Gain report (compression ROI) |
| `ctx_radar` | Full context budget breakdown |
| `ctx_heatmap` | File access frequency heatmap |

---

## AGENTS.md Canonical Template

When running `bootstrap`, inject this between `<!-- lean-ctx -->` markers:

```markdown
<!-- lean-ctx -->
## lean-ctx — Tool preference

ALWAYS use lean-ctx MCP tools instead of native equivalents. This saves
tokens and provides caching, compression, and persistent context.

| Use this | Instead of | Why |
|----------|------------|-----|
| `ctx_read` | `cat`, `view`, `Read` | Cached reads, 10 compression modes |
| `ctx_search` | `grep`, `rg`, `Select-String` | Compact, token-efficient results |
| `ctx_shell` | `bash`, `powershell` | Pattern compression on output |
| `ctx_tree` | `ls`, `dir`, `find`, `glob` | Compact directory maps |
| `ctx_knowledge` | ad-hoc notes | Persistent cross-session memory |

Full rules: @LEAN-CTX.md
<!-- /lean-ctx -->
```

Additionally, ensure the AGENTS.md contains the Prime Directive section for
knowledge recall/persist. If missing, inject:

```markdown
## Prime Directive — Learn from the past, teach the future

Every agent session MUST use `ctx_knowledge` (lean-ctx) for both **input** and
**output** operations. This is non-negotiable.

### Input — Recall before you act

Before planning or implementing any non-trivial change, recall relevant context:

ctx_knowledge(action: "recall", query: "<topic you're about to change>")

### Output — Remember what you learned

After completing work, persist new knowledge for future sessions:

ctx_knowledge(action: "remember", category: "<category>", key: "<slug>", value: "<what you learned>")
```

### Bootstrap workflow

1. Check if `AGENTS.md` exists at repo root
2. If not, create it with both sections (Prime Directive + lean-ctx tool table)
3. If it exists, check for `<!-- lean-ctx -->` markers
4. If markers missing, append the lean-ctx section
5. If markers present but content outdated (missing tool table rows or Prime
   Directive), replace the section between markers with the canonical version
6. Check for Prime Directive section — add if missing
7. Commit the change if the user confirms

### Audit checklist

When running `audit`, check for:

- [ ] `AGENTS.md` exists at repo root
- [ ] Contains `<!-- lean-ctx -->` opening marker
- [ ] Contains `<!-- /lean-ctx -->` closing marker
- [ ] Tool preference table has all 5 rows (ctx_read, ctx_search, ctx_shell, ctx_tree, ctx_knowledge)
- [ ] References `@LEAN-CTX.md` for full rules
- [ ] Contains Prime Directive section with recall/remember instructions
- [ ] `LEAN-CTX.md` exists at repo root (the full rules file)

Report each item as ✅ or ❌ with actionable fix for failures.
