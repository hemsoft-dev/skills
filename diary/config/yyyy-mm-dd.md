# {Weekday}, {YYYY-MM-DD}

## 🎯 Today's Highlight

<!-- Must be the main news headline of the day from the News Headlines section, not a work update -->

**[{title}]({url})**

{1-2 sentence context from user}

---

## 💬 Slack Activity

| # | Channel | Summary |
|---|---------|---------|
| {8-12+ substantive items: PSAs, decisions, announcements, problems/solutions} |||

---

## 🌤️ Weather

<!-- Script: TBD | Source: OpenWeather API -->

### 📍 Mooresville, NC

| 📅 Date | 📆 Day | 🕐 Time |
|---------|--------|---------|
| {YYYY-MM-DD} | {Weekday} | {H:MM AM/PM} Eastern |

**Current Conditions**

| 🌡️ Temp | 🤔 Feels Like | ☁️ Condition | 💨 Wind | 💧 Humidity |
|---------|---------------|-------------|---------|-------------|
| {temp}°F | {feels}°F | {condition} | {wind} mph | {humidity}% |

**3-Day Forecast**

| Day | Condition | Low | High | Wind |
|-----|-----------|-----|------|------|
| {Today} | {condition} | {low}°F | {high}°F | {wind} mph |
| {Tomorrow} | {condition} | {low}°F | {high}°F | {wind} mph |
| {Day After} | {condition} | {low}°F | {high}°F | {wind} mph |

---

## 📰 News Headlines ({Month Day, Year})

<!-- Script: TBD | Source: Web scraping -->

### 🇺🇸 US News

| # | Headline | Source |
|---|----------|--------|
| {5-8 headlines} |||

### 🌍 World News

| # | Headline | Source |
|---|----------|--------|
| {5-8 headlines} |||

### 🤖 AI News

| # | Headline | Source |
|---|----------|--------|
| {5-8 headlines} |||

### 🇩🇰 Danish News

| # | Headline | Source |
|---|----------|--------|
| {3-5 headlines} |||

---

## 📊 Daily Numbers

<!-- Script: 050-daily-numbers.ps1 | Sources: Yahoo Finance, GitHub API, Bitbucket API, CodexBar Copilot token billing, Cloudflare API -->

- **Dow Jones**: {price} ({delta})
- **S&P 500**: {price} ({delta})

*{1-2 sentence market commentary — written by agent using today's news headlines to explain why markets moved}*

- **Relias Repo Count**: GitHub: {count} ({+/- n}), Bitbucket: {count} ({+/- n})
- **GitHub Copilot Org-Wide AI Credits**: {credits} credits, ${gross} gross, ${net} net ({users} users; cache generated {timestamp}; days {days})
  - **Top Users**: {user}: {credits} credits (${gross} gross)
  - **Delta vs Yesterday**: {+/- credits} AI credits, {+/- gross cost} gross cost
  - **Personal (fhemmerrelias)**: {credits} AI credits, ${gross} gross, ${net} net ({days} days with usage)
  - **Personal Delta vs Yesterday**: {+/- credits} AI credits, {+/- gross cost} gross cost
  - **{account}**: {used} / {quota} used ({pct}%)
- **Cloudflare Usage**:
  - **nowleadershipgroup.com**: {page views} page views, {unique visitors} unique visitors, {emails forwarded} emails forwarded
    - **Delta vs Yesterday**: {+/- page views}, {+/- unique visitors}, {+/- emails forwarded}
  - **setitfreeloop.org**: {page views} page views, {unique visitors} unique visitors
    - **Delta vs Yesterday**: {+/- page views}, {+/- unique visitors}

---

## 🤖 LLM Models

<!-- Script: TBD | Sources: LMSYS, OpenRouter API -->

### LMSYS Chatbot Arena Leaderboard

*Only shown when rankings change from previous entry.*

**Overall (Top 5)**

| Rank | Model | Elo Score | Change |
|------|-------|-----------|--------|
| 1 | | | |

**Coding (Top 5)**

| Rank | Model | Elo Score | Change |
|------|-------|-----------|--------|
| 1 | | | |

**Vision (Top 5)**

| Rank | Model | Elo Score | Change |
|------|-------|-----------|--------|
| 1 | | | |

*Source: [LMSYS Chatbot Arena](https://lmarena.ai/leaderboard)*

### New Model Releases (Last 7 Days)

| Model | Provider | Released | Context | Pricing | Link |
|-------|----------|----------|---------|---------|------|
| {from OpenRouter API} ||||||

### Top OpenRouter Apps (by Token Usage)

*Only shown when rankings change from previous entry.*

| Rank | App | Description | Tokens | Change |
|------|-----|-------------|--------|--------|
| 1 | | | | |

*Source: [OpenRouter Rankings](https://openrouter.ai/rankings/apps)*

---

## 🔥 Top 5 Trending GitHub Repos

<!-- Script: TBD | Source: GitHub Trending -->

| # | Repository | Description | Stars |
|---|------------|-------------|-------|
| 1 | [{owner}/{repo}](https://github.com/{owner}/{repo}) | {description} | ⭐ {count} |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |

---

## 💻 Software Watchlist

<!-- Script: TBD | Source: config/software-watchlist.json + GitHub Releases API -->

| Software | Version | Released | Highlights | Links |
|----------|---------|----------|------------|-------|
| {from watchlist — zero updates = checking failure} |||||

---

## 💼 Work

### 📅 Meetings

<!-- Source: workiq — today's calendar meetings with attendees and transcripts (if available) -->

| Time | Meeting | Attendees |
|------|---------|-----------|
| {from workiq} |||

---

## 🏠 Personal

### 💭 Reflections

{user to provide}

---

*Entry created with diary skill V1.0*
