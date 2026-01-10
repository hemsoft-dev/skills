---
name: skill-extractor
description: V1.2 - Analyzes Markdown files to identify and extract reusable instruction sets into standalone skills.
---

# Skill Extractor

Expert in identifying reusable instruction sets within existing Markdown files and extracting them into standalone skills.

## Agent Skills Specification - Frontmatter Reference

Per the official spec at <https://agentskills.io/specification>, SKILL.md frontmatter supports:

| Field         | Required | Constraints                                           |
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

## Workflow

1. **Analyze**: Scan the provided Markdown file for distinct, self-contained topics or
   instruction sets.
2. **Identify**: Look for sections that are:
   - Reusable across different projects or agents.
   - Complex enough to benefit from being a standalone skill.
   - Clearly defined with a specific purpose (e.g., SQL interaction, API integration, specific tool usage).
3. **Propose**: For each identified opportunity:
   - Suggest a concise, kebab-case skill name (e.g., `sql-helper`,
     `azure-deployer`).
   - Provide a one-sentence description.
   - Draft the `SKILL.md` content following the standard format.
4. **Create**: Upon user approval, create the skill directory and `SKILL.md`
   file in `c:\Users\franz\.claude\skills\{skill-name}/`.
5. **Preserve**: Do NOT modify the original Markdown file unless explicitly
   asked. If asked, propose how to replace the extracted section with a
   reference to the new skill.

## SKILL.md Template

**Minimal (required only):**

```yaml
---
name: {skill-name}
description: V1.0 - {One sentence describing when to use this skill}
---

# {Skill Title}

{Concise instructions for the LLM}
```

**With optional fields (when applicable):**

```markdown
---
name: {skill-name}
description: V1.0 - {Description of what + when to use}
license: Apache-2.0
compatibility: Requires specific tools or environment
metadata:
  author: {source-document}
---
```

## Best Practices

- **Consistency**: Keep naming consistent with existing skills (e.g., `mail`, `generate-image`, `skill-creator`).
- **Conciseness**: Keep instructions minimal and actionable.
- **No Bloat**: Avoid documentation fluff; focus on the task at hand.
