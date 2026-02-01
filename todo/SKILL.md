---
name: todo
description: V1.0 - Manages TODO.md file in repository root with status table and context sections for tracking project tasks, ideas, and plans
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the todo directory (path contains 'todo'), verify that history logging occurred.
            
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
            Before stopping, if todo was used (check if any files in todo directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in todo directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
              - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
              - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# To-Do Manager

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Manages TODO.md files in repository roots for tracking project tasks, ideas, and plans.

## When to Use

Activate when the user wants to:

- Create a new TODO.md file in a project
- Update existing TODO items
- Add new tasks, ideas, or plans to a project
- View or organize project to-do lists
- Track project status across multiple repositories

## File Location

Creates or updates `TODO.md` in the root directory of the current repository.

## Structure

### Table Format

The TODO.md file MUST begin with a markdown table using this format:

```markdown
| Status | Priority | Task | Notes |
|--------|----------|------|-------|
| 🚧 | High | Task description | Additional context |
| ⏸️ | Medium | Another task | More details |
| ✅ | Low | Completed item | Done! |
```

### Status Icons

Use these standard status markers:

- `📋` - To Do (not started)
- `🚧` - In Progress (actively working)
- `⏸️` - Blocked/Paused (waiting on something)
- `✅` - Done (completed)
- `❌` - Won't Do (cancelled/deprioritized)

### Priority Levels

- `High` - Critical, needs immediate attention
- `Medium` - Important but not urgent
- `Low` - Nice to have, future work

### Elaboration Sections

Below the table, users can add freeform sections for additional context:

```markdown
## Context

Background information about the project or specific tasks.

## Ideas

Brainstorming and future possibilities.

## Completed

Detailed notes on finished work and outcomes.

## Notes

Any other relevant information.
```

## Operations

### Create New TODO.md

When creating a new file:

1. Verify we're in a git repository (check for .git directory)
2. Create TODO.md in the repository root
3. Add initial table structure with example row
4. Add placeholder sections if requested

### Update Existing TODO.md

When updating:

1. Read the existing TODO.md
2. Parse the table (preserve all existing rows)
3. Add/update/remove rows as requested
4. Maintain table formatting
5. Preserve all content below the table

### Guidelines

- **Always preserve the table at the top** - Never move or remove it
- **Keep the table concise** - Use the elaboration sections for lengthy details
- **Maintain chronological order** - Newest tasks at the bottom of the table
- **Archive completed items** - Move ✅ items to a "## Completed" section periodically to keep the table focused
- **Be specific** - Task descriptions should be actionable ("Add user authentication" not "Auth stuff")

## Example TODO.md

```markdown
# Project TODO

| Status | Priority | Task | Notes |
|--------|----------|------|-------|
| 🚧 | High | Implement authentication system | Using Next-Auth |
| 📋 | High | Set up database schema | PostgreSQL with Prisma |
| 📋 | Medium | Create landing page | Use shadcn/ui components |
| ⏸️ | Low | Add dark mode support | Blocked: waiting on design |

## Context

This project is a web application for managing personal tasks. Built with Next.js, TypeScript, and Supabase.

## Ideas

- Add calendar view for tasks
- Integrate with Google Calendar
- Mobile app using React Native

## Notes

- Remember to update tests when adding new features
- Keep dependencies up to date weekly
```

## Workflow

1. **User requests to-do action** (create, update, view)
2. **Determine repository root** (search for .git directory)
3. **Check for existing TODO.md**
4. **Perform requested operation**:
   - Create: Generate new file with template
   - Update: Modify table while preserving structure
   - View: Display current contents
5. **Confirm changes** with user

## Anti-Patterns

- Don't create TODO.md outside of repository roots
- Don't remove or restructure the table without user consent
- Don't use inconsistent status icons
- Don't add vague or non-actionable tasks
- Don't let the table grow huge - suggest archiving completed items
