# TODO: Diary Skill Streamlining

## Goal

Clarify responsibilities between contributing skills to eliminate duplication and streamline daily diary creation.

## 🎯 New Architecture Pattern

**Standard Output Format**: All skills that contribute data to the diary MUST save their output to:

```
~/.agents/skills/{skill-name}/output/YYYY-MM-DD.md
```

**Benefits**:

- Single source of truth for each day's data
- Easy to review what was collected before compiling diary
- Reusable output if diary needs regeneration
- Clear separation of concerns

**Skills Following This Pattern**:

- ✅ **weather** - `output/2026-02-10.md` (implemented)
- ✅ **today** - Already has `output/` folder
- ✅ **news** - `output/2026-02-11.md` (4 RSS-based scripts, no LLM required)
- ✅ **slack** - `output/YYYY-MM-DD-slack-briefing.md` (18 channels, DMs, mentions, announcements)
- 🔲 **Other contributors** - To be determined

---

## Tasks

### Status: 🔲 Not Started | ⏳ In Progress | ✅ Done

| # | Task | Owner | Status |
|---|------|-------|--------|
| 1 | ✅ Establish output/YYYY-MM-DD.md pattern | weather | ✅ |
| 2 | ✅ Verify today skill follows output pattern | today | ✅ |
| 3 | ✅ Verify weather skill only handles weather data | weather | ✅ |
| 4 | Remove any news gathering logic from diary skill | diary | ✅ |
| 5 | Diary consumes weather + news output files directly | diary | ✅ |
| 6 | Document Slack Activity data collection (18 channels, date-filtered) | diary | ✅ |
| 7 | Document Watchlist Updates integration | diary | ✅ |
| 8 | Document Daily Numbers (stocks + repo counts) | diary | ✅ |
| 9 | Document LLM Models (3 subsections: leaderboard, releases, apps) | diary | ✅ |
| 10 | Document GitHub Trending Repos integration | diary | ✅ |
| 11 | Document Software Watchlist (22+ items, version tracking) | diary | ✅ |
| 12 | Document Today's Productivity metrics | diary | ✅ |
| 13 | Document Todoist Integration (completed/upcoming/filtered) | diary | ✅ |
| 14 | Document Screenshots integration from screenshot skill | diary | ✅ |
| 15 | Verify Today's Highlight is user-provided (not auto-selected) | diary | ✅ |
| 16 | Test complete workflow: weather → today → diary with all sections | all | 🔲 |
| 17 | Update SKILL.md files with finalized responsibilities | all | 🔲 |

---

## Responsibility Matrix

### weather skill OWNS

- Weather data only (location, current conditions, 3-day forecast)
- Delegates to today skill's Get-Today.ps1 script

### news skill OWNS

- News headlines (US, World, AI, Danish) - 5-7 each, last 24h
- Source diversification enforcement (max 2 per source, 3-4 sources min)
- RSS feed parsing without LLM overhead
- 4 independent scripts: Get-USNews.ps1, Get-WorldNews.ps1, Get-AINews.ps1, Get-DanishNews.ps1

### today skill OWNS

- Today's Highlight (user-selected featured news with context)
- Aggregates weather + news into single daily report
- Final formatting and presentation

### diary skill OWNS

- Today's Highlight (user-provided)
- Slack Activity (18 channels)
- Watchlist Updates
- Daily Numbers (stocks + repos)
- news skill runs 4 scripts → outputs to news/output/YYYY-MM-DD.md
- weather skill runs → outputs to weather/output/YYYY-MM-DD.md
- diary skill reads both output files directly (no intermediary)
- No duplication of effort, clear separation of concerns
- Today's Productivity
- Todoist Integration
- Work/Personal sections
- Personal Reflections
- Screenshots

### Integration Point

- diary skill reads `weather/output/YYYY-MM-DD.md` for weather data
- diary skill reads `news/output/YYYY-MM-DD.md` for news data
- If output files don't exist, diary prompts user to run the respective skill first
- No duplication of effort — weather and news skills own data collection, diary only consumes

---

## Notes

- All data collection must respect date filtering (last 24h for news, last 7d for software/models)
- Source diversification: max 2 items per source, min 3-4 sources per category
- Slack requires date-filtered queries (after:(target-1day) before:(target+1day))
