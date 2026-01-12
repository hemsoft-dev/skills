---
name: skill-creator
description: V1.4 - Creates new Claude skills with optimized SKILL.md files following best practices for clarity and conciseness.
---

# Skill Creator

Create new skills in the user's `.claude/skills/` directory.

## Agent Skills Specification - Frontmatter Reference

Per the official spec at <https://agentskills.io/specification>, SKILL.md frontmatter supports:

| Field    | Required | Constraints                                                     |
| `name`             | ✅ | Max 64 chars. Lowercase alphanumeric + hyphens.    |
| `description`      | ✅ | Max 1024 chars. Include what + when to use.        |
| `license`          | ❌ | License name or reference (e.g., `Apache-2.0`)    |
| `dependencies`     | ❌ | Software packages required (e.g., `python>=3.8`)  |
| `compatibility`    | ❌ | Max 500 chars. Environment requirements             |
| `metadata`         | ❌ | Key-value map for custom properties                 |
| `allowed-tools`    | ❌ | Space-delimited pre-approved tools                 |

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Skill Structure

Each skill requires:

```text
.claude/skills/{skill-name}/
└── SKILL.md
```

## SKILL.md Format

**Minimal (required only):**

```markdown
---
name: {skill-name}
description: V{major}.{minor} - {One sentence describing when to use this skill}
---

# {Skill Title}

{Concise instructions for the LLM}
```

**With optional fields:**

```markdown
---
name: {skill-name}
description: V{major}.{minor} - {Description of what + when to use}
license: Apache-2.0
compatibility: Requires git, network access
metadata:
  author: {author-name}
  version: "1.0"
---
```

## Best Practices

1. **Description** - Single sentence that helps the LLM decide if this skill applies
2. **Instructions** - Minimal, actionable guidance; avoid over-documentation
3. **Placeholders** - Use `{VARIABLE}` for runtime values
4. **Output Format** - Only specify if the skill produces structured output

## Creation Workflow

**CRITICAL: Always ask these questions BEFORE creating anything:**

### Step 1: Get Skill Details

Ask user for skill name and purpose.

### Step 2: Choose Location

**Default: User folder (unless user specifies otherwise)**

**Option A - User Folder (Global)** [DEFAULT]:

- Location: `~/.claude/skills/{skill-name}/`
- Available across all projects
- Use for: General-purpose skills, tools, utilities

**Option B - Repository (Project-Scoped)**:

- Location: `{repo-root}/.claude/skills/{skill-name}/`
- Only available in this project
- Use for: Project-specific workflows, context

**Only ask if unclear**: If user explicitly mentions "repo", "repository", or "project-specific", use Option B. Otherwise, default to Option A (user folder).

### Step 3: Enable History Tracking

**Default: Enabled (unless user specifies otherwise)**

History tracking logs all interactions to `History/{YYYY-MM-DD}.md`.

**Only disable if**: User explicitly says "no history", "don't track", or "disable history".

**When enabled** (default), add this section after the title:

```markdown
## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

\```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
\```
```

### Step 4: Create Files

1. Create directory at chosen location (default: user folder)
2. Write SKILL.md with frontmatter and instructions
3. Apply version prefix (V1.0)
4. Create History/ directory and apply history tracking section (default: enabled)

### Step 5: Confirm Creation

Tell user where the skill was created and what features are enabled.

## Skill-Improver Integration

Before finalizing the skill, check the `skill-improver` skill for available improvements and offer them:

| Improvement          | Default        | Override                                    |
|----------------------|----------------|---------------------------------------------|
| Version prefix       | Always applied | Never (always V1.0 for new skills)          |
| History Tracking     | Enabled        | Only if user says "no history" or similar   |
| Location             | User folder    | Only if user says "repo" or "project-specific" |

## Anti-Patterns

- Verbose explanations
- Redundant sections
- Hypothetical edge cases
- Documentation for documentation's sake
