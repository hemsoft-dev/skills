---
name: skill-extractor
description: V1.4 - Analyzes Markdown files to identify and extract reusable instruction sets into standalone skills with hook-based history tracking and retrospectives.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the skill-extractor directory (path contains 'skill-extractor'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if skill-extractor was used (check if any files in skill-extractor directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in skill-extractor directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}"
            3. Ensure the entry includes a one-line summary of what was done
            4. Verify retrospective check was performed
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
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
| `hooks`            | ❌ | Hook configuration for automated post-processing   |

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

**With history tracking and retrospectives (hooks-based):**

```yaml
---
name: {skill-name}
description: V1.0 - {Description of what + when to use}
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the {skill-name} directory (path contains '{skill-name}'), verify that history logging occurred.
            Check if History/{YYYY-MM-DD}.md exists with format "## HH:MM - {Action Taken}" and one-line summary.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if {skill-name} was used, verify history entry exists in History/{YYYY-MM-DD}.md.
---
```

**Important**: Replace `{skill-name}` with the actual skill name throughout the hooks configuration.

## Best Practices

- **Consistency**: Keep naming consistent with existing skills (e.g., `mail`, `generate-image`, `skill-creator`).
- **Conciseness**: Keep instructions minimal and actionable.
- **No Bloat**: Avoid documentation fluff; focus on the task at hand.
