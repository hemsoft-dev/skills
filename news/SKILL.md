---
name: news
description: V1.0 - Fetches news headlines from US, World, AI, and Danish sources via direct web scraping. Use when gathering daily news for diary entries.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the news directory (path contains 'news'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if news was used (check if any files in news directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in news directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# News

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Fetches news headlines from multiple sources without requiring LLM sub-agents. Outputs to standardized `output/YYYY-MM-DD.md` format for diary integration.

## Daily Output Files

**Pattern**: All news reports are automatically saved to `output/YYYY-MM-DD.md` for diary integration.

## News Categories

The skill provides 4 independent scripts for fetching different news categories:

### Master Script: Get All News

```powershell
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-AllNews.ps1"
```

**This is the recommended way to fetch news** - it orchestrates all 4 categories and overwrites any existing output for the day.

### Individual Category Scripts

### 1. US News

```powershell
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-USNews.ps1"
```

**Sources**: Associated Press, Reuters, NPR, PBS NewsHour, Politico, USA Today

### 2. World News

```powershell
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-WorldNews.ps1"
```

**Sources**: Associated Press, Reuters, BBC, Al Jazeera, France 24, The Guardian

### 3. AI News

```powershell
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-AINews.ps1"
```

**Sources**: Simon Willison's Weblog, The Verge, TechCrunch, Ars Technica, VentureBeat, Wired, MIT Tech Review

### 4. Danish News

```powershell
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-DanishNews.ps1"
```

**Sources**: Reuters, The Local Denmark, CPH Post, DR News, Politiken

## Output Format

Each script appends to `output/YYYY-MM-DD.md` in the following format:

```markdown
### 🇺🇸 US News
| # | Headline | Source |
|---|----------|--------|
| 1 | [Headline text](url) | Source |
...
```

## Usage

**Fetch all news categories for today (recommended):**

```powershell
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-AllNews.ps1"
```

This will:

1. Remove any existing output file for today
2. Fetch US News
3. Fetch World News
4. Fetch AI News
5. Fetch Danish News
6. Display preview of the output

**Fetch individual categories:**

```powershell
# Clear output first
$date = Get-Date -Format "yyyy-MM-dd"

# Clear any existing output file for today
$outputFile = "$env:USERPROFILE\.agents\skills\news\output\$date.md"
if (Test-Path $outputFile) { Remove-Item $outputFile }

# Fetch each category
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-USNews.ps1"
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-WorldNews.ps1"
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-AINews.ps1"
& "$env:USERPROFILE\.agents\skills\news\scripts\Get-DanishNews.ps1"

# Output file now contains all 4 news sections
Get-Content $outputFile
```

## Integration with Diary Skill

The diary skill consumes the `output/YYYY-MM-DD.md` file to include news headlines in daily diary entries.

## Source Diversification

Scripts automatically enforce:

- Maximum 2 items per source (30% cap)
- Minimum 3-4 different sources per category
- Last 24 hours only

## Parameters

All scripts accept:

- `-Count`: Number of headlines to fetch (default: 7)
- `-HoursBack`: How far back to search (default: 24)

## When to Use This Skill

Use when:

- Gathering daily news headlines for diary entries
- Need programmatic news collection without LLM overhead
- Want deterministic, reproducible news fetches
- Integrating with automated diary generation workflows
