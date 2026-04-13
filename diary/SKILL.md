---
name: diary
description: "V1.1 - Commands: create, scaffold, update. Personal diary management with daily entry creation, scaffolding, and updates."
---

# Diary

> **Reference (dev only):** `D:\Backup\.agents\skills\diary` — Legacy diary skill for inspiration during development. Remove this reference once migration is complete.

Personal diary management.

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `create` | `/diary create` or `/diary create 2026-03-01` | Create a new diary entry. Defaults to today. Aborts if entry already exists (use `update` instead). |
| `scaffold` | `/diary scaffold` or `/diary scaffold 2026-04-13` | Scaffold a diary entry by loading cached/live data, assembling all sections, saving immediately, then telling the user what to fill in. |
| `update` | `/diary update` or `/diary update 2026-03-01` | Update an existing diary entry. *(coming soon)* |

## Scripts

| File | Role |
|------|------|
| `create.ps1` | Entry point — validates no entry exists, then calls orchestrator |
| `diary-orchestrator.ps1` | Runs all `###-*.ps1` section scripts in order |
| `010-diary-header.ps1` | Scaffolds entry file from `config/yyyy-mm-dd.md` template |
| `020-slack-activity.ps1` | Curates Slack briefing into 5-8 bullet summary via Copilot CLI, falls back to raw briefing |

## Command: scaffold

When the user activates this command without specifying a date, default to **today**.

Follow all steps below in order. Save the entry as soon as automated data is assembled, then tell the user what to fill in.

### Step 1: Load All Cached Data (Run in Parallel)

Check each file first. If today's file exists, use it. If not, run the fallback script.

Also load yesterday's diary entry (`diary/entries/YYYY-MM-DD.md` for yesterday) to compute day-over-day deltas.

#### External skill caches (base path: `~/.agents/skills/`)

| # | Section | Cached File | Fallback Script |
|---|---------|-------------|------------------|
| 1 | Weather | **ALWAYS re-run** (weather changes throughout the day) | `weather/scripts/Get-DailyWeather.ps1` |
| 2 | News | `news/output/YYYY-MM-DD.md` | `news/scripts/Get-AllNews.ps1` |
| 3 | Slack Activity | `slack/output/YYYY-MM-DD-slack-briefing.md` | `slack/scripts/Get-SlackDailyBriefing.ps1 -OutputFormat Detailed 6>&1` |

#### Diary skill caches (base path: `~/.agents/skills/diary/output/`)

| # | Section | Cached File | Fallback Script (in `diary/scripts/`) |
|---|---------|-------------|----------------------------------------|
| 4 | Stock Market | `YYYY-MM-DD-daily-financial-numbers.txt` | `Get-DailyFinancialNumbers.ps1` |
| 5 | Relias Repo Counts | `YYYY-MM-DD-relias-repo-counts.txt` | `Get-ReliasRepoCounts.ps1` |
| 6 | LLM Model Updates | `YYYY-MM-DD-llm-updates.txt` | `Get-LLMUpdates.ps1` |
| 7 | Software Updates | `YYYY-MM-DD-software-updates.txt` | `Get-SoftwareUpdates.ps1` |
| 8 | Cloudflare Usage | `YYYY-MM-DD-cloudflare-usage.txt` | `~/.agents/skills/cloudflare/scripts/Get-CloudflareUsage.ps1 -Date YYYY-MM-DD` |

### Step 2: Gather Live Data (No Cache — Run in Order)

| # | Section | How |
|---|---------|------|
| 9 | Meetings (workiq) | `workiq ask -q "What meetings did I have today {YYYY-MM-DD}? List each meeting with time, title, and attendees."` — then for each meeting: `workiq ask -q "Show me the transcript or notes from the {meeting title} meeting today. Include key discussion points and action items."` |
| 10 | Watchlist Updates | Read `watchlist/WATCHLIST.md` → for each Active item, check its key resources for updates **from today** → include only items with actual changes |
| 11 | Trending GitHub Repos | Fetch `https://github.com/trending` → Top 5 repos with real star counts |
| 12 | Today's Productivity | `productivity/scripts/Get-TodayProductivity.ps1` → LOC, commits, PRs, reviews, issues |
| 13 | Screenshots | Check `screenshot/images/library/YYYY-MM-DD/` for `.webp` files |

### Step 3: Assemble & Save Entry

Use `diary/config/yyyy-mm-dd.md` as the template. Populate every section in this exact order. For user-provided sections, insert `<!-- TODO: fill in -->` placeholders with Todoist data pre-populated where available.

**Save immediately to `diary/entries/YYYY-MM-DD.md`** once all automated sections are populated.

| # | Section | Source | Omit When |
|---|---------|--------|-----------|
| 1 | 🎯 Today's Highlight | Placeholder: `<!-- TODO: fill in -->` but this section always represents the main news headline of the day chosen from `📰 News Headlines` for the same date. It is not for work updates, meetings, Todoist tasks, or productivity notes. | Never |
| 2 | 💬 Slack Activity | Cache #3 — curate 8–12 items | Never |
| 3 | 🌤 Weather | Cache #1 — copy verbatim | Never |
| 4 | 📰 News Headlines | Cache #2 — copy verbatim, all links intact, no paraphrasing | Never |
| 5 | 📊 Daily Numbers | Cache #4 + #5 + #8. **After injecting numbers, write 1–2 sentences explaining why markets moved using today's news headlines as context.** On weekends, note markets were closed. Include Cloudflare usage from cache #8. **Always compute and show deltas vs yesterday for GitHub Copilot usage and Cloudflare usage (page views, unique visitors, emails forwarded where applicable). If yesterday's value is unavailable, explicitly state delta unavailable.** | Weekends (market only) |
| 6 | 🤖 LLM Models | Cache #6 — carry forward yesterday's section if no changes | Never |
| 7 | 🔥 Trending GitHub Repos | Live #11 | Never |
| 8 | 🛠 Software Watchlist | Cache #7 | Never |
| 9 | 📋 Watchlist Updates | Live #10 — only if ≥1 Active item has updates today | No updates found |
| 10 | 💻 Today's Productivity | Live #12 | All metrics are zero |
| 11 | 💼 Meetings | Live #9 (workiq) — table of meetings with transcripts/notes if available | Saturday |
| 12 | 💭 Personal Reflections | Placeholder: `<!-- TODO: fill in -->` | Never |
| 13 | 📸 Screenshots | Live #13 | No screenshots today |

### Step 4: Tell User What to Fill In

After saving, show the user a checklist of sections that need their input:

1. **🎯 Today's Highlight** — the news headline of the day from the News section, plus URL + optional context
2. **💭 Personal Reflections** — thoughts, feelings, or observations about today

### Step 5: Automated Sections Checklist

Print this checklist in the output so the user can see what was populated:

- [ ] Weather populated (cache or script)
- [ ] Today's Highlight left as a placeholder for the user, but clearly framed as the news headline of the day
- [ ] News populated — all headlines verbatim with links intact
- [ ] Slack Activity has 8–12 curated items
- [ ] Daily Numbers: Dow, S&P, GitHub repo count, Bitbucket repo count, Cloudflare usage, plus GitHub Copilot + Cloudflare deltas vs yesterday
- [ ] LLM Models present (new data or carried forward from yesterday)
- [ ] Top 5 Trending GitHub Repos with real star counts
- [ ] Software Watchlist populated from script output
- [ ] Watchlist Updates: Active items checked — section present OR explicitly noted "no updates today"
- [ ] Today's Productivity present (or confirmed zero activity)
- [ ] Meetings populated from workiq (weekdays) or correctly omitted (weekends)
- [ ] Screenshots present or confirmed none today

## Scaffolding Defaults

- `🎯 Today's Highlight` is not a work summary, task summary, or personal accomplishment.
- It must always be the main news headline of the day, chosen from the same day's `📰 News Headlines` section.
- If the entry is saved with a placeholder, the placeholder should still tell the user to provide a news headline plus source URL, not a work-related update.
- In `📊 Daily Numbers`, always include day-over-day deltas versus yesterday for:
  - GitHub Copilot usage
  - Cloudflare usage metrics (page views, unique visitors, and emails forwarded where applicable)
- If a prior-day value is missing, explicitly state that the delta is unavailable.
