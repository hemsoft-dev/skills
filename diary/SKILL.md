---
name: diary
description: "V2.27 - Captures daily accomplishments, goals, and reflections with Todoist integration. Consumes weather from weather skill output and news from news skill output (no inline gathering). Comprehensive Slack highlights from 18 monitored channels (8-12+ highlights), watchlist updates, Daily Numbers (Dow Jones, S&P 500, Relias Repo Counts), LLM Models (LMSYS Chatbot Arena leaderboard + OpenRouter new releases + Top OpenRouter Apps), trending GitHub repos, Software Watchlist with 68% automation and improved GitHub Copilot Chat handling (extracts 5-15 highlights from VS Code updates page across all major sections), today's productivity metrics (LOC, commits, PRs, code reviews, issues), and screenshots taken today from screenshot skill library. Structured Work/Personal/Personal Reflections format. Omits Work section on Saturdays; Sundays only include Work → Tomorrow's Goals. NEVER removes files without user consent."
---

# Diary

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert in daily journaling that integrates with Todoist to capture what you've accomplished and what your goals are. Consumes weather and news from their respective skill output files — no inline gathering needed.

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
- **Weather**: Current conditions and 3-day forecast (from weather skill output: `~/.agents/skills/weather/output/YYYY-MM-DD.md`)
- **News Headlines**: US, World, AI, and Danish News (from news skill output: `~/.agents/skills/news/output/YYYY-MM-DD.md`)
- **Daily Numbers**: Stock market data (weekdays) and Relias repo counts (GitHub and Bitbucket with day-over-day deltas)
- **LLM Models**: LMSYS Chatbot Arena leaderboard (Overall/Coding/Vision top 5), OpenRouter new model releases (last 7 days), and Top OpenRouter Apps by token usage (top 10). If there are no changes, repeat yesterday's LLM Models section.
- **Top 5 Trending GitHub Repos**: Current trending repositories with actual star counts (use web search to get real data from <https://github.com/trending>)
- **Software Watchlist**: Version updates for monitored software (last 7 days)
- **Today's Productivity**: Lines of code, commits, pull requests, code reviews, and issues closed (daily summary)
- **Work**: Work Done, Tomorrow's Goals
- **Personal**: Work Done, Tomorrow's Goals
- **Personal Reflections**: Freeform thoughts
- **Screenshots taken today**: All screenshots captured today from the screenshot skill library with metadata summaries

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

### 0. Weather and News Integration (from skill outputs)

**ALWAYS read weather and news from their respective skill output files first.**

**Step 1: Read Weather Output**

Read the weather skill's output file for today's date:

```powershell
$today = Get-Date -Format "yyyy-MM-dd"
$weatherFile = "$env:USERPROFILE\.agents\skills\weather\output\$today.md"
if (Test-Path $weatherFile) {
    $weatherContent = Get-Content $weatherFile -Raw
} else {
    Write-Warning "Weather output not found for $today. Run the weather skill first: & `"$env:USERPROFILE\.agents\skills\weather\scripts\Get-DailyWeather.ps1`""
}
```

Copy the weather content directly into the diary entry. The weather skill produces a standardized markdown block with location header, current conditions table, and 3-day forecast table.

If the file doesn't exist, prompt the user: "Weather output not found for today. Would you like me to run the weather skill first?"

**Step 2: Read News Output**

Read the news skill's output file for today's date:

```powershell
$today = Get-Date -Format "yyyy-MM-dd"
$newsFile = "$env:USERPROFILE\.agents\skills\news\output\$today.md"
if (Test-Path $newsFile) {
    $newsContent = Get-Content $newsFile -Raw
} else {
    Write-Warning "News output not found for $today. Run the news skill first: & `"$env:USERPROFILE\.agents\skills\news\scripts\Get-AllNews.ps1`""
}
```

**⚠️ CRITICAL: Copy the news content VERBATIM — do NOT paraphrase, summarize, or rewrite headlines. Do NOT strip URLs. Every headline must remain a clickable markdown link exactly as it appears in the output file.** The news skill enforces source diversification and quality rules internally — no additional validation is needed here.

If the file doesn't exist, prompt the user: "News output not found for today. Would you like me to run the news skill first?"

**Step 3: Read Slack Briefing Output**

Read the Slack briefing output file for today's date:

```powershell
$today = Get-Date -Format "yyyy-MM-dd"
$slackFile = "$env:USERPROFILE\.agents\skills\slack\output\$today-slack-briefing.md"
if (Test-Path $slackFile) {
    $slackContent = Get-Content $slackFile -Raw
} else {
    Write-Warning "Slack briefing not found for $today. Run: & `"$env:USERPROFILE\.agents\skills\slack\scripts\Get-SlackDailyBriefing.ps1`" -OutputFormat Detailed 6>&1"
}
```

If the file doesn't exist, prompt the user: "Slack briefing not found for today. Would you like me to run it?"

**Using the briefing output in the diary:**

The raw briefing provides message previews per channel. When composing the diary's Slack Activity section, **curate and summarize** the raw data:

- Aim for 8-12+ curated activity items
- Combine related messages into coherent summaries
- Capture BOTH problem and solution when available
- Format: `- **[#channel-name](link)**: {Comprehensive summary}`
- Omit bot noise, simple acks, and pleasantries
- If the briefing shows no substantive activity, note "No significant Slack activity"

**Section Header:** Use "### 💬 Slack Activity" in diary entries

**Step 4: Check Watchlist for Updates**

Use the watchlist skill to check for any updates on tracked items:

- Review the WATCHLIST.md file for items marked as "Active" or "Watching"
- For each item, check its key resources for updates from today
- Only include items that have actual updates/changes
- Format as: `- **{Item Name}**: {Brief summary of what changed/updated}`
- If no watchlist items have updates today, omit this section entirely

**Step 4.5: Gather Daily Numbers**

Both sub-sections use cached output files. Check for the cached file first; only run the script if the file is missing.

**Stock Market (Dow Jones + S&P 500):**

**Source:** Alpha Vantage API (`GLOBAL_QUOTE` endpoint) via `Get-DailyFinancialNumbers.ps1`
**Requires:** `ALPHA_VANTAGE_API_KEY` environment variable (free key, 25 requests/day)
**Note:** Alpha Vantage only supports equities/ETFs, so the script uses ETF proxies: DIA (Dow Jones ETF) and SPY (S&P 500 ETF). Prices reflect the ETF share price, not the raw index value.

```powershell
$today = Get-Date -Format "yyyy-MM-dd"
$marketFile = "$env:USERPROFILE\.agents\skills\diary\output\$today-daily-financial-numbers.txt"
if (Test-Path $marketFile) {
    $marketContent = Get-Content $marketFile -Raw
} else {
    # Output file not found — run the script to generate it
    $marketContent = & "$env:USERPROFILE\.agents\skills\diary\scripts\Get-DailyFinancialNumbers.ps1"
}
```

- Fetches Dow Jones (DIA ETF) and S&P 500 (SPY ETF) closing prices, daily change, and percent change
- Outputs to `output/YYYY-MM-DD-daily-financial-numbers.txt` automatically
- On weekends/holidays, returns last trading day data with a note: "Trading day: YYYY-MM-DD"
- Display format: `"Dow Jones: 49,384.01 (+306.78, +0.63%)"`
- **Market Commentary:** After displaying the Dow and S&P numbers, add a brief 1-2 sentence italicized commentary (*Markets closed...*) summarizing the day's market tone — direction, magnitude, and any notable driver (e.g., Fed news, earnings, macro events). Keep it concise and factual.

**Relias Repo Count (daily):**

```powershell
$today = Get-Date -Format "yyyy-MM-dd"
$repoCountFile = "$env:USERPROFILE\.agents\skills\diary\output\$today-relias-repo-counts.txt"
if (Test-Path $repoCountFile) {
    $repoCountContent = Get-Content $repoCountFile -Raw
} else {
    # Output file not found — run the script to generate it
    $repoCountContent = & "$env:USERPROFILE\.agents\skills\diary\scripts\Get-ReliasRepoCounts.ps1"
}
```

- The script outputs to `output/YYYY-MM-DD-relias-repo-counts.txt` automatically
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

**🚨 CRITICAL: Highlights Must Be Free Text**

**NEVER use generic placeholders like:**

- ❌ "Latest release"
- ❌ "Preview release"
- ❌ "Beta release"
- ❌ "Bug fixes and improvements"
- ❌ "New features"

**ALWAYS fetch and read the actual release notes**, then extract 3-7 specific, actionable changes:

- ✅ "Added dark mode support for sidebar"
- ✅ "Fixed memory leak in file watcher (issue #1234)"
- ✅ "New /explain command for code analysis"
- ✅ "Performance: 40% faster file indexing"

**Process:**

1. Visit the changelog/release notes URL
2. Read the actual content
3. Extract specific features, fixes, or improvements
4. Answer: "What can I do now that I couldn't before?"

**Special Cases:**

- **Security**: List CVE numbers (e.g., "CVE-2025-55132: permission model bypass")
- **Deprecations**: State replacement (e.g., "Final release, use X instead")
- **Vague vendor notes**: Acknowledge explicitly (e.g., "Slack provides no details beyond version bump")
- **GitHub Copilot Chat**: Use the VS Code updates page format (e.g., <https://code.visualstudio.com/updates/v1_109>) as the source of truth. **CRITICAL: GitHub Copilot Chat releases are MAJOR VS Code releases with extensive features across multiple categories.** You MUST:
  1. Fetch the VS Code updates page using fetch_webpage tool
  2. Extract highlights from ALL major sections: Chat UX, Agent Session Management, Agent Customization, Agent Extensibility, Agent Optimizations, Agent Security and Trust, Terminal enhancements, Coding and editor, Workbench and productivity, Extensions and API
  3. Prioritize the most impactful user-facing features (5-15 highlights)
  4. Capture both the main version (1.109) and full extension version (e.g., v0.37.2026020406)
  5. **NEVER rely solely on GitHub releases** - they only show extension-specific changes, not the comprehensive VS Code feature updates
  6. Examples of quality highlights: "Anthropic thinking tokens with detailed/compact styles", "Mermaid diagram rendering with pan/zoom", "Plan agent with 4-phase workflow", "parallel subagents execution", "Agent Skills generally available", "Claude Agent support (preview)", "terminal sandboxing", "integrated browser with DevTools"

**Format:** `| [Software](url) | version | date | highlights | [Notes](release-url) |`

After rendering, update JSON with new `last_displayed_date` and `last_displayed_version`. Maintain alphabetical order.

**Step 4.7: Gather Today's Productivity Metrics**

Use the productivity skill to collect coding activity metrics for today:

**Metrics to Collect:**

- **Total Lines of Code**: Net LOC (additions minus deletions) committed today
- **Commits**: Number of commits made today
- **Pull Requests**: Number opened and/or merged today
- **Code Reviews**: Number of code reviews submitted today
- **Issues Closed**: Number of issues resolved today
- **Repositories**: List of repos touched today
- **File Types**: Primary file types modified

**Data Collection Method:**

```powershell
# Query GitHub API and local repositories for today's productivity
& "$env:USERPROFILE\.claude\skills\productivity\scripts\Get-TodayProductivity.ps1"
```

This script:

- Uses GitHub API for public/private repositories, PRs, code reviews, issues
- Queries local git repositories for commit stats
- Filters to author identity (Franz Hemmer and variations)
- Excludes generated code, node_modules, build artifacts, documentation
- Returns net LOC (additions - deletions) for code files only (.js, .ts, .py, .cs, .ps1, etc.)

**Format:**

```markdown
### 💻 Today's Productivity

| Metric | Count |
|--------|-------|
| Lines of Code | 1,247 |
| Commits | 8 |
| Pull Requests | 2 |
| Code Reviews | 3 |
| Issues Closed | 1 |

**Repositories**: hemsoft-core, claude-skills
**File Types**: .ts, .ps1, .md
```

**Section Placement**: Include after Software Watchlist section, before Work section

**Omission Rules:**

- If productivity data shows 0 across all metrics (no activity), omit section entirely
- If data collection script fails, note "Productivity metrics unavailable today" with reason

**Step 5: Include Full Output**

Copy **complete, unfiltered output** from weather and news skill output files, plus Slack Highlights and Watchlist Updates gathered above. Include every headline for future context. Use user-provided highlight if specified.

**Step 6: Gather Screenshots Taken Today**

Use the screenshot skill to find all screenshots captured today from the screenshot skill's image library:

```powershell
# Get today's date folder
$today = Get-Date -Format "yyyy-MM-dd"
$screenshotLibrary = "$env:USERPROFILE\.claude\skills\screenshot\images\library\$today"

if (Test-Path $screenshotLibrary) {
    # Find all .webp files and their metadata
    $screenshots = Get-ChildItem $screenshotLibrary -Filter "*.webp" | ForEach-Object {
        $metaPath = "$($_.FullName).meta.json"
        if (Test-Path $metaPath) {
            $meta = Get-Content $metaPath | ConvertFrom-Json
            [PSCustomObject]@{
                Filename = $_.Name
                RelativePath = "../../screenshot/images/library/$today/$($_.Name)"
                Description = $meta.description
                ImportedTime = $meta.imported_time
                Tags = $meta.tags -join ", "
                Size = $meta.size_webp
            }
        }
    } | Sort-Object ImportedTime
    
    # Format for diary entry
    if ($screenshots) {
        Write-Output "### 📸 Screenshots taken today"
        Write-Output ""
        foreach ($shot in $screenshots) {
            Write-Output "**$($shot.ImportedTime)** - $($shot.Description)"
            Write-Output ""
            Write-Output "![Screenshot]($($shot.RelativePath))"
            if ($shot.Tags) {
                Write-Output ""
                Write-Output "*Tags: $($shot.Tags)*"
            }
            Write-Output ""
        }
    }
} else {
    # No screenshots today - omit section
}
```

**Section Placement:** Add at the very end of the diary entry, after Personal Reflections

**Format:**

- List screenshots chronologically by imported_time
- Show AI-generated description as caption
- Embed image using relative path from diary entry to screenshot library
- Include tags if present
- Omit entire section if no screenshots were captured today

### 1. Meeting Notes Creation

**Workflow:** Detect request → Generate slug filename (`entries/{YYYY-MM-DD}-{slug}.md`) → Confirm → Format content (markdown with header/date/footer) → Create file → Offer to update main diary → Offer to create Todoist tasks

**Slug Examples:** "AI SyncUp" → `ai-syncup`, "Q1 Planning (Goals)" → `q1-planning-goals`

**Todoist Integration:** Detect action items → Ask to add each (due date, project, priority, labels) → Confirm with task ID

### 2. Daily Entry Creation Workflow

1. **Read weather/news output files** (weather skill `output/YYYY-MM-DD.md`, news skill `output/YYYY-MM-DD.md`)
2. **Pull Todoist data** (`Get-TodoistCompleted.ps1`, `Get-TodoistTasks.ps1`, `Get-TodoistUpdated.ps1`)
3. **Apply filters** (`exclusion.json`: @Regular Chores, health/exercise/timesheet tasks)
4. **Categorize** (Work: 2221463722, Personal: 2200472795 or others)
5. **Check LLM Models** (LMSYS leaderboard changes, OpenRouter new releases from last 7 days; if no changes, carry forward yesterday's LLM Models section)
6. **Gather productivity metrics** (lines of code, commits, PRs, code reviews, issues closed)
7. **Gather screenshots** (find all screenshots from today in screenshot skill library)
8. **Generate entry** with weather/news/Todoist/LLM/productivity/screenshots data
9. **Query for gaps** (work/personal done/goals/reflections)
10. **Save** to `entries/{YYYY-MM-DD}.md`

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

## LLM Models Configuration

**File:** `config/llm-leaderboard.json` - Tracks LMSYS Chatbot Arena rankings and new model releases

### Leaderboard Tracking (LMSYS Chatbot Arena)

**Source:** <https://lmarena.ai/leaderboard>

**Categories to Track:**

- Overall (Top 5)
- Coding (Top 5)
- Vision (Top 5)

**Data Collection Method:**

1. Use WebSearch to fetch current leaderboard: "LMSYS Chatbot Arena leaderboard January 2026"
2. Parse results to extract top 5 models for each category with:
   - Rank position
   - Model name
   - Elo score
3. Compare against `last_displayed_rankings` in JSON config
4. Calculate rank changes (↑/↓/−) and score deltas

**Incremental Tracking:**

1. **First Run** (`last_displayed_rankings` is empty): Display all three categories (Overall, Coding, Vision top 5)
2. **Subsequent Runs**: Only display categories where rankings changed (rank position changes OR new models in top 5)
3. **After rendering**: Update JSON with current rankings as `last_displayed_rankings` and set `last_displayed_date`

**Format:**

```markdown
**Overall (Top 5)**

| Rank | Model | Elo Score | Change |
|------|-------|-----------|--------|
| 1 | Gemini-3-Pro | 1490 | − |
| 2 | Grok-4.1-Thinking | 1477 | ↑1 |
| 3 | Gemini-3-Flash | 1472 | ↓1 |
```

**Change Indicators:**

- `↑{n}` = Moved up n positions
- `↓{n}` = Moved down n positions
- `−` = No change
- `NEW` = New entry to top 5

### Model News (OpenRouter Releases)

**Primary Source:** OpenRouter API and announcements

- API: `https://openrouter.ai/api/v1/models`
- Announcements: `https://openrouter.ai/announcements`
- Models page: `https://openrouter.ai/models?fmt=table&order=newest`

**Secondary Sources (if needed):**

- HuggingFace model hub for notable open-source releases
- Official vendor announcements (OpenAI, Anthropic, Google, Meta)

**Time Range:** Last 7 days from today's date

**Data Collection Method:**

1. **PRIMARY - AI Model Trackers**:
   - LLM Stats Updates: `https://llm-stats.com/llm-updates` (comprehensive release tracking)
   - AI Timeline Recent: `https://www.aitimelines.club/recent` (last 24 hours updates)
   - Cross-reference releases with OpenRouter availability
2. **SECONDARY**: Visit OpenRouter models page: `https://openrouter.ai/models?fmt=table&order=newest`
   - Check individual model pages for "Created" date
   - Look for models created within last 7 days
3. **TERTIARY**: Direct provider announcements
   - OpenAI blog, Anthropic news, Google AI blog, xAI announcements
   - HuggingFace model hub (huggingface.co/models)
4. **FALLBACK**: OpenRouter announcements: `https://openrouter.ai/announcements`
5. Extract models released in last 7 days with:
   - Model name (full ID: provider/model)
   - Provider/vendor
   - Release date ("Created" date on model page)
   - Context window size
   - Pricing (input/output per 1M tokens)
   - Model link (e.g., <https://openrouter.ai/moonshotai/kimi-k2.5>)
6. Display ALL models from last 7 days (no limit)

**CRITICAL:** Do NOT rely solely on announcements page - many models are added to OpenRouter without announcements. Always check the models page sorted by newest and verify "Created" dates on individual model pages.

**Format:**

```markdown
| Model | Provider | Released | Context | Pricing | Link |
|-------|----------|----------|---------|---------|------|
| GPT-5.2-High | OpenAI | 2026-01-25 | 128K | $30/1M | [Announcement](url) |
| Kimi K2.5 | Moonshot AI | 2026-01-27 | 1M | $2/1M | [Release](url) |
```

**Tracking:** Store `last_displayed_date` and `last_displayed_models` (array of model names) to avoid duplicates on subsequent runs within same 7-day window.

### OpenRouter App Rankings

**Source:** OpenRouter App Rankings page

- URL: `https://openrouter.ai/rankings/apps`
- Shows top public applications by total token usage

**Data Collection Method:**

1. Use WebSearch: "OpenRouter top apps rankings January 2026" or visit rankings page
2. Extract top 10 apps with:
   - Rank position
   - App name
   - Description/purpose
   - Token count (e.g., "71.2B tokens")
3. Compare against `last_displayed_rankings` in JSON config
4. Calculate rank changes (↑/↓/−) and token deltas

**Incremental Tracking:**

1. **First Run** (`last_displayed_rankings` is empty): Display top 10 apps
2. **Subsequent Runs**: Only display when rankings change (position changes OR new apps in top 10 OR significant token changes >10B)
3. **After rendering**: Update JSON with current rankings as `last_displayed_rankings` and set `last_displayed_date`

**Format:**

```markdown
### Top OpenRouter Apps (by Token Usage)

| Rank | App | Description | Tokens | Change |
|------|-----|-------------|--------|--------|
| 1 | Kilo Code | AI coding agent for VS Code | 71.2B | − |
| 2 | BLACKBOXAI | AI agent for builders | 51.7B | ↑1 |
| 3 | liteLLM | Open-source LLM library | 46B | ↓1 |
```

**Change Indicators:**

- `↑{n}` = Moved up n positions
- `↓{n}` = Moved down n positions
- `−` = No change in position
- `NEW` = New entry to top 10
- Token count changes shown in parentheses if >10B change

**Notable Apps to Watch:**

- Kilo Code: AI coding agent for VS Code
- BLACKBOXAI: AI agent for builders
- liteLLM: Open-source library to simplify LLM calls
- Janitor AI: Character chat and creation
- Cline: Autonomous coding agent for IDE
- Agent Zero: Build autonomous AI agents
- Claude Code: The AI for problem solvers

**Section Omission:** Do not omit the LLM Models section. If no leaderboard changes AND no new models in last 7 days AND no app ranking changes, copy yesterday's LLM Models section verbatim into today's entry.

## File Structure

```
diary/
├── SKILL.md
├── config/
│   ├── yyyy-mm-dd.md (template)
│   ├── exclusion.json
│   ├── software-watchlist.json
│   ├── llm-leaderboard.json (tracks LMSYS rankings and model releases)
│   └── repo-counts.json (tracks daily repo counts for delta calculation)
├── output/
│   ├── YYYY-MM-DD-daily-financial-numbers.txt (cached stock market data from Alpha Vantage)
│   └── YYYY-MM-DD-relias-repo-counts.txt (cached daily repo count output)
├── scripts/
│   ├── Get-DailyFinancialNumbers.ps1 (Dow Jones + S&P 500 via Alpha Vantage API, writes to output/)
│   ├── Get-ReliasRepoCounts.ps1 (unified script for GitHub + Bitbucket with deltas, writes to output/)
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

- Full weather and news integration from skill output files
- Proper section structure and hierarchy
- Appropriate level of detail (high-level, not granular)
- Balance of accomplishments and concerns
- How to document skills created/enhanced
- Work in progress tracking format
- Personal Reflections including both positive and negative feelings

## User Interaction Prompts

**Initial:** "Let's create today's diary entry. I'll gather weather, news, and your Todoist data."

**For gaps:** Ask about work done/goals/reflections, personal done/goals/reflections, overall feelings. Keep conversational, build iteratively.
