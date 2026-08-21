---
name: skill-creator
description: V1.16 - Creates new skills with optimized SKILL.md files following the agentskills.io open standard. Default location is .agents/skills/ (universal, all vendors). Uses hooks for history tracking and retrospectives (enabled by default). Includes explicit instructions for getting accurate timestamps.
disable-model-invocation: true
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the skill-creator directory (path contains 'skill-creator'), verify that history logging occurred.
            
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
            Before stopping, if skill-creator was used (check if any files in skill-creator directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in skill-creator directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Skill Creator

Create new skills following the [agentskills.io](https://agentskills.io/specification) open standard.

## Skill Location Standard

The canonical location for skills is **`.agents/skills/`** — this is the universal path defined by the agentskills.io specification (v0.9+, AAIF/Linux Foundation). It is scanned by all major AI coding tools: Claude Code, GitHub Copilot, OpenAI Codex CLI, Cursor, Gemini CLI, JetBrains, and 30+ others.

**Do NOT use vendor-specific paths** (`.claude/skills/`, `.github/skills/`, `.cursor/rules/`) for new skills unless the user explicitly requests vendor lock-in. Those are legacy/fallback paths.

## Frontmatter Reference

### Agent Skills Specification Fields

Per the official spec at <https://agentskills.io/specification>, SKILL.md
frontmatter supports these fields:

| Field | Required | Constraints |
| --- | --- | --- |
| `name` | Yes | Max 64 chars. Lowercase alphanumeric and hyphens. |
| `description` | Yes | Max 1024 chars. Include what the skill does and when to use it. |
| `license` | No | License name or reference, such as `Apache-2.0`. |
| `compatibility` | No | Max 500 chars. Environment requirements. |
| `metadata` | No | String key-value map for custom properties. |
| `allowed-tools` | No | Experimental. Space-delimited pre-approved tools. |

### Optional Client Extensions

These fields are outside the core Agent Skills specification. Client support
varies; invocation control is documented by
[Claude Code](https://code.claude.com/docs/en/skills#control-who-invokes-a-skill).

| Field | Required | Constraints |
| --- | --- | --- |
| `dependencies` | No | Software packages required, such as `python>=3.8`. |
| `hooks` | No | Hook configuration for automated post-processing. |
| `disable-model-invocation` | No | Claude Code boolean: `true` prevents automatic loading and allows user invocation only; `false` permits model invocation. Client default: `false`. |

**Recommended skill-creator default**: Set `disable-model-invocation: true`
unless the user explicitly wants the model to invoke the skill automatically.

## Skill Structure

Each skill requires:

```text
.agents/skills/{skill-name}/
├── SKILL.md
├── scripts/              # Optional: PowerShell/Python scripts
│   └── script-name.ps1
└── History/              # Optional: Interaction logs
    └── {YYYY-MM-DD}.md
```

## SKILL.md Format

**Recommended default:**

```markdown
---
name: {skill-name}
description: V{major}.{minor} - {One sentence describing when to use this skill}
disable-model-invocation: true
---

# {Skill Title}

{Concise instructions for the LLM}
```

**With commands/modes (when a skill has distinct capabilities):**

```markdown
---
name: {skill-name}
description: "V{major}.{minor} - Commands: {Cmd1}, {Cmd2}, {Cmd3}. {Description of what + when to use}"
disable-model-invocation: true
---
```

The `Commands:` prefix lists the skill's modes/capabilities upfront so they are
immediately visible when the user types `/{skill-name}` in the chat prompt.
Only add `Commands:` when the skill genuinely has multiple distinct modes or
entry points — simple single-purpose skills should omit it.

**With optional fields and hooks:**

```markdown
---
name: {skill-name}
description: V{major}.{minor} - {Description of what + when to use}
disable-model-invocation: true
license: Apache-2.0
compatibility: Requires git, network access
metadata:
  author: {author-name}
  version: "1.0"
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the {skill-name} directory...
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, verify history entry exists...
---
```

## Best Practices

1. **Description** - Single sentence that helps the LLM decide if this skill applies
2. **Commands prefix** - If the skill has multiple commands or modes, list them at the start of the description: `Commands: Cmd1, Cmd2, Cmd3.` This makes capabilities visible when the user types `/{skill-name}` in the chat prompt
3. **Invocation control** - Set `disable-model-invocation: true` by default; use `false` only when automatic model invocation is intentional
4. **Instructions** - Minimal, actionable guidance; avoid over-documentation
5. **Placeholders** - Use `{VARIABLE}` for runtime values
6. **Output Format** - Only specify if the skill produces structured output
7. **Scripts Organization** - Keep all PowerShell/Python scripts in a `scripts/` subfolder (e.g., `{skill-name}/scripts/script-name.ps1`)
8. **Imported skills** - Skills from other authors keep their author's conventions. Do not retrofit version prefixes, `disable-model-invocation`, hooks, or History folders onto third-party skills unless the user asks; house style applies to skills created here

## Creation Workflow

**CRITICAL: Always ask these questions BEFORE creating anything:**

### Step 1: Get Skill Details

Use the skill name and purpose from the request when they are explicit. Ask only
for missing details that would materially change the result.

### Step 2: Choose Location

**Default: User folder (unless user specifies otherwise)**

**Option A - User Folder (Global)** [DEFAULT]:

- Location: `~/.agents/skills/{skill-name}/`
- Available across all projects for all AI tools
- Use for: General-purpose skills, tools, utilities

**Option B - Repository (Project-Scoped)**:

- Location: `{repo-root}/.agents/skills/{skill-name}/`
- Available in this project for all AI tools
- Use for: Project-specific workflows, context

**Only ask if unclear**: If user explicitly mentions "repo", "repository", or "project-specific", use Option B. Otherwise, default to Option A (user folder).

> **Note**: The `.agents/skills/` path is the agentskills.io universal standard, supported by Claude, Copilot, Codex CLI, Cursor, Gemini CLI, and others. Avoid vendor-specific paths like `.claude/skills/` or `.github/skills/` unless explicitly requested.

### Step 3: Enable History Tracking & Retrospectives via Hooks

**Default: Enabled (unless user specifies otherwise)**

History tracking and retrospectives are now handled via hooks in the SKILL.md frontmatter.

**Only disable if**: User explicitly says "no history", "don't track", "no retrospective", or "disable history/retrospective".

**When enabled** (default), add this to the frontmatter after `description`:

```yaml
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the {skill-name} directory (path contains '{skill-name}'), verify that history logging occurred.
            
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
            Before stopping, if {skill-name} was used (check if any files in {skill-name} directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in {skill-name} directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
```

**Important**: Replace `{skill-name}` with the actual skill name throughout the hooks configuration.

**Client support caveat**: frontmatter `hooks` are a Claude Code extension. Opencode reads only `name`, `description`, `license`, `compatibility`, and `metadata` from skill frontmatter and ignores every other field, including `hooks` and `disable-model-invocation`. The same applies to other clients with partial spec support. Because of that, every skill created here must also carry a short body-level `## History` section stating the logging rule in plain instructions. The body section is the mechanism that works everywhere; the hooks block is a Claude Code enhancement layered on top, not a replacement.

### Step 4: Create Files

1. Create directory at chosen location (default: user folder)
2. Write SKILL.md with `disable-model-invocation: true` by default, frontmatter hooks if enabled, and instructions
3. Apply version prefix (V1.0)
4. Create History/ directory if history tracking enabled (default: enabled)
5. Create initial History/{YYYY-MM-DD}.md entry if history tracking enabled

**CRITICAL: Getting Accurate Timestamps**

When creating history entries, you MUST get the current time using PowerShell:

```powershell
Get-Date -Format "HH:mm"
```

This returns the current time in 24-hour format (e.g., "12:36", "23:53", "02:22").

**Never guess or estimate the time** - always run this command to get the accurate current time before writing the history entry. The timestamp format is `## HH:MM - {Action Taken}` where HH:MM is the 24-hour time from the command above.

### Step 5: Confirm Creation

Tell user where the skill was created and what features are enabled.

## Final Review

Before finalizing the skill:

1. Validate the frontmatter and directory name.
2. Confirm the instructions are concise and executable.
3. Check that scripts and referenced files exist.
4. Record the exact timestamp in the current history file when history is enabled.
5. Run the repository's focused Markdown and script checks.

## Anti-Patterns

- Verbose explanations
- Redundant sections
- Hypothetical edge cases
- Documentation for documentation's sake

## History

After using this skill, append `## HH:MM - {Action Taken}` plus a one-line
summary to `History/{YYYY-MM-DD}.md` in this skill folder, noting whether a
retrospective check found a reusable improvement. Take the timestamp from the
shell (`Get-Date -Format "HH:mm"` on Windows, `date +%H:%M` elsewhere), never
an estimate.
