---
name: meeting-preparation
description: V1.0 - Expert in helping prepare for meetings with structured templates, research, checklists, and readiness assessments.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the meeting-preparation directory (path contains 'meeting-preparation'), verify that history logging occurred.
            
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
            Before stopping, if meeting-preparation was used (check if any files in meeting-preparation directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in meeting-preparation directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Meeting Preparation

Helps prepare for upcoming meetings with structured templates, research, and readiness assessments.

## Directory Structure

```text
meeting-preparation/
├── meetings/
│   └── {YYYY-MM-DD-slug}/
│       └── meeting.md
├── meeting.json
└── SKILL.md
```

## Workflow

### 1. Create Meeting Folder

When user schedules a meeting, create a folder under `meetings/` with format:

- `{YYYY-MM-DD-slug}/` (e.g., `2026-02-15-quarterly-review/`)

### 2. Generate meeting.md

Create `meeting.md` in the meeting folder using the template from `meeting.json`. Required fields:

- **Meeting Title** (mandatory)
- **Date and Time** (mandatory)
- **Participants** OR **Audience Description** (at least one required)

Optional fields:

- **Host**
- **Skill Level** (100/200/300/400 per Microsoft system)
- **Observations**

### 3. Preparation Tasks Section

Generate a preparation checklist table with:

| Task | Status | Resources | Notes |
|------|--------|-----------|-------|
| {task-name} | ✓ / ✗ | [Resource Title](url) | Brief note |

**Guidelines for content:**

- Provide tips, tricks, and research links
- Keep summaries to 1 paragraph maximum
- Focus on references over explanations
- Ask clarifying questions if requirements are incomplete

### 4. Readiness Assessment

Review the checklist and ask questions for any incomplete items (✗) to help user achieve full preparation.

## Microsoft Skill Level Reference

- **100 - Introductory**: Little or no expertise required; overview level
- **200 - Intermediate**: Assumes 100-level knowledge; specific details
- **300 - Advanced**: Assumes 200-level knowledge; in-depth understanding, strong technical skills
- **400 - Expert**: Deep technical knowledge; expert-to-expert interaction

## Output Format

When creating a meeting preparation, always:

1. Confirm meeting details with user
2. Create folder structure
3. Generate meeting.md from template
4. Populate preparation tasks with research and resources
5. Present checklist for review
6. Ask questions for incomplete items
