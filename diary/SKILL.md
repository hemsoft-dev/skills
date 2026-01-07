---
name: diary
description: V1.6 - Captures daily accomplishments, goals, and reflections with Todoist integration. Includes highlighted news section. Filters out routine tasks tagged with @Regular Chores. Structured Work/Personal/Personal Reflections format with consistent subsections. Keeps entries high-level and summarized. Queries user for missing content.
---

# Diary

Expert in daily journaling that integrates with Todoist to capture what you've accomplished and what your goals are.

## Entry Template

**REQUIRED STRUCTURE** - Every diary entry must contain all these sections:

```markdown
# {YYYY-MM-DD Full Date}

## 🎯 Today's Highlight

**[{Headline}]({url})**

{Optional 1-2 sentence context provided by user}

---

## Work

### Work Done
{Content required - query user if empty}

### Tomorrow's Goals
{Content required - query user if empty}

### Reflections
{Content required - query user if empty}

## Personal

### Work Done
{Content required - query user if empty}

### Tomorrow's Goals
{Content required - query user if empty}

### Reflections
{Content required - query user if empty}

## Personal Reflections

{Content required - query user if empty}

---
*Entry created with diary skill v{version} | todoist v{version}*
```

**CRITICAL:** If any section is empty after pulling Todoist data, explicitly ask the user:
- "What's today's highlight article? (headline + URL + optional context)"
- "Anything else for Work Done today?"
- "Any work goals for tomorrow I should add?"
- "Any work reflections or proud moments?"
- "Did you accomplish anything personal today?"
- "Any personal goals for tomorrow?"
- "Any personal thoughts or learnings?"
- "Any overall reflections about today?"

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

### 1. Daily Entry Creation Workflow

When user wants to record today's diary entry, follow this process:

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

Create diary entry with all required sections populated from Todoist data.

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

Write to `history/{YYYY-MM-DD}.md` with proper formatting.

### 2. Review Past Entries

When user wants to review previous entries:
- Read from `history/{YYYY-MM-DD}.md` files
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

## Task Categorization

Tasks are categorized by project hierarchy:
- **Work**: Tasks under project "Work" (id: 2221463722) and its children
- **Personal**: Tasks under "Home" (id: 2200472795) or other non-work projects

Use project parent_id to determine category.

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
└── history/
    ├── 2026-01-06.md  (TEMPLATE REFERENCE)
    ├── 2026-01-07.md
    └── ...
```

Format: `history/yyyy-mm-dd.md`

## Example Entry (Template Reference)

See `history/2026-01-06.md` for the canonical template showing:
- Proper section structure and hierarchy
- Appropriate level of detail (high-level, not granular)
- Balance of accomplishments and concerns
- How to document skills created/enhanced
- Work in progress tracking format
- Personal Reflections including both positive and negative feelings

## User Interaction Prompts

**Initial prompt:**
"Let's create today's diary entry. I'll pull your Todoist data and we'll build it together."

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

After creating a diary entry, log to todoist skill's `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - Created diary entry
Generated daily journal entry with Work/Personal/Personal Reflections structure
```
