---
name: slack
description: V2.3 - Slack Web API for messaging, channels, search, and files. Primary entry point with links to specialized sub-skills for search, files, and advanced features.
compatibility: Requires SLACK_TOKEN and SLACK_USER_TOKEN environment variables, PowerShell, network access
---

# Slack Web API

**Primary entry point** for Slack API operations. For specialized functionality, see the sub-skills below.

## 📋 Sub-Skills

| Skill | Purpose |
|-------|---------|
| **[slack-search](../slack-search/SKILL.md)** | Message search, channel discovery, user lookup |
| **[slack-files](../slack-files/SKILL.md)** | File uploads, downloads, temp folder management |
| **[slack-advanced](../slack-advanced/SKILL.md)** | Reminders, bookmarks, pins, DMs, reactions, AI Agent |

---

## 🚨🚨🚨 ABSOLUTE RULE: NEVER RETRY MESSAGE POSTS 🚨🚨🚨

**THIS IS THE MOST IMPORTANT RULE IN THIS ENTIRE SKILL.**

When you post a message to Slack:

1. **RUN THE COMMAND ONCE. EXACTLY ONCE.**
2. **DO NOT CHECK IF IT WORKED.**
3. **DO NOT RETRY IF OUTPUT LOOKS EMPTY OR WEIRD.**
4. **TELL THE USER "Posted to #channel" AND STOP.**

**WHY THIS MATTERS:**

- Terminal output is often blank or truncated — **this is normal, not a failure**
- Slack API calls almost always succeed
- Every retry = another duplicate message in the channel
- Users HATE seeing the same message 2-3 times
- If the message truly failed, the user will tell you

**THE ONLY TIME TO RETRY:** When the user explicitly says "it didn't post" or "I don't see it."

**VIOLATING THIS RULE IS UNACCEPTABLE.** It damages user trust and spams channels.

---

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## ⚠️ CRITICAL: Message Posting Rules

**NEVER post, send, or react in Slack without explicit user approval.**

Before executing ANY write operation (post message, add reaction, upload file, etc.):

1. Show the user exactly what will be sent
2. Show which channel/user will receive it
3. Wait for explicit "yes", "go ahead", or similar confirmation
4. If user says no or is unclear, DO NOT proceed

**Read-only operations** (list channels, get messages, user info) are safe and don't require approval.

---

## 📢 Monitored Channels for Daily Highlights

When gathering daily Slack highlights (e.g., for diary entries), monitor these 18 channels:

**Direct Messages:** All DMs

**AI & Development:**

- #ai-chapter, #dev-ex-private, #prod-eng-devex-private
- #productivity-engineering-private, #productivity-engineering-public
- #relias-cortex-external

**Platform & Engineering:**

- #dev-tribe, #next-deployment, #swatteam, #systems-mangement
- #architecture, #dev-env-help, #platform, #product-engineering
- #relias-engineering, #software-quality, #sonarcloud-public

**Highlight Criteria:**

- Important announcements and decisions
- Technical discussions with actionable insights
- Project updates and milestones
- Mentions of @fhemmer
- **Help provided**: When someone helped solve a problem or steered things in the right direction
- **Thread context**: For threaded messages, read the FULL thread to understand the substance
- Exclude: Bot notifications, simple acks, routine alerts, surface-level pleasantries

**⚠️ CRITICAL: Capture Substance, Not Pleasantries**

When summarizing Slack messages:

- **Read full threads**: If a message is part of a thread, read the entire conversation to understand context
- **Focus on value**: What help was provided? What problem was solved? What direction was given?
- **Don't summarize trivial endings**: "Good luck" or "Thanks" at the end of a thread is not the highlight
- **Example BAD**: "Franz wished someone good luck on a task"
- **Example GOOD**: "Franz helped troubleshoot GitHub deploy key setup for Webscale integration"

**Method for Gathering Daily Highlights:**

```powershell
# Use Search-SlackMessages.ps1 with date filters (RECOMMENDED)
# IMPORTANT: 'after' is EXCLUSIVE - to get messages FROM Jan 16, use after:Jan 15
$targetDate = "2026-01-16"
$dayBefore = "2026-01-15"  # after: is exclusive, so use day before target
$dayAfter = "2026-01-17"   # before: is exclusive, so use day after target
& "$env:USERPROFILE\.claude\skills\slack\scripts\Search-SlackMessages.ps1" -Query "in:#dev-tribe after:$dayBefore before:$dayAfter -from:@email -from:@datadog" -Count 20 -OutputFormat List

# If using Get-SlackChannelMessages.ps1, manually filter by timestamp
& "$env:USERPROFILE\.claude\skills\slack\scripts\Get-SlackChannelMessages.ps1" -Channel "dev-tribe" -Count 20 -MaxThreadReplies 0
# Then check each message's timestamp and only include messages from target date
```

**⚠️ CRITICAL: Date Validation**

**ALWAYS verify message dates before including in reports.** When gathering daily highlights:

1. **Use date-filtered search**: `Search-SlackMessages.ps1` with `after:(target-1day) before:(target+1day)`
   - **IMPORTANT**: `after:` is EXCLUSIVE - to get messages FROM Jan 16, use `after:2026-01-15`
   - **IMPORTANT**: `before:` is EXCLUSIVE - to get messages UP TO Jan 16, use `before:2026-01-17`
2. **Check timestamps**: Verify each message's timestamp matches the target date
3. **Filter out old messages**: If `Get-SlackChannelMessages.ps1` is used, manually filter by date
4. **Accept empty results**: If no messages found for a specific date, that's valid - don't include old messages

**Common mistake**: Using `after:YYYY-MM-DD` to get messages from that date. The `after` parameter is exclusive, not inclusive. Use the day before your target date.

---

## 🎨 REQUIRED: Beautiful Message Formatting

**ALL messages MUST use Block Kit for professional, polished posts.**

> 📋 **Need a template?** See [block-kit-templates.md](block-kit-templates.md) for complete examples.

### Quick Block Kit Template

```powershell
$body = @{
    channel = "C08H7CG4NTS"
    text = "Fallback text for notifications"  # REQUIRED
    blocks = @(
        @{
            type = "header"
            text = @{ type = "plain_text"; text = "🚀 Your Title Here"; emoji = $true }
        }
        @{
            type = "section"
            text = @{ type = "mrkdwn"; text = "*Key info:* Details here" }
        }
        @{ type = "divider" }
        @{
            type = "context"
            elements = @(
                @{ type = "mrkdwn"; text = "Posted by <@U2XMZDPJ7> • $(Get-Date -Format 'MMM d, yyyy h:mm tt')" }
            )
        }
    )
} | ConvertTo-Json -Depth 10
```

**Common Patterns:**

- Deployment: `🚀 header → 📊 fields → divider → context`
- Alert: `⚠️ header → section → fields → actions`
- Report: `📊 header → context (dates) → section → divider → context`

---

## Authentication

All API requests require a Bearer token:

```powershell
$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"  # or $env:SLACK_USER_TOKEN
    "Content-Type" = "application/json"
}
```

### Token Types

**Bot Token** (`$env:SLACK_TOKEN` / `xoxb-`):

- Use for: Posting messages, reactions, file uploads, DMs, reminders, bookmarks
- Scopes: Full messaging, files, reactions, channels, users, AI Agent

**User Token** (`$env:SLACK_USER_TOKEN` / `xoxp-`):

- Use for: Searching messages, listing all channels, reading history
- Scopes: search:read, channels:read, users:read, files:read

**Current Status (Relias Engineering):** Both tokens valid ✓

---

## Common Operations

### Send Message

```powershell
$body = @{
    channel = "C1234567890"  # or "#channel-name"
    text = "Hello from PowerShell!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Headers $headers -Method Post -Body $body
```

### Get Channel Messages

**PRIMARY TOOL** for retrieving messages:

```powershell
.\scripts\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -Count 10 -MaxThreadReplies 0
```

### List Channels

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_USER_TOKEN"}
Invoke-RestMethod -Uri "https://slack.com/api/conversations.list?types=public_channel,private_channel" -Headers $h
```

### Get User Info

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/users.info?user=U2XMZDPJ7" -Headers $h
Write-Host "Name: $($r.user.real_name)"
```

---

## Finding IDs

### Channel IDs (start with `C`)

**Recommended method:**

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_USER_TOKEN"}
$q = [System.Web.HttpUtility]::UrlEncode("in:#channel-name")
$r = Invoke-RestMethod -Uri "https://slack.com/api/search.messages?query=$q&count=1" -Headers $h
$r.messages.matches[0].channel.id
```

**Known Channels:**

- `C08H7CG4NTS` - #pe-bot-test (always use for testing)
- `C065W8AUL8P` - #productivity-engineering-private

### User IDs (start with `U`)

```powershell
# By email
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/users.lookupByEmail?email=user@example.com" -Headers $h
Write-Host $r.user.id
```

**Known Users:**

- `U2XMZDPJ7` - Franz Hemmer
- `U08GJU7S7BM` - Relias Assistant (bot)
- `U0A780L15S8` - slack_skill_bot (bot)

---

## PowerShell Scripts

### Get-SlackDailyBriefing.ps1 ⭐

**RECOMMENDED** for daily Slack overview:

```powershell
.\scripts\Get-SlackDailyBriefing.ps1 -DaysBack 1 -OutputFormat Detailed
```

Features: @mentions, DMs, @channel announcements, action items

### Get-SlackChannelMessages.ps1

**PRIMARY TOOL** for retrieving messages:

```powershell
.\scripts\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -Count 10 -MaxThreadReplies 0
```

### Send-SlackMessage.ps1

Post with approval workflow:

```powershell
.\scripts\Send-SlackMessage.ps1 -Channel "#pe-bot-test" -Text "Test message"
```

**For search, files, and advanced features, see the sub-skills listed at the top.**

---

## Troubleshooting

**"missing_scope" error:** Use correct token (bot for posting, user for searching)

**"channel_not_found" error:**

1. Bot not a member → `/invite @slack_skill_bot`
2. Use `chat:write.public` scope for public channels
3. Verify channel ID with search

**Verify token:**

```powershell
$r = Invoke-RestMethod -Uri "https://slack.com/api/auth.test" -Headers @{"Authorization"="Bearer $env:SLACK_TOKEN"}
if ($r.ok) { "Valid: $($r.user) on $($r.team)" }
```

---

## Resources

- **[block-kit-templates.md](block-kit-templates.md)** - Ready-to-use message templates
- **[slack-search](../slack-search/SKILL.md)** - Search and discovery
- **[slack-files](../slack-files/SKILL.md)** - File operations
- **[slack-advanced](../slack-advanced/SKILL.md)** - Advanced features
- **Web API**: <https://docs.slack.dev/reference/methods>
- **Block Kit Builder**: <https://app.slack.com/block-kit-builder>
