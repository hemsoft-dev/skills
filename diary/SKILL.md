---
name: diary
description: "V1.6 - Commands: create, scaffold, update. Personal diary management with credential-resilient automated collection and HTML entries."
---

# Diary

> **Reference (dev only):** `D:\Backup\.agents\skills\diary` — Legacy diary skill for inspiration during development. Remove this reference once migration is complete.

Personal diary management.

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `create` | `/diary create` or `/diary create 2026-03-01` | Create a new diary entry. Defaults to today. Aborts if entry already exists (use `update` instead). |
| `scaffold` | `/diary scaffold` or `/diary scaffold 2026-04-13` | Scaffold a diary entry as a standalone HTML file. Loads cached/live data, assembles all sections, saves immediately, then tells the user what to fill in. |
| `update` | `/diary update` or `/diary update 2026-03-01` | Update an existing diary entry. *(coming soon)* |

## Scripts

| File | Role |
|------|------|
| `create.ps1` | Entry point — validates no entry exists, then calls orchestrator |
| `diary-orchestrator.ps1` | Runs all `###-*.ps1` section scripts in order |
| `010-diary-header.ps1` | Scaffolds entry file from `config/yyyy-mm-dd.html` template |
| `020-slack-activity.ps1` | Generates date-scoped Slack briefing, curates it into an 8-12 item summary via Copilot CLI, and falls back to raw briefing |
| `HtmlDiaryHelpers.ps1` | Shared HTML path resolution, environment credential fallback, section replacement, and markdown-to-HTML helpers |

> **Scripted vs. scaffolded workflow:** The numbered PowerShell scripts power the reusable script-backed sections used by `create.ps1` and `diary-orchestrator.ps1`. The `scaffold` command below is still the authoritative end-to-end workflow for live-only sections such as Watchlist Updates, Today's Productivity, Meetings, Screenshots, and picking Today's Highlight from the news.

## Command: scaffold

When the user activates this command without specifying a date, default to **today**.

Follow all steps below in order. Save the entry as soon as automated data is assembled, then tell the user what to fill in.

> **HTML only:** Older prompts and legacy notes may still refer to `diary/entries/YYYY-MM-DD.md`. That markdown output path is obsolete. The scaffold flow always targets `diary/entries/YYYY/MM/YYYY-MM-DD.html`.

### Step 1: Load All Cached Data (Run in Parallel)

Check each file first. If today's file exists, use it. If not, run the fallback script.

Also load yesterday's diary entry (`diary/entries/YYYY/MM/YYYY-MM-DD.html` for yesterday) to compute day-over-day deltas.

#### External skill caches (base path: `~/.agents/skills/`)

| # | Section | Cached File | Fallback Script |
|---|---------|-------------|------------------|
| 1 | Weather | **ALWAYS re-run** (weather changes throughout the day) | `weather/scripts/Get-DailyWeather.ps1` |
| 2 | News | `news/output/YYYY-MM-DD.md` | `news/scripts/Get-AllNews.ps1` |
| 3 | Slack Activity | `slack/output/YYYY-MM-DD-slack-briefing.md` | `slack/scripts/Get-SlackDailyBriefing.ps1 -OutputFormat Detailed 6>&1` |

#### Diary skill caches (base path: `~/.agents/skills/diary/output/`)

| # | Section | Cached File | Fallback |
|---|---------|-------------|----------|
| 4 | Stock Market | `YYYY-MM-DD-daily-financial-numbers.txt` | Yahoo Finance API: `Invoke-RestMethod "https://query1.finance.yahoo.com/v8/finance/chart/%5EDJI?interval=1d&range=1d"` (and `%5EGSPC` for S&P 500) — extract `meta.regularMarketPrice` and `meta.chartPreviousClose` to compute delta |
| 5 | Relias Repo Counts | `YYYY-MM-DD-relias-repo-counts.txt` | GitHub: `gh api orgs/Relias-Engineering/repos --paginate --jq 'length'` (sum all pages). Bitbucket: `diary/scripts/Get-BitbucketRepoCount.ps1` |
| 6 | GitHub Copilot Usage | *(no cache — always live)* | **Always show BOTH org-wide AND personal stats.** Org-wide: `gh api "/orgs/Relias-Engineering/settings/billing/usage"` → filter for `product=="copilot"` and `sku=="Copilot Premium Request"` where `date` matches current billing month. Also get Cloud Agent (`sku=="Coding Agent Premium Request"`). Org quota = seats × 1000 (get seat count from `/orgs/Relias-Engineering/copilot/billing` → `seat_breakdown.total`). Personal: `gh api /copilot_internal/user --jq '.quota_snapshots.premium_interactions'` → returns `{entitlement, remaining, ...}`. Calculate: `used = entitlement - remaining`. Display as: `fhemmerrelias: {used} / {entitlement} used ({pct}%)`. **⚠️ Do NOT use** `/orgs/.../copilot/usage` or `/copilot/metrics` — these return 404. |
| 7 | LLM Model Updates | `YYYY-MM-DD-llm-updates.txt` | Carry forward yesterday's LLM section. No automated script exists — check LMSYS and OpenRouter manually if needed. |
| 8 | Software Updates | `YYYY-MM-DD-software-updates.txt` | For each repo in `diary/config/software-watchlist.json`: `gh api "repos/{owner}/{repo}/releases/latest" --jq '"\(.tag_name) \| \(.published_at) \| \(.name)"'`. For GitHub Web (RSS type): `Invoke-RestMethod "https://github.blog/changelog/feed/"` and filter by today's date. |
| 9 | Cloudflare Usage | `YYYY-MM-DD-cloudflare-usage.txt` | `~/.agents/skills/cloudflare/scripts/Get-CloudflareUsage.ps1 -Date YYYY-MM-DD` |

### Step 2: Gather Live Data (No Cache — Run in Order)

| # | Section | How |
|---|---------|------|
| 10 | Meetings (workiq) | `workiq ask -q "What meetings did I have today {YYYY-MM-DD}? List each meeting with time, title, and attendees."` — then for each meeting: `workiq ask -q "Show me the transcript or notes from the {meeting title} meeting today. Include key discussion points and action items."` |
| 11 | Watchlist Updates | Read `watchlist/WATCHLIST.md` → for each Active item, check its key resources for updates **from today** → include only items with actual changes |
| 12 | Trending GitHub Repos | Fetch `https://github.com/trending` with `Invoke-WebRequest -UseBasicParsing`, then regex-extract repo paths from `/owner/repo/stargazers` links. Get star counts + descriptions via `gh api "repos/{owner}/{repo}" --jq '.stargazers_count, .description'`. Take top 5. |
| 13 | Today's Productivity | `productivity/scripts/Get-TodayProductivity.ps1` → LOC, commits, PRs, reviews, issues |
| 14 | Screenshots | Check `screenshot/images/library/YYYY-MM-DD/` for `.webp` files |

### Step 3: Assemble & Save Entry

**Output format: HTML.** Consult the `html` skill (`~/.agents/skills/html/SKILL.md`) for the visual system, theme definitions (Paper/Obsidian/Twilight/Carbon), approved layout variants, component vocabulary, default skeleton, and theme toggle. Use the `dashboard` variant as the base layout. All theme CSS, toggle JS, and component classes defined in the `html` skill MUST be included.

Use `diary/config/yyyy-mm-dd.html` as the **section reference** for content structure. Translate each section into structured HTML using the `html` skill's component vocabulary (`.page-shell`, `.window`, `.section`, `.section-title`, `.card`, `.grid`, `.stat-block`, `.tag`, `.num-list`, etc.).

**News headline lists**: Render as `<ol class="num-list">` with each `<li>` containing the headline link, em dash, and source badge inline. Do NOT use `display: flex` on `<li>` — use `position: relative` with `padding-left` for the counter number and let content flow inline naturally. Add `white-space: nowrap` to `.tag` elements to prevent badge text wrapping.

**Save immediately to `diary/entries/YYYY/MM/YYYY-MM-DD.html`** once all automated sections are populated.

| # | Section | Source | Omit When |
|---|---------|--------|-----------|
| 1 | 🎯 Today's Highlight | Placeholder: `<!-- TODO: fill in -->` but this section always represents the main news headline of the day chosen from `📰 News Headlines` for the same date. It is not for work updates, meetings, Todoist tasks, or productivity notes. | Never |
| 2 | 💬 Slack Activity | Cache #3 — curate 8–12 items | Never |
| 3 | 🌤 Weather | Cache #1 — copy verbatim | Never |
| 4 | 📰 News Headlines | Cache #2 — copy verbatim, all links intact, no paraphrasing | Never |
| 5 | 📊 Daily Numbers | Cache #4 + #5 + #6 + #9. **After injecting numbers, write 1–2 sentences explaining why markets moved using today's news headlines as context.** On weekends, note markets were closed. Include Cloudflare usage from cache #9 and GitHub Copilot usage from cache #6 — **always show BOTH org-wide totals AND personal (fhemmerrelias) stats**. **Always compute and show deltas vs yesterday for GitHub Copilot usage and Cloudflare usage (page views, unique visitors, emails forwarded where applicable). If yesterday's value is unavailable, explicitly state delta unavailable.** | Weekends (market only) |
| 6 | 🤖 LLM Models | Cache #7 — carry forward yesterday's section if no changes | Never |
| 7 | 🔥 Trending GitHub Repos | Live #12 | Never |
| 8 | 🛠 Software Watchlist | Cache #8 | Never |
| 9 | 📋 Watchlist Updates | Live #11 — only if ≥1 Active item has updates today | No updates found |
| 10 | 💻 Today's Productivity | Live #13 | All metrics are zero |
| 11 | 💼 Meetings | Live #10 (workiq) — table of meetings with transcripts/notes if available | Saturday |
| 12 | 💭 Personal Reflections | Placeholder: `<!-- TODO: fill in -->` | Never |
| 13 | 📸 Screenshots | Live #14 | No screenshots today |

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
- [ ] Daily Numbers: Dow, S&P, GitHub repo count, Bitbucket repo count, Cloudflare usage, plus GitHub Copilot (org-wide AND personal/fhemmerrelias) + Cloudflare deltas vs yesterday
- [ ] LLM Models present (new data or carried forward from yesterday)
- [ ] Top 5 Trending GitHub Repos with real star counts
- [ ] Software Watchlist populated from script output
- [ ] Watchlist Updates: Active items checked — section present OR explicitly noted "no updates today"
- [ ] Today's Productivity present (or confirmed zero activity)
- [ ] Meetings populated from workiq (weekdays) or correctly omitted (weekends)
- [ ] Screenshots present or confirmed none today

### Step 6: Validate Automated Sections

After saving the entry, validate the following rules. If any validation fails, **fix the section before
finishing** — do not leave known-bad data in the entry.

| # | Validation Rule | Action on Failure |
|---|----------------|-------------------|
| 1 | **Productivity script must complete.** If the script hangs (>120s) or errors, kill it and re-run with explicit `-Date YYYY-MM-DD`. If it hangs a second time, run it in a fresh shell. | Re-run up to 2 retries before accepting zero. |
| 2 | **Weekday productivity must not be all zeros.** On weekdays (Mon–Fri), if LOC, Commits, PRs, Reviews, and Issues are ALL zero, treat this as a data collection failure — not a valid result. | Re-run the script with `-Date` parameter. Check that `D:\github` search roots are accessible. If still zero after retries, add a note: *"⚠️ Productivity data collection failed — metrics may be incomplete."* |
| 3 | **Weekend zero is acceptable.** On Sat/Sun, all-zero productivity is valid — no retry needed. |  |
| 4 | **Trending repos must have star counts.** All 5 repos must show `⭐ {number}` — not blank or zero. | Re-fetch star counts via `gh repo view {owner/repo} --json stargazerCount`. |
| 5 | **News section must have headlines.** Each news category (US, World, AI, Danish) must have at least 1 headline. | Re-run news script or flag as data collection failure. |
| 6 | **Cloudflare deltas must be computed.** If yesterday's entry exists, deltas must show actual numbers — not "unavailable." | Re-read yesterday's entry and compute manually. |

## Scaffolding Defaults

- `🎯 Today's Highlight` is not a work summary, task summary, or personal accomplishment.
- It must always be the main news headline of the day, chosen from the same day's `📰 News Headlines` section.
- If the entry is saved with a placeholder, the placeholder should still tell the user to provide a news headline plus source URL, not a work-related update.
- In `📊 Daily Numbers`, always include day-over-day deltas versus yesterday for:
  - GitHub Copilot usage (org-wide)
  - Cloudflare usage metrics (page views, unique visitors, and emails forwarded where applicable)
- **GitHub Copilot must always show BOTH**:
  - **Org-wide**: Total premium requests / quota from billing API
  - **Personal (fhemmerrelias)**: `gh api /copilot_internal/user --jq '.quota_snapshots.premium_interactions'` → show as `{used} / {entitlement} used ({pct}%)`
- If a prior-day value is missing, explicitly state that the delta is unavailable.
