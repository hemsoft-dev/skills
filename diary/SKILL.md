---
name: diary
description: "V2.4 - Captures daily accomplishments, goals, and reflections with Todoist integration. Auto-includes weather, ALL news headlines (5-7 per category: US, World, AI), Slack highlights from 18 monitored channels, and watchlist updates. Supports meeting notes creation with auto-formatted markdown files. Filters out routine tasks tagged with @Regular Chores. Structured Work/Personal/Personal Reflections format with consistent subsections. Keeps entries high-level and summarized. Queries user for missing content. Omits Work section on Saturdays; Sundays only include Work → Tomorrow's Goals. NEVER removes files without user consent."
---

# Diary

Expert in daily journaling that integrates with Todoist to capture what you've accomplished and what your goals are. Automatically includes weather and news context from the today skill.

## ⚠️ CRITICAL: File Management

**NEVER delete or remove any diary entry files without explicit user consent.**

Diary entries are valuable personal records. Before removing any `.md` files from `entries/` or `History/`:

1. Always ask the user first
2. Explain what will be deleted and why
3. Wait for explicit approval

## Creating New Entries

When creating a new diary entry:

1. **Copy the template**: Use `yyyy-mm-dd.md` as the base template
2. **Replace placeholders**: Fill in date-specific values (`{YYYY-MM-DD}`, `{Weekday}`, etc.)
3. **Run weather script**: Execute `Get-Today.ps1` for current weather and forecast
4. **Gather Todoist tasks**: Use `Get-TodoistCompleted.ps1` for completed tasks
5. **Get Slack highlights**: Use the slack skill to retrieve 5 important messages
6. **Fetch news**: Gather 5-7 headlines each for US, World, and AI news
7. **Check watchlist**: Use watchlist skill for any updates
8. **Save to**: `entries/{YYYY-MM-DD}.md`

**Template location**: `~/.claude/skills/diary/yyyy-mm-dd.md`

## Entry Structure

All diary entries follow the template at `yyyy-mm-dd.md`. Key sections:

- **Today's Highlight**: Featured news article with user context
- **Slack Highlights**: 5 bullet points from today's messages
- **Weather**: Current conditions and 3-day forecast (from `Get-Today.ps1`)
- **News Headlines**: 5-7 items each for US, World, AI (last 24 hours only)
- **Work**: Work Done, Tomorrow's Goals
- **Personal**: Work Done, Tomorrow's Goals
- **Personal Reflections**: Freeform thoughts

**CRITICAL:** If any section is empty after pulling data, explicitly ask the user:

- "What's today's highlight article? (headline + URL + optional context)"
- "Anything else for Work Done today?"
- "Any work goals for tomorrow I should add?"
- "Any work reflections or proud moments?"
- "Did you accomplish anything personal today?"
- "Any personal goals for tomorrow?"
- "Any personal thoughts or learnings?"
- "Any overall reflections about today?"

## Weekend Work Section Handling

**Saturday (Day 6):**

- **Omit entire Work section** - No Work Done, no Tomorrow's Goals, no Reflections
- Only include Personal section and Personal Reflections

**Sunday (Day 0):**

- Include Work section ONLY for "Tomorrow's Goals" (Monday preparation)
- Omit "Work Done" and "Reflections" subsections
- Personal section remains fully populated

**Monday-Friday (Days 1-5):**

- Include all Work sections as normal

**Detection logic:**

```powershell
$dayOfWeek = (Get-Date).DayOfWeek.value__  # 0=Sunday, 6=Saturday
if ($dayOfWeek -eq 6) {
    # Saturday: Skip entire Work section
} elseif ($dayOfWeek -eq 0) {
    # Sunday: Only include Work → Tomorrow's Goals
} else {
    # Weekdays: Full Work section
}
```

## Entry Style

**Keep entries high-level and summarized:**

- Focus on what was accomplished, not detailed steps or file names
- Example: "Enhanced Todoist skill with task management scripts" NOT "Created Get-TodoistCompleted.ps1, Get-TodoistSummary.ps1..."
- Capture the essence and impact, not granular implementation details
- Think: What would be useful to remember in 6 months?

**Exclude routine maintenance tasks:**

- Do NOT include daily health routines (medications, supplements)
- Do NOT include basic self-care tasks (exercise, sleep, meals)
- Do NOT include recurring household chores
- Focus on meaningful accomplishments and intentional goals only

**Personal Reflections can include:**

- Feelings about the day's progress and accomplishments
- Personal concerns or worries (family, relationships, health)
- Gratitude or positive observations
- Stress, anxiety, or challenges outside of work
- Both professional satisfaction AND personal life concerns

## Core Functions

### 0. Weather and News Integration (today skill)

**ALWAYS run the today skill first** to gather weather and news context.

**Step 1: Execute Today Skill**

Run the PowerShell script from the today skill:

```powershell
& "$env:USERPROFILE\.claude\skills\today\Get-Today.ps1"
```

This fetches current date, time, weather, and 3-day forecast.

**Step 2: Launch News Sub-Agents**

The today skill automatically launches 3 parallel sub-agents to gather:

- US News headlines (last 24 hours)
- World News headlines (last 24 hours)
- AI News headlines (last 24 hours)

**Step 3: Gather Slack Highlights**

Use the slack skill to retrieve today's most interesting messages from these channels:

**Monitored Channels:**

- All DMs
- #ai-chapter
- #dev-ex-private
- #prod-eng-devex-private
- #productivity-engineering-private
- #productivity-engineering-public
- #relias-cortex-external
- #dev-tribe
- #next-deployment
- #swatteam
- #systems-mangement
- #architecture
- #dev-env-help
- #platform
- #product-engineering
- #relias-engineering
- #software-quality
- #sonarcloud-public

**Method:**
Use `Get-SlackChannelMessages.ps1` to check recent messages (10-15 per channel):

```powershell
# Example: Check dev-tribe for today's messages
& "$env:USERPROFILE\.claude\skills\slack\scripts\Get-SlackChannelMessages.ps1" -Channel "dev-tribe" -Count 10 -MaxThreadReplies 0
```

**Slack Highlight Criteria:**

- Exclude routine/low-value messages (bot notifications, simple acks)
- Prioritize: decisions made, action items, important announcements
- Include channel name for context: `- **[#channel-name](link)**: Brief summary of message`
- Aim for 5 highlights; if fewer than 5 interesting items, that's fine
- Focus on messages that would be useful to remember later
- Include direct links to messages when available

**Step 4: Check Watchlist for Updates**

Use the watchlist skill to check for any updates on tracked items:

- Review the WATCHLIST.md file for items marked as "Active" or "Watching"
- For each item, check its key resources for updates from today
- Only include items that have actual updates/changes
- Format as: `- **{Item Name}**: {Brief summary of what changed/updated}`
- If no watchlist items have updates today, omit this section entirely

**Step 5: Include Full Output in Diary Entry**

Copy the complete output from the today skill into the diary entry, including:

- Today's Highlight (top news story)
- Slack Highlights (5 bullet points)
- Watchlist Updates (items with changes/updates from today)
- Weather section (current conditions + 3-day forecast)
- News Headlines (all three categories with tables)

Copy the **complete, unfiltered output** from the today skill into the diary entry, including:

- Today's Highlight (top news story)
- Weather section (current conditions + 3-day forecast)
- **News Headlines - ALL categories with ALL headlines** (typically 5-7 per category):
  - 🇺🇸 US News (full table with all headlines)
  - 🌍 World News (full table with all headlines)
  - 🤖 AI News (full table with all headlines)
- News gathering metadata footer

**CRITICAL:** Include **every single headline** returned by the today skill's sub-agents. Do not truncate, summarize, or filter the news tables. The diary entry should contain the complete news snapshot from that day.

This provides valuable context for future reflection on what was happening in the world when you wrote each entry.

**Note:** If the user provides a specific highlight article, use that instead of the top news story from today skill.

### 1. Meeting Notes Creation

When user requests to save meeting notes (flexible phrasing):

- "Add meeting notes for '{title}'"
- "Create meeting notes for '{title}'"
- "Meeting notes: '{title}'"
- "Save meeting notes '{title}'"

**Workflow:**

**Step 1: Detect Request**

- Identify meeting notes request with flexible pattern matching
- Extract meeting title from user's request
- Extract content (the "lots of text" following the title)

**Step 2: Generate Filename**

- Convert title to slug format: lowercase, replace spaces/special chars with hyphens
- Examples:
  - `"AI Weekly SyncUp - Harbinger"` → `ai-weekly-syncup-harbinger`
  - `"Q1 2026 Planning (Budget & Goals)"` → `q1-2026-planning-budget-goals`
  - `"Team Retro #3 [Action Items]"` → `team-retro-3-action-items`
- Format: `entries/{YYYY-MM-DD}-{slug}.md`

**Step 3: Confirm with User**
Ask for confirmation before creating the file:

```
I'll create a meeting notes file:
- Title: {Original Title}
- File: entries/{YYYY-MM-DD}-{slug}.md
- Content: {X} lines of notes

Proceed?
```

**Step 4: Format Content**

- Assume raw text input
- Format into clean markdown:
  - Add level 1 header with meeting title and date
  - Detect and format lists (bullet points, numbered items)
  - Preserve paragraphs and spacing
  - Detect and format common meeting sections (Attendees, Action Items, Decisions, etc.)
  - Clean up excessive whitespace
- Add footer: `*Meeting notes created with diary skill v1.7*`

**Step 5: Create File**

- Write to `entries/{YYYY-MM-DD}-{slug}.md`

**Step 6: Provide Receipt**
Confirm completion with details:

```
✅ Meeting notes saved!
- File: entries/{YYYY-MM-DD}-{slug}.md
- Title: {Original Title}
- Date: {YYYY-MM-DD}
- Size: {X} lines
```

**Step 7: Offer to Update Main Diary Entry**
Ask if user wants to add a reference to the meeting in today's diary entry:

```
Would you like me to add an entry about this meeting to today's diary (entries/{YYYY-MM-DD}.md)?
I'll add it to the Work Done section with a link to the meeting notes.
```

If confirmed:

- Check if `entries/{YYYY-MM-DD}.md` exists
- If it exists, add to appropriate section (Work Done or Personal Done based on context)
- If it doesn't exist, offer to create a basic diary entry
- Add a line like: `- Attended {Meeting Title} ([meeting notes](entries/{YYYY-MM-DD}-{slug}.md))`

**Step 8: Offer to Create Todoist Tasks**
If follow-up tasks are detected in the meeting notes, offer to add them:

```
I found {X} follow-up tasks in the meeting notes. Would you like me to add them to Todoist?
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
# AI Weekly SyncUp - Harbinger
*2026-01-09*

{Formatted content from user}

---
*Meeting notes created with diary skill v1.7*
```

### 2. Daily Entry Creation Workflow

When user wants to record today's diary entry, follow this process:

**Step 0: Run Today Skill** *(NEW)*

Execute the today skill to get weather and news context (see section 0 above).

**Step 1: Pull Todoist Data**

Use PowerShell scripts from todoist skill:

- `Get-TodoistCompleted.ps1` - Completed tasks today
- `Get-TodoistTasks.ps1` with filter `tomorrow` - Tomorrow's tasks
- `Get-TodoistUpdated.ps1` - Tasks with description updates today

**Step 2: Apply Filters**

Load `exclusion.json` and filter out:

- Tasks tagged with @Regular Chores
- Tasks matching excludeTaskPatterns
- Health/medication tasks
- Exercise/self-care tasks
- Submit timesheet tasks

**Step 3: Categorize Tasks**

- **Work**: Project ID 2221463722 and children
- **Personal**: Project ID 2200472795 or other non-work projects

**Step 4: Generate Initial Entry**

Create diary entry starting with weather/news section from today skill, followed by all required sections populated from Todoist data.

**Step 5: Query for Missing Content**

For each section that's empty or sparse, ask user:

- Work Done: "Anything else you accomplished at work today?"
- Work Tomorrow's Goals: "Any work goals for tomorrow?"
- Work Reflections: "Any work reflections? Proud of anything you built?"
- Personal Work Done: "Did you accomplish anything personal today?"
- Personal Tomorrow's Goals: "Any personal goals for tomorrow?"
- Personal Reflections: "Any personal thoughts or learnings?"
- Personal Reflections (top-level): "How are you feeling about today overall? Anything on your mind?"

**Step 6: Save Entry**

Write to `entries/{YYYY-MM-DD}.md` with proper formatting.

### 3. Review Past Entries

When user wants to review previous entries:

- Read from `entries/{YYYY-MM-DD}.md` files
- Summarize patterns, progress, recurring themes
- Compare goals vs accomplishments over time
- Identify trends in work/personal balance

## Task Filtering Configuration

**Location:** `{skill-directory}/exclusion.json`

```json
{
  "excludeLabels": ["@Regular Chores"],
  "excludeTaskPatterns": ["submit time sheet", "submit timesheet"],
  "excludeRecurring": false
}
```

**Filtering Rules:**

- **excludeLabels**: Tasks with these labels are completely filtered out
- **excludeTaskPatterns**: Task names matching these patterns (case-insensitive) are excluded
- **excludeRecurring**: If true, automatically exclude all recurring tasks

**Apply filters to BOTH:**

1. Work Done sections (completed tasks)
2. Tomorrow's Goals sections (upcoming tasks)

**Hard-coded exclusions (always filter):**

- Daily health routines (medications, supplements, exercise)
- Basic self-care (sleep tracking, meals)
- Recurring household chores
- Submit timesheet tasks
- Egg Inc game tasks (chores/entertainment, not work)

## Task Categorization

Tasks are categorized by project hierarchy:

- **Work**: Tasks under project "Work" (id: 2221463722) and its children
- **Personal**: Tasks under "Home" (id: 2200472795) or other non-work projects

**CRITICAL:** Always verify project membership before categorizing. Use the project_id field from Todoist task data:

- If project_id = 2221463722 (or child of Work) → Work section
- If project_id = 2200472795 (Home) → Personal section
- All other projects → Personal section

**Never assume** a task is work-related based on content alone. The project_id is the authoritative source.

Use project parent_id to determine category.

## Todoist Task Creation (Meeting Follow-ups)

When creating tasks from meeting notes:

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

**Known Labels:**

- `Todo` - Default task label (use this for meeting follow-ups)
- `Regular Chores` - Routine maintenance (excluded from diary)
- `AI` - AI-related tasks
- `AI Chapter` - AI chapter work
- `Event` - Event-related tasks
- `Relias Assistant` - Relias Assistant work
- `Software Dev Chapter` - Software development chapter

Query available labels via API before suggesting:

```powershell
$labels = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/labels" -Headers @{ Authorization = "Bearer $env:TODOIST_API_TOKEN" }
$labels | ForEach-Object { $_.name }
```

**Create Task API Call:**

```powershell
# Load token from environment (may not be in $env: on fresh sessions)
$env:TODOIST_API_TOKEN = [System.Environment]::GetEnvironmentVariable('TODOIST_API_TOKEN', 'User')

$headers = @{ 
    Authorization = "Bearer $env:TODOIST_API_TOKEN"
    "Content-Type" = "application/json"
}

$body = @{
    content = "Task title"
    description = "Task description with owner and context"
    project_id = "2221463722"  # Use appropriate project ID
    due_string = "tomorrow"    # Or specific date: "2026-01-15"
    priority = 3               # 4=P1, 3=P2, 2=P3, 1=P4
    labels = @("Todo")         # MUST include labels in initial creation, not after
} | ConvertTo-Json

$task = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/tasks" -Headers $headers -Method Post -Body $body

Write-Host "✓ Created task: $($task.content) (ID: $($task.id))"
Write-Host "  Labels: $($task.labels -join ', ')"
Write-Host "  Link: https://todoist.com/app/task/$($task.id)"
```

**Important Best Practices:**

1. **Include labels in initial creation** - Adding labels after creation doesn't work reliably
2. **Never retry automatically** - Only retry if user explicitly requests it
3. **Check for duplicates** - After creation, verify no duplicate tasks exist with same content
4. **Load token properly** - Use `[System.Environment]::GetEnvironmentVariable('TODOIST_API_TOKEN', 'User')` if `$env:` is empty

**Due Date Parsing:**

- `today` → `"due_string": "today"`
- `tomorrow` → `"due_string": "tomorrow"`
- `monday` / `next week` → `"due_string": "monday"` / `"due_string": "next week"`
- Custom date → `"due_string": "2026-01-15"` (YYYY-MM-DD format)
- No date → Omit `due_string` field

## Todoist Integration Scripts

Use PowerShell scripts from todoist skill:

- `Get-TodoistCompleted.ps1` - Get completed tasks for specific date
- `Get-TodoistTasks.ps1` - Active tasks with filter queries
- `Get-TodoistUpdated.ps1` - Tasks with description field updates
- `Get-TodoistSummary.ps1` - Comprehensive task overview
- `Get-TodoistComments.ps1` - Get comments for tasks/projects

## File Structure

```
diary/
├── SKILL.md
├── exclusion.json
└── entries/
    ├── 2026-01-06.md  (TEMPLATE REFERENCE - Daily diary)
    ├── 2026-01-07.md
    ├── 2026-01-09-ai-weekly-syncup-harbinger.md  (Meeting notes)
    └── ...
```

**Formats:**

- Daily diary: `history/yyyy-mm-dd.md`
- Meeting notes: `history/yyyy-mm-dd-{meeting-title-slug}.md`

## Example Entry (Template Reference)

See `entries/2026-01-11.md` for the canonical template showing:

- Full weather and news integration from today skill
- Proper section structure and hierarchy
- Appropriate level of detail (high-level, not granular)
- Balance of accomplishments and concerns
- How to document skills created/enhanced
- Work in progress tracking format
- Personal Reflections including both positive and negative feelings

## User Interaction Prompts

**Initial prompt:**
"Let's create today's diary entry. I'll gather weather, news, and your Todoist data."

**For missing content:**

- "Anything else you accomplished at work today?"
- "Any work goals for tomorrow?"
- "How do you feel about today's work? Proud of anything?"
- "Did you accomplish anything personal today?"
- "Any personal goals for tomorrow?"
- "Any personal thoughts or learnings from today?"
- "Overall, how are you feeling about today? Anything on your mind?"

**Keep prompts conversational and natural - don't ask all at once, build the entry iteratively.**

## ALWAYS: Log Skill Usage

After creating a diary entry, log to todoist skill's `entries/{YYYY-MM-DD}.md`:

```

After creating meeting notes, log to todoist skill's `entries/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - Created meeting notes
Saved meeting notes: {meeting-title} → entries/{YYYY-MM-DD}-{slug}.md
```markdown
## {HH:MM} - Created diary entry
Generated daily journal entry with Work/Personal/Personal Reflections structure
```
