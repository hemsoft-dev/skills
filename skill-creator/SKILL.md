---
name: skill-creator
description: V1.2 - Creates new Claude skills with optimized SKILL.md files following best practices for clarity and conciseness.
---

# Skill Creator

Create new skills in the user's `.claude/skills/` directory.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Skill Structure

Each skill requires:

```
.claude/skills/{skill-name}/
└── SKILL.md
```

## SKILL.md Format

```markdown
---
name: {skill-name}
description: V{major}.{minor} - {One sentence describing when to use this skill}
---

# {Skill Title}

{Concise instructions for the LLM}
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

### Step 2: Choose Location (REQUIRED - NEVER SKIP)

**ALWAYS ask the user where to create the skill:**

**Option A - User Folder (Global)**:

- Location: `~/.claude/skills/{skill-name}/`
- Available across all projects
- Use for: General-purpose skills, tools, utilities

**Option B - Repository (Project-Scoped)**:

- Location: `{repo-root}/.claude/skills/{skill-name}/`
- Only available in this project
- Use for: Project-specific workflows, context

**Prompt to user**: "Where should I create this skill? A) User folder (~/.claude/skills/) for global access, or B) This repository (./.claude/skills/) for project-specific use?"

### Step 3: Enable History Tracking? (REQUIRED - NEVER SKIP)

**ALWAYS ask the user about history tracking:**

**Prompt to user**: "Would you like to enable History Tracking for this skill? This logs all interactions to History/{YYYY-MM-DD}.md for future reference."

If yes, add this section after the title:

```markdown
## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

\```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
\```
```

### Step 4: Create Files

1. Create directory at chosen location
2. Write SKILL.md with frontmatter and instructions
3. Apply version prefix (V1.0)
4. Apply history tracking (if user said yes)

### Step 5: Confirm Creation

Tell user where the skill was created and what features are enabled.

## Skill-Improver Integration

Before finalizing the skill, check the `skill-improver` skill for available improvements and offer them:

| Improvement | Default | Ask User |
|-------------|---------|----------|
| Version prefix (`V1.0 -`) | Always applied | No |
| History Tracking | Off | Yes |

**Prompt**: "Would you like to enable History Tracking for this skill? This logs all interactions to `History/{YYYY-MM-DD}.md`."

## Anti-Patterns

- Verbose explanations
- Redundant sections
- Hypothetical edge cases
- Documentation for documentation's sake
