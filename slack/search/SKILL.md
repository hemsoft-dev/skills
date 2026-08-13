---
name: slack-search
description: "V1.3 - Slack message search, channel discovery, and user lookup with advanced query syntax and PowerShell scripts. CRITICAL: All scripts require 6>&1 stream redirection."
disable-model-invocation: true
compatibility: Requires SLACK_USER_TOKEN environment variable, PowerShell, network access
---

# Slack Search

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Specialized skill for searching Slack messages, discovering channels, and looking up users.

**Parent skill:** [slack](../SKILL.md)

---

## ⚠️ CRITICAL: PowerShell Script Output

**ALL scripts in this skill use `Write-Information` for output.**

You MUST redirect the Information stream (6) to stdout (1) when calling scripts:

```powershell
# CORRECT
.\scripts\Search-SlackMessages.ps1 -Query "in:#dev-tribe" -Count 5 6>&1

# WRONG - No visible output
.\scripts\Search-SlackMessages.ps1 -Query "in:#dev-tribe" -Count 5
```

**Always append `6>&1` to script calls in this skill.**

---

## Message Search

**Endpoint**: `GET https://slack.com/api/search.messages`

**Requires**: User token (`$env:SLACK_USER_TOKEN`) with `search:read` scope

```powershell
$userHeaders = @{
    "Authorization" = "Bearer $env:SLACK_USER_TOKEN"
    "Content-Type" = "application/json"
}

$query = [System.Web.HttpUtility]::UrlEncode("Cortex support ticket")
$search = Invoke-RestMethod -Uri "https://slack.com/api/search.messages?query=$query&count=10" -Headers $userHeaders

# Parse results
foreach ($match in $search.messages.matches) {
    $date = [DateTimeOffset]::FromUnixTimeSeconds([double]$match.ts.Split('.')[0]).LocalDateTime
    Write-Output "$($date.ToString('yyyy-MM-dd HH:mm')): $($match.text)"
}
```

### Query Syntax

| Syntax | Description |
|--------|-------------|
| `in:#channel-name` | Search in specific channel |
| `from:@username` | Messages from specific user |
| `from:me` | Your own messages |
| `to:me` | Messages sent to you (DMs and mentions) |
| `-from:me` | Exclude your own messages |
| `@username` | Messages mentioning a user |
| `after:2024-01-01` | Search after date |
| `before:2024-12-31` | Search before date |
| `has:link` | Messages with links |
| `has:emoji` | Messages with reactions |

### Useful Search Patterns

```powershell
# Find all channels you've posted to in last 3 months
$q = [System.Web.HttpUtility]::UrlEncode("from:me after:$((Get-Date).AddMonths(-3).ToString('yyyy-MM-dd'))")

# Find @mentions of you from others
$q = [System.Web.HttpUtility]::UrlEncode("@fhemmer -from:fhemmer after:2025-01-01")

# Find messages to you (DMs + mentions)
$q = [System.Web.HttpUtility]::UrlEncode("to:me after:2025-01-01")

# Find channel ID when you can't list channels
$q = [System.Web.HttpUtility]::UrlEncode("in:#channel-name")
# Then extract: $r.messages.matches[0].channel.id
```

### Search Result Fields

- `channel.id` and `channel.name` - Useful for discovering channel IDs
- `username` - The sender's username
- `ts` - Timestamp for threading or referencing
- `text` - Message content

---

## Channel Discovery

### Find Channel ID by Name

**Method 1: Via Search (Recommended)**

Works even without `channels:read` scope:

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_USER_TOKEN"}
$q = [System.Web.HttpUtility]::UrlEncode("in:#channel-name")
$r = Invoke-RestMethod -Uri "https://slack.com/api/search.messages?query=$q&count=1" -Headers $h
if ($r.ok -and $r.messages.matches.Count -gt 0) {
    $channelId = $r.messages.matches[0].channel.id
    Write-Host "Channel ID: $channelId"
}
```

**Method 2: Via conversations.list**

Requires `channels:read` scope:

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_USER_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/conversations.list?types=public_channel,private_channel&limit=1000" -Headers $h
$channel = $r.channels | Where-Object { $_.name -eq "channel-name" }
Write-Host "Channel ID: $($channel.id)"
```

**Method 3: Via Slack UI**

Right-click channel → View channel details → Copy link (ID is in URL)

---

## User Lookup

### Find User by Email

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$user = Invoke-RestMethod -Uri "https://slack.com/api/users.lookupByEmail?email=user@example.com" -Headers $h
Write-Output "User ID: $($user.user.id)"
```

### Get User Info by ID

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/users.info?user=U2XMZDPJ7" -Headers $h
if ($r.ok) {
    Write-Host "Display Name: $($r.user.profile.display_name)"
    Write-Host "Real Name: $($r.user.real_name)"
    Write-Host "Username: $($r.user.name)"
}
```

### List All Users

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/users.list" -Headers $h
$r.members | Select-Object id, name, real_name, is_bot
```

### Find Bot User IDs

**Method 1: auth.test (if you have bot's token)**

```powershell
$botToken = "xoxb-your-bot-token"
$h = @{"Authorization"="Bearer $botToken"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/auth.test" -Headers $h
if ($r.ok) {
    Write-Host "Bot User ID: $($r.user_id)"  # Use for @mentions
    Write-Host "Bot Name: $($r.user)"
}
```

**Method 2: Search users.list for bots**

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/users.list?limit=500" -Headers $h
$r.members | Where-Object { $_.is_bot -eq $true } | Select-Object id, name, real_name
```

---

## PowerShell Scripts

### Search-SlackMessages.ps1

Search Slack messages with advanced filtering:

```powershell
# Basic search (REMEMBER: 6>&1 redirects Information stream)
.\scripts\Search-SlackMessages.ps1 -Query "deployment" -Count 10 6>&1

# Channel-specific search
.\scripts\Search-SlackMessages.ps1 -Query "in:#dev-portal after:2024-12-01" -Count 20 6>&1

# User-specific search
.\scripts\Search-SlackMessages.ps1 -Query "from:@fhemmer Cortex" -Count 15 6>&1

# Table output format
.\scripts\Search-SlackMessages.ps1 -Query "support ticket" -OutputFormat Table 6>&1

# JSON output for parsing
.\scripts\Search-SlackMessages.ps1 -Query "error" -Count 5 -OutputFormat JSON 6>&1
```

**Parameters:**

- `-Query` (required) - Search query with advanced syntax support
- `-Count` - Number of results (1-100, default 10)
- `-SortBy` - Sort by 'timestamp' or 'score' (default timestamp)
- `-SortDirection` - 'desc' or 'asc' (default desc)
- `-OutputFormat` - 'List', 'Table', or 'JSON' (default List)

### Get-SlackDailyBriefing.ps1

Get comprehensive overview of Slack activity:

```powershell
# Get today's briefing (default) - REMEMBER: 6>&1
.\scripts\Get-SlackDailyBriefing.ps1 6>&1

# Get briefing for the last 3 days with detailed output
.\scripts\Get-SlackDailyBriefing.ps1 -DaysBack 3 -OutputFormat Detailed 6>&1

# Focus on specific channels
.\scripts\Get-SlackDailyBriefing.ps1 -Channels @("relias-engineering", "dev-tribe") 6>&1

# Get JSON output for parsing
.\scripts\Get-SlackDailyBriefing.ps1 -DaysBack 1 -OutputFormat JSON 6>&1
```

**Features:**

- Finds @mentions from others
- Lists DMs grouped by sender
- Detects @channel/@here announcements
- Auto-discovers active deployment channels
- Identifies potential action items
- Color-coded summary with counts

---

## Known IDs

### Channels

| Channel | ID | Notes |
|---------|----|----- |
| #pe-bot-test | `C08H7CG4NTS` | Test channel |
| #productivity-engineering-private | `C065W8AUL8P` | PE private |

### Users

| User | ID | Type |
|------|----|----- |
| Franz Hemmer | `U2XMZDPJ7` | Human |
| Relias Assistant | `U08GJU7S7BM` | Bot |
| slack_skill_bot | `U0A780L15S8` | Bot |

---

## Resources

- **Parent skill**: [slack](../SKILL.md)
- **Search API**: <https://docs.slack.dev/reference/methods/search.messages>
- **Users API**: <https://docs.slack.dev/reference/methods/users.info>
