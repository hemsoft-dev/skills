---
name: protocols
description: V1.1 - Central reference manual of standardized procedures and execution patterns. Skills consult this for detailed instructions on common tasks to ensure consistency. User-controlled; never modify without explicit request.
disable-model-invocation: true
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the protocols directory (path contains 'protocols'), verify that history logging occurred.
            
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
            Before stopping, if protocols was used (check if any files in protocols directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in protocols directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Protocols

This skill contains standardized procedures and execution patterns that other skills reference for detailed instructions. When a skill references a protocol (e.g., "consult protocols for how to ask questions"), look up the corresponding entry below and follow the detailed instructions.

## How to Use

1. Skills will reference protocols when they need detailed execution instructions
2. Look up the protocol entry by name/topic
3. Follow the detailed instructions in that entry
4. Never modify this skill unless the user explicitly requests it

---

## Protocol Entries

### Asking Clarifying Questions

**When to use**: When a skill instructs you to "ask clarifying questions" or "gather requirements from the user" without specifying the exact format.

**Details**: See [translations/asking-clarifying-questions.md](translations/asking-clarifying-questions.md)

### Batch and Incremental Task Execution

**When to use**: When instructions contain keywords indicating batch, incremental, or context-aware execution (e.g., "in batches", "incremental", "context-aware", "do X at a time", "process in groups").

**Details**: See [translations/batch-incremental-tasks.md](translations/batch-incremental-tasks.md)
