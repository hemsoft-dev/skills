---
name: test-hook-skill
description: V1.0 - Test skill that demonstrates hook-based history logging instead of manual instructions.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the test-hook-skill directory, verify that history logging occurred.
            
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
            Before stopping, verify that the test-hook-skill interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in test-hook-skill directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}"
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Test Hook Skill

A simple test skill to demonstrate automated history logging via hooks defined in SKILL.md frontmatter.

## Purpose

This skill performs basic operations and relies on hooks (defined in the SKILL.md frontmatter) to automatically log interactions to `History/{YYYY-MM-DD}.md` instead of requiring manual "ALWAYS: Log This Interaction" instructions.

## Usage

This skill can be invoked directly - hooks are configured in the SKILL.md frontmatter and will automatically handle history logging.

## What This Skill Does

- Performs a simple test operation
- Returns a summary of what was accomplished
- Relies on hooks (defined in frontmatter) to log the interaction automatically

## Note

This skill does NOT include "ALWAYS: Log This Interaction" instructions. History logging is handled entirely by hooks defined in the SKILL.md frontmatter above.
