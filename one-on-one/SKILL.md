---
name: one-on-one
description: V1.0 - Expert in managing one-on-one meetings including agendas, note-taking, action items, and follow-ups.
---

# One-on-One

Manage one-on-one meetings with structured note-taking, agenda tracking, and action item follow-up.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Core Functions

### 1. Create Meeting Notes

When user requests to save one-on-one meeting notes (flexible phrasing):

- "Add one-on-one notes for '{person}'"
- "Create one-on-one for '{person}'"
- "One-on-one notes: '{person}'"
- "Save one-on-one '{person}'"

**Workflow:**

**Step 1: Detect Request**

- Identify one-on-one notes request with flexible pattern matching
- Extract participant name from user's request
- Extract content (the "lots of text" following the participant name)

**Step 2: Generate Filename**

- Convert name to slug format: lowercase, replace spaces/special chars with hyphens
- Examples:
  - `"John Smith"` → `john-smith`
  - `"Sarah O'Connor"` → `sarah-oconnor`
  - `"Manager Q1 Review"` → `manager-q1-review`
- Format: `history/{YYYY-MM-DD}-{slug}.md`

**Step 3: Confirm with User**

Ask for confirmation before creating the file:

```
I'll create a one-on-one notes file:
- Participant: {Participant Name}
- File: history/{YYYY-MM-DD}-{slug}.md
- Content: {X} lines of notes

Proceed?
```

**Step 4: Format Content**

- Assume raw text input
- Format into clean markdown:
  - Add level 1 header with participant name and date
  - Detect and format lists (bullet points, numbered items)
  - Preserve paragraphs and spacing
  - Detect and format common one-on-one sections (Agenda, Discussion, Action Items, Feedback, Follow-ups)
  - Clean up excessive whitespace
- Add footer: `*One-on-one notes created with one-on-one skill v1.0*`

**Step 5: Create File**

- Write to `history/{YYYY-MM-DD}-{slug}.md`

**Step 6: Provide Receipt**

Confirm completion with details:

```
✅ One-on-one notes saved!
- File: history/{YYYY-MM-DD}-{slug}.md
- Participant: {Participant Name}
- Date: {YYYY-MM-DD}
- Size: {X} lines
```

**Step 7: Offer to Update Main Diary Entry**

Ask if user wants to add a reference to the meeting in today's diary entry:

```
Would you like me to add an entry about this one-on-one to today's diary (history/{YYYY-MM-DD}.md)?
I'll add it to the Work Done section with a link to the meeting notes.
```

If confirmed:

- Check if `history/{YYYY-MM-DD}.md` exists
- If it exists, add to appropriate section (Work Done or Personal Done based on context)
- If it doesn't exist, offer to create a basic diary entry
- Add a line like: `- One-on-one with {Participant Name} ([meeting notes](history/{YYYY-MM-DD}-{slug}.md))`

**Step 8: Offer to Create Todoist Tasks**

If follow-up tasks are detected in the meeting notes, offer to add them:

```
I found {X} follow-up tasks in your one-on-one notes. Would you like me to add them to Todoist?
```

For each task:

1. Show the task title and owner
2. Ask: "Add this task? (y/n/skip all)"
3. If yes, ask: "Due date? (today/tomorrow/monday/next week/custom date/no date)"
4. Ask: "Which project? (Work/Personal/Other)"
5. Query available Todoist projects via API if needed
6. Ask: "Priority? (P1/P2/P3/P4/none)"
7. Suggest appropriate labels based on task content:
   - `@quick_win` for simple tasks
   - `@high_impact` for important items
   - `@needs_research` for investigation tasks
   - `@blocked` for waiting/dependency items
8. Create task via Todoist REST API
9. Confirm creation with task ID and link

**Example Meeting Note Format:**

```markdown
# One-on-One: {Participant Name}
*{YYYY-MM-DD}*

## Agenda
- [ ] Topic 1
- [ ] Topic 2

## Discussion
### Topic 1
{Notes and key points}

### Topic 2
{Notes and key points}

## Action Items
| Owner | Action | Due Date |
|-------|--------|----------|
| {Name} | {Action} | {YYYY-MM-DD} |

## Feedback
- Positive: {feedback}
- Development area: {feedback}

## Follow-up for Next Meeting
- {Item}

---
*One-on-one notes created with one-on-one skill v1.0*
```

### 2. Track Action Items

When creating tasks from one-on-one notes:

**Fetch Available Projects and Labels:**

```powershell
$headers = @{ Authorization = "Bearer $env:TODOIST_API_TOKEN" }
$projects = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/projects" -Headers $headers
$labels = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/labels" -Headers $headers
```

**Known Projects:**

- **Work** (id: 2221463722) - Main work project
- **Home** (id: 2200472795) - Personal tasks
- Query API for current project list and their IDs

**Create Task API Call:**

```powershell
$env:TODOIST_API_TOKEN = [System.Environment]::GetEnvironmentVariable('TODOIST_API_TOKEN', 'User')

$headers = @{ 
    Authorization = "Bearer $env:TODOIST_API_TOKEN"
    "Content-Type" = "application/json"
}

$body = @{
    content = "Task title"
    description = "Task description with owner and context"
    project_id = "2221463722"
    due_string = "tomorrow"
    priority = 3
    labels = @("Todo")
} | ConvertTo-Json

$task = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/tasks" -Headers $headers -Method Post -Body $body
```

**Important Best Practices:**

1. **Include labels in initial creation** - Adding labels after creation doesn't work reliably
2. **Never retry automatically** - Only retry if user explicitly requests it
3. **Check for duplicates** - Verify no duplicate tasks exist with same content

### 3. Review & Prepare for Meetings

Help structure upcoming one-on-ones by:

- Reading from `history/{YYYY-MM-DD}-{slug}.md` files
- Reviewing previous meeting notes for that participant
- Summarizing patterns, progress, recurring themes
- Surfacing pending action items from previous meetings
- Suggesting agenda topics based on discussion history
- Noting any patterns or concerns over time

### 4. Generate Summaries

Create quick summaries of:

- Recent discussions and themes across all one-on-ones
- Ongoing action items across all participants
- Progress on development areas
- Relationship and performance insights
- Trends in conversation topics

## File Structure

```
one-on-one/
├── SKILL.md
└── History/
    ├── 2026-01-09-john-smith.md  (One-on-one notes)
    ├── 2026-01-09-sarah-jones.md
    └── ...
```

**Formats:**

- One-on-one notes: `history/{YYYY-MM-DD}-{participant-slug}.md`

## Best Practices

1. **Document immediately** - Capture notes during or right after the meeting
2. **Specific action items** - Include owner, description, and due date
3. **Two-way feedback** - Note feedback both given and received
4. **Continuity** - Reference previous discussions and progress
5. **Privacy** - Keep sensitive feedback confidential
6. **Todoist integration** - Create follow-up tasks to ensure accountability
