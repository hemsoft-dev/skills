---
name: notes
description: V1.1 - Manages and organizes personal notes with a structured folder system. Use when creating, organizing, searching, or managing notes across different categories and projects.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the notes directory (path contains 'notes'), verify that history logging occurred.
            
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
            Before stopping, if notes was used (check if any files in notes directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in notes directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Notes

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Manages and organizes personal notes with a structured folder system.

## Folder Structure

All notes are stored in the `Notes/` subfolder with the following organization:

```
Notes/
├── Projects/          # Project-specific notes and documentation
├── Ideas/             # Random ideas, thoughts, and brainstorming
├── References/        # Reference materials, documentation, guides
├── Personal/          # Personal notes and reflections
├── Work/              # Work-related notes and documentation
└── Archive/           # Older notes moved here for organization
```

## Usage

- **Create notes**: Place new notes in the appropriate category folder
- **Organize notes**: Move notes between folders as needed
- **Search notes**: Use file search tools to find notes across all folders
- **Archive notes**: Move older or completed notes to Archive/ for long-term storage

## Migration

Notes will gradually be migrated from the reference location (old notes) to this structure.

**Reference Notes Location**: `D:\OneDrive\Documents\Notes`

When referring to "reference notes" or "old notes", this is the source location (`D:\OneDrive\Documents\Notes`) where existing notes are stored before migration.

When migrating:

1. Review the note content to determine the appropriate category
2. Place it in the correct subfolder
3. Update any references or links if needed
4. Consider archiving very old notes directly to Archive/
