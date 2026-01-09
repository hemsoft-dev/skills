---
name: today
description: V1.1 - Displays highlighted news, current date/time, weather conditions, and 3-day forecast with news headlines.
---

# Today

Fetch and display the current date, time, weather, and news.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `~/.claude/skills/today/History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - Today Check
Location: {city} | Temp: {temp}°F | News items: {count}
```

## Execution Order

1. **Weather**: Run PowerShell script
2. **News**: Launch 3 sub-agents in parallel

---

## Part 1: Weather

Run the PowerShell script:

```powershell
& "$env:USERPROFILE\.claude\skills\today\Get-Today.ps1"
```

For a different location:

```powershell
& "$env:USERPROFILE\.claude\skills\today\Get-Today.ps1" -Location "Seattle,WA"
```

**Default location**: 28117 (Mooresville, NC)

**IMPORTANT**: Always run the script. Do not estimate date/time/weather manually.

---

## Part 2: News (Sub-Agent Approach)

Launch **3 parallel sub-agents** for US News, World News, and AI News.

### Sub-Agent Prompt Template

```
TASK: Gather {CATEGORY} news headlines from the last 24 hours.

TODAY'S DATE: {CURRENT_DATE} ({WEEKDAY})

SOURCES TO CHECK (in priority order):
{SOURCE_LIST}

FOCUS AREAS: {FOCUS_AREAS}

REQUIREMENTS:
1. Only include news from the last 24 hours
2. Return exactly 5-7 of the most significant stories
3. Verify each story's date before including - REJECT anything older than 24 hours
4. No duplicates - if same story appears on multiple sources, pick the best one
5. Use fetch_webpage tool to check each source's homepage or news section

OUTPUT FORMAT (return EXACTLY this format, no other text):
| # | Headline | Source | Link |
|---|----------|--------|------|
| 1 | {headline} | {source_name} | {url} |
| 2 | {headline} | {source_name} | {url} |
...

If a source is unavailable or has no fresh news, note at the end:
"Unavailable: {source_name}"
```

### Category 1: US News

**Sources:**

1. Associated Press (apnews.com)
2. Reuters US (reuters.com/world/us)
3. NPR News (npr.org/sections/news)
4. PBS NewsHour (pbs.org/newshour)
5. The Hill (thehill.com)
6. Politico (politico.com)
7. USA Today (usatoday.com)

**Focus areas:** Politics, economy, major events, legislation, Supreme Court, federal policy

### Category 2: World News

**Sources:**

1. Associated Press International (apnews.com/world-news)
2. Reuters World (reuters.com/world)
3. BBC World (bbc.com/news/world)
4. Al Jazeera (aljazeera.com)
5. France 24 (france24.com/en)
6. DW News (dw.com/en)
7. The Guardian World (theguardian.com/world)

**Focus areas:** International conflicts, diplomacy, global economy, humanitarian issues, elections abroad

### Category 3: AI News

**Sources:**

1. The Verge AI (theverge.com/ai-artificial-intelligence)
2. Ars Technica AI (arstechnica.com/ai)
3. TechCrunch AI (techcrunch.com/category/artificial-intelligence)
4. Wired AI (wired.com/tag/artificial-intelligence)
5. MIT Technology Review (technologyreview.com)
6. VentureBeat AI (venturebeat.com/ai)
7. Crescendo AI News (crescendo.ai/news/latest-ai-news-and-updates)
8. Hacker News top (news.ycombinator.com) - AI-related only

**Focus areas:** Model releases, research breakthroughs, AI regulation, major funding, product launches, safety developments

---

## Final Output Format

Present output in this EXACT format:

```markdown
## 🎯 Today's Highlight

**[{Headline}]({url})**

{Optional 1-2 sentence context or why this matters}

---

### 📍 {City}, {Country}

| 📅 Date | 📆 Day | 🕐 Time |
|---------|--------|---------|
| {YYYY-MM-DD} | {Weekday} | {H:MM AM/PM} {Timezone} |

### Current Weather

| 🌡️ Temp | 🤔 Feels Like | {Icon} Condition | 💨 Wind | 💧 Humidity |
|---------|---------------|------------------|---------|-------------|
| {temp}°F | {feels}°F | {condition} | {wind} mph | {humidity}% |

### 3-Day Forecast

| Day | Icon | Condition | Low | High | Wind |
|-----|------|-----------|-----|------|------|
| {Weekday} (Today) | {icon} | {condition} | {low}°F | {high}°F | {wind} mph |
| {Weekday} | {icon} | {condition} | {low}°F | {high}°F | {wind} mph |
| {Weekday} | {icon} | {condition} | {low}°F | {high}°F | {wind} mph |

---

## 📰 News Headlines ({Month Day, Year})

### 🇺🇸 US News
| # | Headline | Source |
|---|----------|--------|
| 1 | [Headline text](url) | Source |
| 2 | [Headline text](url) | Source |
| 3 | [Headline text](url) | Source |
| 4 | [Headline text](url) | Source |
| 5 | [Headline text](url) | Source |
| 6 | [Headline text](url) | Source |
| 7 | [Headline text](url) | Source |

### 🌍 World News
| # | Headline | Source |
|---|----------|--------|
| 1 | [Headline text](url) | Source |
| 2 | [Headline text](url) | Source |
| 3 | [Headline text](url) | Source |
| 4 | [Headline text](url) | Source |
| 5 | [Headline text](url) | Source |
| 6 | [Headline text](url) | Source |
| 7 | [Headline text](url) | Source |

### 🤖 AI News
| # | Headline | Source |
|---|----------|--------|
| 1 | [Headline text](url) | Source |
| 2 | [Headline text](url) | Source |
| 3 | [Headline text](url) | Source |
| 4 | [Headline text](url) | Source |
| 5 | [Headline text](url) | Source |
| 6 | [Headline text](url) | Source |
| 7 | [Headline text](url) | Source |

---
*News gathered at {time}. Sources checked: {count}. Items within last 24 hours only.*
```

## Weather Icons

| Condition | Icon |
|-----------|------|
| Clear/Sunny | ☀️ |
| Few Clouds | 🌤️ |
| Scattered Clouds | ⛅ |
| Cloudy/Overcast | ☁️ |
| Rain/Drizzle | 🌧️ |
| Thunderstorm | ⛈️ |
| Snow | 🌨️ |
| Fog/Mist | 🌫️ |

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--hours` | 24 | How far back to search for news |
| `--count` | 5-7 | Headlines per category |
| `--category` | all | Specific category: `us`, `world`, `ai`, or `all` |
| `-Location` | 28117 | ZIP code or city for weather |
