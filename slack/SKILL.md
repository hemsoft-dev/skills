---
name: slack
description: V2.7 - Slack Web API for messaging, channels, search, and files. Primary entry point with links to specialized sub-skills for search, files, and advanced features. CRITICAL: All PowerShell scripts require 6>&1 stream redirection.
compatibility: Requires SLACK_TOKEN and SLACK_USER_TOKEN environment variables, PowerShell, network access
---

# Slack Web API

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

**Primary entry point** for Slack API operations. For specialized functionality, see the sub-skills below.

## 📋 Sub-Skills

| Skill | Purpose |
|-------|---------|
| **[slack-search](search/SKILL.md)** | Message search, channel discovery, user lookup |
| **[slack-files](files/SKILL.md)** | File uploads, downloads, temp folder management |
| **[slack-advanced](advanced/SKILL.md)** | Reminders, bookmarks, pins, DMs, reactions, AI Agent |

---

## ⚠️ CRITICAL: PowerShell Script Output

**ALL Slack PowerShell scripts use `Write-Information` for output.**

When calling scripts, you MUST redirect the Information stream (6) to stdout (1) to see results:

```powershell
# CORRECT - Redirects Information stream
& "$env:USERPROFILE\.claude\skills\slack\scripts\Search-SlackMessages.ps1" -Query "in:#dev-tribe" -Count 5 6>&1

# WRONG - Output will not be visible
& "$env:USERPROFILE\.claude\skills\slack\scripts\Search-SlackMessages.ps1" -Query "in:#dev-tribe" -Count 5
```

**Why this matters:**

- Scripts run successfully but appear to produce no output without `6>&1`
- This is NOT a script failure - it's a PowerShell stream handling requirement
- Without redirection, you'll think the script failed when it actually worked perfectly

**Always use `6>&1` when calling any script in this skill.**

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
# CRITICAL: Scripts use Write-Information - redirect stream 6 to stdout with 6>&1
& "$env:USERPROFILE\.claude\skills\slack\scripts\Search-SlackMessages.ps1" -Query "in:#dev-tribe after:$dayBefore before:$dayAfter -from:@email -from:@datadog" -Count 20 -OutputFormat List 6>&1

# If using Get-SlackChannelMessages.ps1, manually filter by timestamp
& "$env:USERPROFILE\.claude\skills\slack\scripts\Get-SlackChannelMessages.ps1" -Channel "dev-tribe" -Count 20 -MaxThreadReplies 0 6>&1
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
# Remember to redirect Information stream (6>&1)
.\scripts\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -Count 10 -MaxThreadReplies 0 6>&1
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

### Request-SlackPRReview.ps1

Post PR review requests (handles backtick escaping correctly):

```powershell
$prs = @(
    @{ Number = 18; Title = "Part 1"; Url = "https://github.com/org/repo/pull/18" }
    @{ Number = 20; Title = "Part 2"; Url = "https://github.com/org/repo/pull/20" }
)
.\scripts\Request-SlackPRReview.ps1 -Channel "C09LB1CM1BK" -RepoName "relias-assistant" -PRs $prs
```

**For search, files, and advanced features, see the sub-skills listed at the top.**

---

## Troubleshooting

## Slack Skill Bot App Manifest (Reference)

Use this as the canonical manifest snapshot for the current Slack Skill Bot configuration.

```yaml
display_information:
    name: Slack Skill Bot
    description: Slack Skill Bot
    background_color: "#2e313b"
features:
    app_home:
        home_tab_enabled: true
        messages_tab_enabled: false
        messages_tab_read_only_enabled: false
    bot_user:
        display_name: Slack Skill Bot
        always_online: true
oauth_config:
    scopes:
        user:
            - channels:read
            - search:read
            - users.profile:read
            - users:read
            - users:read.email
            - files:read
        bot:
            - channels:history
            - channels:join
            - channels:read
            - chat:write
            - chat:write.customize
            - chat:write.public
            - files:read
            - files:write
            - reactions:read
            - reactions:write
            - users:read
            - im:write
            - im:history
            - im:read
            - assistant:write
            - app_mentions:read
            - users:read.email
            - users.profile:read
            - team:read
            - pins:read
            - pins:write
            - bookmarks:read
            - bookmarks:write
            - reminders:read
            - reminders:write
            - usergroups:read
            - emoji:read
            - dnd:read
settings:
    interactivity:
        is_enabled: true
    org_deploy_enabled: false
    socket_mode_enabled: true
    token_rotation_enabled: false
```

**🚨 CRITICAL: Backtick Escape Issue in PowerShell**

**NEVER use backticks for code formatting in PowerShell strings!**

PowerShell interprets backticks as escape sequences:

- `` `r `` = carriage return (breaks "relias" → "elias")
- `` `n `` = newline
- `` `t `` = tab

**BAD:** `"PRs for \`relias-assistant\`"` → "PRs for elias-assistant"

**GOOD:** `"PRs for *relias-assistant*"` (use bold instead)

Use `Request-SlackPRReview.ps1` for PR review requests - it handles this correctly.

---

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
- **[slack-search](search/SKILL.md)** - Search and discovery
- **[slack-files](files/SKILL.md)** - File operations
- **[slack-advanced](advanced/SKILL.md)** - Advanced features
- **Web API**: <https://docs.slack.dev/reference/methods>
- **Block Kit Builder**: <https://app.slack.com/block-kit-builder>
