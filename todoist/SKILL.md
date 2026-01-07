---
name: todoist
description: V1.3 - Interact with Todoist API via PowerShell scripts to manage tasks, projects, labels, and track task updates/comments.
---

# Todoist

Manage Todoist tasks, projects, and labels via REST API v2.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Handling Idea Backlogs vs True Overdue Tasks

**Problem**: Tasks marked as "overdue" that are actually a backlog of ideas (video concepts, demos, tutorials) create false urgency and stress.

**Solution**: Separate Ideas from Deadlines

### Create a Content Ideas / Backlog Project
1. **Move idea tasks** out of Work projects into dedicated "Content Ideas" or "Project Ideas" project
2. **Remove due dates** - Ideas don't have deadlines; use "No date" to clear them from overdue
3. **Organize with sections**:
   - Video Ideas
   - Demo Ideas  
   - Tutorial Concepts
   - Someday/Maybe

### Use Labels for Prioritization
Instead of dates and priorities, use context labels:
- `@quick_win` - Can be done quickly
- `@high_impact` - High value/reach potential
- `@needs_research` - Requires investigation first
- `@blocked` - Waiting on external factors

### Weekly Review Process
Set recurring weekly task: **"Review Ideas Backlog - Pick 1-2 to activate"**
- Browse your ideas project
- Move selected ideas to active Work projects with real due dates
- Archive or delete ideas no longer relevant

**Result**: Your overdue list shows only true deadlines while your idea backlog becomes an inspirational resource to draw from, not a source of stress.

## Task Prioritization Logic

When asked about priorities, what to focus on, next steps, or workload:

1. **Context from project hierarchy**: Work > Home
   - Tasks under **Work** parent project (and its children) are higher priority
   - **Home** tasks are lower priority
   - **Project Ideas** spans both contexts
2. **Task priority**: P1 (urgent) > P2 > P3 > P4/none
3. **Time sensitivity**: Overdue and due-today tasks carry more weight

**Do NOT organize output by project**—use project hierarchy only to determine work vs. home context.

## PowerShell Scripts (Preferred)

Use the provided PowerShell scripts for reliable Todoist interaction:

### Get-TodoistSummary.ps1
Comprehensive overview with all task categories:
```powershell
.\Get-TodoistSummary.ps1 -IncludeCompleted
```

### Get-TodoistCompleted.ps1
Completed tasks for a specific date:
```powershell
.\Get-TodoistCompleted.ps1 -Date "2026-01-06" -Format List
```

### Get-TodoistTasks.ps1
Active tasks with custom filters:
```powershell
.\Get-TodoistTasks.ps1 -Filter "today | overdue" -Format List
```

### Get-TodoistUpdated.ps1
Tasks with comments/updates today (shows progress logs):
```powershell
.\Get-TodoistUpdated.ps1
```

### Get-TodoistComments.ps1
Get comments for specific tasks:
```powershell
.\Get-TodoistComments.ps1 -TaskId 1234567890
.\Get-TodoistComments.ps1 -ProjectId 2221463722
```

All scripts are located in the skill directory and support multiple output formats (Table, List, JSON, Raw).

## MCP Tools (If Available)

Use mcp_doist_todoist_search with these queries:
- `p1` - Urgent priority tasks
- `p2` - High priority tasks
- `overdue` - Overdue tasks
- `today` - Due today

Use mcp_doist_todoist_fetch with `task:{id}` or `project:{id}` (numeric IDs only).

## REST API Direct Access

**Authentication:** Set environment variable `TODOIST_API_TOKEN` with your API token from https://todoist.com/app/settings/integrations/developer

**Base URL:** `https://api.todoist.com/rest/v2`

### Get Today's Tasks
```powershell
$headers = @{ Authorization = "Bearer $env:TODOIST_API_TOKEN" }
$tasks = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/tasks?filter=today" -Headers $headers
$tasks | ForEach-Object { Write-Host "$($_.id): $($_.content) | Priority: $($_.priority)" }
```

### Get Overdue Tasks
```powershell
$headers = @{ Authorization = "Bearer $env:TODOIST_API_TOKEN" }
$tasks = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/tasks?filter=overdue" -Headers $headers
$tasks | ForEach-Object { Write-Host "$($_.id): $($_.content) | Priority: $($_.priority)" }
```

### List Projects (with hierarchy)
```powershell
$headers = @{ Authorization = "Bearer $env:TODOIST_API_TOKEN" }
$projects = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/projects" -Headers $headers
$projects | ForEach-Object { Write-Host "$($_.id): $($_.name) | Parent: $($_.parent_id)" }
```

### Complete a Task
```powershell
$headers = @{ Authorization = "Bearer $env:TODOIST_API_TOKEN" }
Invoke-RestMethod -Method Post -Uri "https://api.todoist.com/rest/v2/tasks/TASK_ID/close" -Headers $headers
```

## Task Priority Values

- 4 = P1 (Urgent)
- 3 = P2 (High)
- 2 = P3 (Medium)
- 1 = P4 (Normal/default)
