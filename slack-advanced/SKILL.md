---
name: slack-advanced
description: V1.0 - Advanced Slack features including DMs, reminders, bookmarks, pins, reactions, user groups, emoji, DND status, and AI Agent capabilities.
compatibility: Requires SLACK_TOKEN environment variable, PowerShell, network access
---

# Slack Advanced Features

Specialized skill for advanced Slack operations including DMs, reminders, bookmarks, pins, reactions, and AI Agent capabilities.

**Parent skill:** [slack](../slack/SKILL.md)

---

## Direct Messages

### Open DM with User

**Endpoint**: `POST https://slack.com/api/conversations.open`

```powershell
$body = @{ users = "U2XMZDPJ7" } | ConvertTo-Json
$headers = @{ "Authorization"="Bearer $env:SLACK_TOKEN"; "Content-Type"="application/json" }
$dm = Invoke-RestMethod -Uri "https://slack.com/api/conversations.open" -Headers $headers -Method Post -Body $body

# Then use $dm.channel.id to send messages
$msgBody = @{
    channel = $dm.channel.id
    text = "Hello from automation!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Headers $headers -Method Post -Body $msgBody
```

---

## Reactions

### Add Reaction to Message

**Endpoint**: `POST https://slack.com/api/reactions.add`

```powershell
$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type" = "application/json"
}

$body = @{
    channel = "C1234567890"
    timestamp = "1234567890.123456"  # Message ts
    name = "thumbsup"  # Emoji name without colons
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://slack.com/api/reactions.add" -Headers $headers -Method Post -Body $body
```

### Remove Reaction

```powershell
$body = @{
    channel = "C1234567890"
    timestamp = "1234567890.123456"
    name = "thumbsup"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://slack.com/api/reactions.remove" -Headers $headers -Method Post -Body $body
```

### Get Reactions on Message

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/reactions.get?channel=C1234567890&timestamp=1234567890.123456" -Headers $h

$r.message.reactions | ForEach-Object {
    Write-Host "$($_.name): $($_.count) users"
}
```

---

## Reminders

### Create Reminder

**Endpoint**: `POST https://slack.com/api/reminders.add`

```powershell
$body = @{
    text = "Review pull request"
    time = "in 2 hours"  # or Unix timestamp, or "tomorrow at 9am"
    user = "U2XMZDPJ7"   # optional: remind someone else
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type" = "application/json"
}

Invoke-RestMethod -Uri "https://slack.com/api/reminders.add" -Headers $headers -Method Post -Body $body
```

**Time formats:**

- Relative: `"in 2 hours"`, `"in 30 minutes"`, `"tomorrow"`
- Specific: `"tomorrow at 9am"`, `"next Monday at 3pm"`
- Unix timestamp: `1704564789`

### List Reminders

**Endpoint**: `GET https://slack.com/api/reminders.list`

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/reminders.list" -Headers $h

$r.reminders | ForEach-Object {
    $time = [DateTimeOffset]::FromUnixTimeSeconds($_.time).LocalDateTime
    Write-Host "$($time.ToString('yyyy-MM-dd HH:mm')): $($_.text)"
}
```

### Delete Reminder

```powershell
$body = @{ reminder = "Rm1234567890" } | ConvertTo-Json
Invoke-RestMethod -Uri "https://slack.com/api/reminders.delete" -Headers $headers -Method Post -Body $body
```

---

## Bookmarks

### Add Bookmark to Channel

**Endpoint**: `POST https://slack.com/api/bookmarks.add`

```powershell
$body = @{
    channel_id = "C08H7CG4NTS"
    title = "Team Wiki"
    type = "link"
    link = "https://wiki.example.com"
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type" = "application/json"
}

Invoke-RestMethod -Uri "https://slack.com/api/bookmarks.add" -Headers $headers -Method Post -Body $body
```

### List Channel Bookmarks

**Endpoint**: `GET https://slack.com/api/bookmarks.list`

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/bookmarks.list?channel_id=C08H7CG4NTS" -Headers $h

$r.bookmarks | ForEach-Object {
    Write-Host "$($_.title): $($_.link)"
}
```

### Remove Bookmark

```powershell
$body = @{
    bookmark_id = "Bm1234567890"
    channel_id = "C08H7CG4NTS"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://slack.com/api/bookmarks.remove" -Headers $headers -Method Post -Body $body
```

---

## Pins

### Pin Message

**Endpoint**: `POST https://slack.com/api/pins.add`

```powershell
$body = @{
    channel = "C08H7CG4NTS"
    timestamp = "1234567890.123456"  # message ts
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type" = "application/json"
}

Invoke-RestMethod -Uri "https://slack.com/api/pins.add" -Headers $headers -Method Post -Body $body
```

### List Pinned Items

**Endpoint**: `GET https://slack.com/api/pins.list`

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/pins.list?channel=C08H7CG4NTS" -Headers $h

$r.items | ForEach-Object {
    if ($_.message) {
        Write-Host "$($_.message.user): $($_.message.text.Substring(0, [Math]::Min(50, $_.message.text.Length)))"
    }
}
```

### Unpin Message

```powershell
$body = @{
    channel = "C08H7CG4NTS"
    timestamp = "1234567890.123456"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://slack.com/api/pins.remove" -Headers $headers -Method Post -Body $body
```

---

## User Groups (Handles)

### List User Groups

**Endpoint**: `GET https://slack.com/api/usergroups.list`

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/usergroups.list?include_users=true" -Headers $h

$r.usergroups | Select-Object handle, name, user_count
```

**Example output:**

- `@developers` (handle: `developers`, name: `Developers`, users: 45)
- `@leads` (handle: `leads`, name: `Team Leads`, users: 8)

### Get User Group Members

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/usergroups.users.list?usergroup=S1234567890" -Headers $h

Write-Host "Members: $($r.users -join ', ')"
```

---

## Custom Emoji

### List Workspace Emoji

**Endpoint**: `GET https://slack.com/api/emoji.list`

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/emoji.list" -Headers $h

$r.emoji.PSObject.Properties | Select-Object Name, Value | Format-Table
```

**Use custom emoji in messages:**

```text
:custom_emoji_name:
```

---

## Do Not Disturb Status

### Get User's DND Status

**Endpoint**: `GET https://slack.com/api/dnd.info`

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/dnd.info?user=U2XMZDPJ7" -Headers $h

if ($r.dnd_enabled) {
    $endTime = [DateTimeOffset]::FromUnixTimeSeconds($r.next_dnd_end_ts)
    Write-Host "DND active until: $($endTime.LocalDateTime)"
} else {
    Write-Host "DND not active"
}
```

### Get Team DND Info

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/dnd.teamInfo?users=U2XMZDPJ7,U08GJU7S7BM" -Headers $h

foreach ($userId in $r.users.PSObject.Properties.Name) {
    $info = $r.users.$userId
    Write-Host "$userId - DND: $($info.dnd_enabled)"
}
```

---

## Team/Workspace Info

### Get Workspace Info

**Endpoint**: `GET https://slack.com/api/team.info`

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/team.info" -Headers $h

Write-Host "Workspace: $($r.team.name)"
Write-Host "Domain: $($r.team.domain).slack.com"
Write-Host "Email Domain: $($r.team.email_domain)"
```

---

## Public Channel Operations

### Join Public Channel

**Endpoint**: `POST https://slack.com/api/conversations.join`

Bot can join public channels with `channels:join` scope:

```powershell
$body = @{ channel = "C1234567890" } | ConvertTo-Json
$headers = @{ "Authorization"="Bearer $env:SLACK_TOKEN"; "Content-Type"="application/json" }
Invoke-RestMethod -Uri "https://slack.com/api/conversations.join" -Headers $headers -Method Post -Body $body
```

### Post to Public Channel (without joining)

With `chat:write.public` scope, the bot can post to public channels without being a member:

```powershell
# No need to join first - just post directly
$body = @{
    channel = "C1234567890"  # Any public channel
    text = "Hello from the bot!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Headers $headers -Method Post -Body $body
```

---

## Customized Bot Messages

### Post with Custom Username/Icon

With `chat:write.customize` scope, post with custom appearance:

```powershell
$body = @{
    channel = "C08H7CG4NTS"
    text = "Deploy notification"
    username = "DeployBot"
    icon_emoji = ":rocket:"
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type" = "application/json"
}

Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Headers $headers -Method Post -Body $body
```

**Options:**

- `username` - Custom display name
- `icon_emoji` - Emoji as avatar (e.g., `:robot_face:`)
- `icon_url` - Image URL as avatar

---

## AI Agent Capabilities

With `assistant:write` and `app_mentions:read` scopes, the bot can act as an AI Agent in Slack:

- Receive messages via `app_mentions:read`
- Respond with `assistant:write` scope
- Access AI Agent features in the Slack platform
- Participate in conversations and threads
- Provide contextual assistance

**Use cases:**

- Automated support responses
- Interactive command execution
- Workflow automation triggered by mentions
- Integration with AI/LLM services

---

## Resources

- **Parent skill**: [slack](../slack/SKILL.md)
- **Reminders API**: <https://docs.slack.dev/reference/methods/reminders.add>
- **Reactions API**: <https://docs.slack.dev/reference/methods/reactions.add>
- **Bookmarks API**: <https://docs.slack.dev/reference/methods/bookmarks.add>
- **Pins API**: <https://docs.slack.dev/reference/methods/pins.add>
