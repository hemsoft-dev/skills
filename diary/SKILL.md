---
name: diary
description: "V2.16 - Captures daily accomplishments, goals, and reflections with Todoist integration. Auto-includes weather, ALL news headlines (5-7 per category: US, World, AI, Danish) with mandatory source diversification (max 2 per source, 3-4 sources minimum) and Simon Willison priority for AI News, comprehensive Slack highlights from 18 monitored channels (8-12+ highlights), watchlist updates, Daily Numbers (Dow Jones, S&P 500, Relias Repo Counts), trending GitHub repos, and Software Watchlist with 68% automation. Structured Work/Personal/Personal Reflections format. Omits Work section on Saturdays; Sundays only include Work → Tomorrow's Goals. NEVER removes files without user consent."
---

# Diary

Expert in daily journaling that integrates with Todoist to capture what you've accomplished and what your goals are. Automatically includes weather and news context from the today skill.

## ALWAYS: Retrospective Check

Before completing, reflect on this interaction:

1. Were new patterns or edge cases discovered?
2. Could instructions be clearer?
3. Do scripts need improvements or bug fixes?
4. Should new capabilities be added?

If improvements identified:

- Present proposed changes with clear rationale
- Wait for user approval before applying
- Keep skill concise (remove/condense when adding if possible)
- Version bump SKILL.md if changes applied

## ⚠️ CRITICAL: File Management

**NEVER delete or remove any diary entry files without explicit user consent.**

Diary entries are valuable personal records. Before removing any `.md` files from `entries/` or `History/`:

1. Always ask the user first
2. Explain what will be deleted and why
3. Wait for explicit approval

## Creating New Entries

**Quick Start:** Use `config/yyyy-mm-dd.md` template → Run `scripts/Get-Today.ps1` → Gather Todoist/Slack/News/Watchlist data → Save to `entries/{YYYY-MM-DD}.md`

**Template location**: `~/.claude/skills/diary/config/yyyy-mm-dd.md`

## Entry Structure

All diary entries follow the template at `config/yyyy-mm-dd.md`. Key sections:

- **Today's Highlight**: Featured news article with user context
- **Slack Highlights**: 5 bullet points from today's messages
- **Weather**: Current conditions and 3-day forecast (from `Get-Today.ps1`)
- **News Headlines**: 5-7 items each for US, World, AI, and Danish News (last 24 hours only)
- **Daily Numbers**: Stock market data (weekdays) and Relias repo counts (GitHub and Bitbucket with day-over-day deltas)
- **Top 5 Trending GitHub Repos**: Current trending repositories with actual star counts (use web search to get real data from <https://github.com/trending>)
- **Software Watchlist**: Version updates for monitored software (last 7 days)
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

**🚨 CRITICAL: News Quality Requirements**

**Source Diversification (MANDATORY):**

- **Maximum 2 items per source** (30% cap per source)
- **Minimum 3-4 different sources** per category when returning 5-7 items
- If multiple stories are equally significant, prioritize the one from a less-represented source
- **Verify source distribution** before finalizing news selection

**AI News Priority Sources:**

- **ALWAYS check Simon Willison's Weblog (simonwillison.net)** - This is priority source #1 for AI News
- If Simon Willison has relevant posts from the last 24 hours, they MUST be included
- Then diversify across other sources: The Verge AI, Ars Technica AI, TechCrunch AI, Wired AI, MIT Technology Review, VentureBeat AI

**Verification:**

- Count items per source before including in diary
- Reject any news selection that violates diversification rules
- If Simon Willison is missing from AI News, explicitly check why and include if content exists

**Step 3: Gather Slack Activity**

Use the slack skill to retrieve comprehensive coverage of today's substantive activity from these channels:

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
**CRITICAL: Always filter by date when gathering daily highlights.** Use `Search-SlackMessages.ps1` with date filters:

```powershell
# Example: Check dev-tribe for messages on today's date ONLY
# IMPORTANT: 'after' is EXCLUSIVE - to get messages FROM today, use yesterday as 'after' value
$today = Get-Date -Format "yyyy-MM-dd"
$yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
$tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
& "$env:USERPROFILE\.claude\skills\slack\scripts\Search-SlackMessages.ps1" -Query "in:#dev-tribe after:$yesterday before:$tomorrow -from:@email -from:@datadog" -Count 20 -OutputFormat List
```

**⚠️ DATE FILTERING REQUIREMENT:**

- **CRITICAL**: `after:` is EXCLUSIVE - to get messages FROM Jan 16, use `after:2026-01-15` (the day before)
- **CRITICAL**: `before:` is EXCLUSIVE - to get messages UP TO Jan 16, use `before:2026-01-17` (the day after)
- **ALWAYS** use `after:(target-1day) before:(target+1day)` in search queries for daily highlights
- **ALWAYS** verify message timestamps match the target date before including in diary
- **NEVER** include messages from previous days, even if they appear in recent results
- If `Get-SlackChannelMessages.ps1` is used, manually filter results by checking timestamps
- If no messages found for the target date, note "No significant Slack activity" - don't include old messages

**Slack Activity Criteria:**

**IMPORTANT: Provide exhaustive coverage of substantive Slack activity across all monitored channels.**

**Priority Content (in order):**

1. **PSAs and FYI posts**: Public service announcements, general information, important notices (e.g., "Release branches merged", "Deployment starting", "New process announced")
2. **Problems being addressed**: Solutions provided, troubleshooting resolutions, help given with outcomes
3. **Problems being asked**: Technical issues raised, help requests, blockers identified
4. **Decisions and action items**: Technical decisions made, architecture discussions, planning outcomes
5. **Announcements**: Team changes, deployment notifications, process updates

**What to INCLUDE:**

- Technical discussions with substance (architecture decisions, implementation strategies)
- Help requests AND their resolutions (not just the ask, but the solution)
- PSAs and informational posts that provide context or awareness
- Deployment notifications (starting, completed, verification)
- Process changes or updates
- Team coordination and planning

**What to EXCLUDE:**

- Bot notifications (email, datadog, pagerduty alerts)
- Simple acknowledgments ("thanks", "sounds good")
- Pleasantries without substance
- Channel membership changes (unless significant)

**Format:**

- `- **[#channel-name](link)**: {Comprehensive summary that captures the problem/solution/information}`
- **Read full thread context** to understand complete story, not just individual messages
- Capture BOTH problem and solution when available
- For PSAs, include the key information being communicated
- For technical discussions, summarize the decision or conclusion reached

**Coverage Goal:**

- Aim for 8-12+ activity items per day (more if substantive activity warrants)
- Cast a wide net across all monitored channels
- Prioritize information value over message count
- **Verify date**: Each message must match target date

**Section Header:** Use "### 💬 Slack Activity" in diary entries

**Step 4: Check Watchlist for Updates**

Use the watchlist skill to check for any updates on tracked items:

- Review the WATCHLIST.md file for items marked as "Active" or "Watching"
- For each item, check its key resources for updates from today
- Only include items that have actual updates/changes
- Format as: `- **{Item Name}**: {Brief summary of what changed/updated}`
- If no watchlist items have updates today, omit this section entirely

**Step 4.5: Gather Daily Numbers**

**Stock Market (weekdays only):** Dow Jones and S&P 500 closing prices with change/% change

**Source:** Use Google Finance (<https://www.google.com/finance/beta>) to fetch current market data. Fetch the page directly using mcp_web_fetch tool to get the most recent closing prices and percentage changes for:

- Dow Jones Industrial Average (DJI)
- S&P 500 Index (SPX)

Display format: "{Index Name}: {closing_price} ({point_change}, {percent_change}%)"
Example: "Dow Jones: 49,384.01 (+306.78, +0.63%)"

**Relias Repo Count (daily):**

- **Unified Script:** `& "$env:USERPROFILE\.claude\skills\diary\scripts\Get-ReliasRepoCounts.ps1"`
  - Fetches both GitHub and Bitbucket repo counts
  - Compares to yesterday's counts (stored in `config/repo-counts.json`)
  - Displays deltas in parentheses: "GitHub: 175 (+2), Bitbucket: 562 (-1)"
  - Updates tracking file with today's counts for tomorrow's comparison
  - **Requires:** `BITBUCKET_USERNAME` and `BITBUCKET_API_KEY` environment variables

**Format:** Weekdays include both market + repo counts; weekends/holidays only include repo counts. Display as "GitHub: {count} ({delta}), Bitbucket: {count} ({delta})" where delta shows change from yesterday (e.g., +2, -1, or 0)

**Step 4.6: Check Software Watchlist**

**🚨 CRITICAL: ACTUALLY CHECK FOR UPDATES FIRST!** Do not just read the JSON file and assume there are no updates. You MUST actively check for new versions using the appropriate method for each software:

**Checking Methods (MUST execute before reading JSON):**

1. **github_releases**: Run `gh release list --repo owner/repo --limit 5` to get latest releases
2. **github_releases_prerelease**: Filter GitHub releases for preview/pre-release tags (excludes nightly for Gemini CLI)
3. **rss**: Parse RSS feed to extract version from title or date (supports Slack version extraction)
4. **web**: Use WebSearch for latest version (e.g., "Docker Desktop latest version January 2026")
5. **web_scrape**: Fetch static HTML and parse with regex (only works for non-JS pages)
6. **cli**: Execute the version command locally (e.g., `node --version`, `docker --version`)

**Automated Script Support:** Use `Get-SoftwareUpdates.ps1` to check all items with github_releases, github_releases_prerelease, and rss methods (15/22 items = 68% automated)

**QUALITY STANDARD:** Verify versions exist, read actual release notes, extract 3-7 specific changes (no generic "bug fixes/improvements"), handle special cases (CVEs for security, replacements for deprecations), be honest if vendor provides no details.

**Configuration:** Load `config/software-watchlist.json` with `monitored_software` array (name, changelog_url, check_method, last_displayed_date, last_displayed_version)

**IMPORTANT:** WebFetch may return stale content (especially `raw.githubusercontent.com`). For GitHub repos, use `gh release list` first. Verify suspicious versions with WebSearch. **NEVER use "Check manually"** - always extract real version data (semantic version, release date, or month identifier).

**Incremental Tracking:**

1. **First Run** (`last_displayed_version` is null): Show ALL software in alphabetical order, update tracking fields after rendering
2. **Subsequent Runs**: Compare actual current versions against `last_displayed_version`, only show software with version changes, update tracking fields for displayed items
3. **After determining updates**: Only THEN read the JSON to see what should be displayed based on tracking

**🚨 ZERO UPDATES = ERROR CONDITION:** If you find ZERO software updates when checking all 22+ monitored items, this indicates a problem with the checking process itself, not that no software was updated. In this case:

1. Run diagnostic script: `& "$env:USERPROFILE\.claude\skills\diary\scripts\Test-SoftwareWatchlist.ps1"`
2. Report the issue: "⚠️ Software watchlist check returned zero updates, which indicates a checking process failure. Diagnostic results: [output]"
3. Do NOT render "No software updates" - instead show the diagnostic information

**Highlights:** 3-7 specific changes from release notes (NEVER generic "bug fixes/improvements"). Answer: "What can I do now that I couldn't before?"

**Special Cases:**

- **Security**: List CVE numbers (e.g., "CVE-2025-55132: permission model bypass")
- **Deprecations**: State replacement (e.g., "Final release, use X instead")
- **Vague vendor notes**: Acknowledge explicitly (e.g., "Slack provides no details")

**Format:** `| [Software](url) | version | date | highlights | [Notes](release-url) |`

After rendering, update JSON with new `last_displayed_date` and `last_displayed_version`. Maintain alphabetical order.

**Step 5: Include Full Output**

Copy **complete, unfiltered output** from today skill: Today's Highlight, Weather, ALL News Headlines (5-7 per category: US/World/AI), Slack Highlights, Watchlist Updates. Include every headline for future context. Use user-provided highlight if specified.

### 1. Meeting Notes Creation

**Workflow:** Detect request → Generate slug filename (`entries/{YYYY-MM-DD}-{slug}.md`) → Confirm → Format content (markdown with header/date/footer) → Create file → Offer to update main diary → Offer to create Todoist tasks

**Slug Examples:** "AI SyncUp" → `ai-syncup`, "Q1 Planning (Goals)" → `q1-planning-goals`

**Todoist Integration:** Detect action items → Ask to add each (due date, project, priority, labels) → Confirm with task ID

### 2. Daily Entry Creation Workflow

1. **Run today skill** (weather/news)
2. **Pull Todoist data** (`Get-TodoistCompleted.ps1`, `Get-TodoistTasks.ps1`, `Get-TodoistUpdated.ps1`)
3. **Apply filters** (`exclusion.json`: @Regular Chores, health/exercise/timesheet tasks)
4. **Categorize** (Work: 2221463722, Personal: 2200472795 or others)
5. **Generate entry** with weather/news/Todoist data
6. **Query for gaps** (work/personal done/goals/reflections)
7. **Save** to `entries/{YYYY-MM-DD}.md`

### 3. Review Past Entries

When user wants to review previous entries:

- Read from `entries/{YYYY-MM-DD}.md` files
- Summarize patterns, progress, recurring themes
- Compare goals vs accomplishments over time
- Identify trends in work/personal balance

## Todoist Integration

**Task Categorization:**

- **Work**: Tasks under project "Work" (id: 2221463722) and its children
- **Personal**: Tasks under "Home" (id: 2200472795) or other non-work projects
- **CRITICAL:** Always verify project membership using project_id field - never assume based on content alone

**Task Filtering (`exclusion.json`):**

- **excludeLabels**: Filter out tasks with these labels (e.g., "@Regular Chores")
- **excludeTaskPatterns**: Case-insensitive pattern matching (e.g., "submit time sheet")
- **Hard-coded exclusions**: Daily health routines, basic self-care, recurring chores, timesheet tasks, Egg Inc game tasks
- **Apply filters to BOTH** Work Done and Tomorrow's Goals sections

**Scripts:** `Get-TodoistCompleted.ps1`, `Get-TodoistTasks.ps1`, `Get-TodoistUpdated.ps1`, `Get-TodoistSummary.ps1`, `Get-TodoistComments.ps1`

**Task Creation (Meeting Follow-ups):**

- Projects: Work (2221463722), Home (2200472795)
- Labels: Todo, Regular Chores, AI, AI Chapter, Event, Relias Assistant, Software Dev Chapter
- Priority: 4=P1, 3=P2, 2=P3, 1=P4
- Include labels in initial creation (not after), check for duplicates, never auto-retry

## Software Watchlist Configuration

**File:** `config/software-watchlist.json` - See Step 4.6 for detailed checking procedures.

**Adding Software:** Insert alphabetically with: `name`, `changelog_url`, `check_method`, `notes`, `last_displayed_date`, `last_displayed_version`

**Tracking:** First run shows all software; subsequent runs only show version changes. Update JSON after rendering.

## File Structure

```
diary/
├── SKILL.md
├── config/
│   ├── yyyy-mm-dd.md (template)
│   ├── exclusion.json
│   ├── software-watchlist.json
│   └── repo-counts.json (tracks daily repo counts for delta calculation)
├── scripts/
│   ├── Get-ReliasRepoCounts.ps1 (unified script for GitHub + Bitbucket with deltas)
│   ├── Get-BitbucketRepoCount.ps1 (Bitbucket-only script)
│   ├── Get-SoftwareUpdates.ps1 (automated update checker - 68% coverage)
│   └── Test-SoftwareWatchlist.ps1 (diagnostic tool)
└── entries/
    ├── 2026-01-06.md  (TEMPLATE REFERENCE - Daily diary)
    ├── 2026-01-07.md
    ├── 2026-01-09-ai-weekly-syncup-harbinger.md  (Meeting notes)
    └── ...
```

**Formats:**

- Daily diary: `entries/yyyy-mm-dd.md`
- Meeting notes: `entries/yyyy-mm-dd-{meeting-title-slug}.md`

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

**Initial:** "Let's create today's diary entry. I'll gather weather, news, and your Todoist data."

**For gaps:** Ask about work done/goals/reflections, personal done/goals/reflections, overall feelings. Keep conversational, build iteratively.
