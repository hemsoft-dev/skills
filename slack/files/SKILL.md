---
name: slack-files
description: V1.1 - Slack file uploads, downloads, and temp folder management with PowerShell scripts for cleanup and organization.
compatibility: Requires SLACK_TOKEN environment variable, PowerShell, network access
---

# Slack Files

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Specialized skill for Slack file operations including uploads, downloads, and temp folder management.

**Parent skill:** [slack](../SKILL.md)

---

## File Upload

**Endpoint**: `POST https://slack.com/api/files.upload`

```powershell
$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type" = "application/json"
}

$body = @{
    channels = "C1234567890"
    content = "File content here"
    filename = "example.txt"
    title = "Example File"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://slack.com/api/files.upload" -Headers $headers -Method Post -Body $body
```

### Upload from File

```powershell
$fileContent = Get-Content "path/to/file.txt" -Raw

$body = @{
    channels = "C1234567890"
    content = $fileContent
    filename = "file.txt"
    title = "My File"
    initial_comment = "Here's the file you requested"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://slack.com/api/files.upload" -Headers $headers -Method Post -Body $body
```

---

## File Download

**⚠️ IMPORTANT: Bot must be a member of the channel to download files.**

If the bot isn't in the channel, file downloads will fail (returns HTML login page instead of file).

### Download with Get-SlackChannelMessages.ps1

```powershell
# Download files from messages
.\scripts\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -Count 5 -IncludeFiles

# Download to specific directory
.\scripts\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -IncludeFiles -OutputDir "D:\slack-downloads"
```

### Fix: Bot Not in Channel

If file downloads fail:

1. In Slack, go to the channel
2. Type `/invite @YourBotName` or click channel settings → Integrations → Add apps
3. Re-run the script

**Alternative:** Add `files:read` scope to the **user token** and reinstall the app.

---

## Temp Folder Management

**Default location:** `~/.claude/skills/slack/temp/`

Files downloaded during a session are stored here by default to avoid polluting repositories.

### Clean Up Temp Files

Use the `Clear-SlackTempFiles.ps1` script:

```powershell
# List what would be deleted (dry run)
.\scripts\Clear-SlackTempFiles.ps1 -ListOnly

# Interactive cleanup with confirmation prompt
.\scripts\Clear-SlackTempFiles.ps1

# Force cleanup without prompts (useful for session end)
.\scripts\Clear-SlackTempFiles.ps1 -Force
```

**Parameters:**

- `-ListOnly` - Preview files without deleting
- `-Force` - Skip confirmation prompt

**When to clean up:**

- At the end of a session when downloaded files are no longer needed
- Before starting a new task to free disk space
- The agent should run this automatically when finishing file-related work

---

## PowerShell Scripts

### Get-SlackChannelMessages.ps1 (with files)

**PRIMARY TOOL** for retrieving messages with file downloads:

```powershell
# Get last 5 messages from #dev-tribe with files
.\scripts\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -IncludeFiles

# Get last message with up to 5 thread replies and download attachments
.\scripts\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -Count 1 -MaxThreadReplies 5 -IncludeFiles

# Get messages with all files downloaded to specific directory
.\scripts\Get-SlackChannelMessages.ps1 -Channel "dev-tribe" -Count 3 -IncludeFiles -OutputDir "D:\slack-downloads"
```

**Parameters:**

- `-Channel` (required) - Channel name (without #) or ID
- `-Count` - Number of parent messages (1-50, default 5)
- `-MaxThreadReplies` - Max thread replies per message (default 2, 0=none, -1=all)
- `-IncludeFiles` - Download attached files
- `-OutputDir` - Where to save files (default: `~/.claude/skills/slack/temp/`)
- `-OutputFormat` - 'Summary' (default), 'Detailed', or 'JSON'

**Features:**

- Auto-resolves channel names to IDs (with fallback methods)
- Limits thread replies to prevent output overflow
- Downloads files to isolated temp folder by default
- Caches user ID lookups for performance

### Clear-SlackTempFiles.ps1

**Cleanup utility** for removing downloaded files:

```powershell
# List what would be deleted (dry run)
.\scripts\Clear-SlackTempFiles.ps1 -ListOnly

# Interactive cleanup with confirmation prompt
.\scripts\Clear-SlackTempFiles.ps1

# Force cleanup without prompts (useful for session end)
.\scripts\Clear-SlackTempFiles.ps1 -Force
```

**Temp Folder Location**: `~/.claude/skills/slack/temp/`

---

## File Information

### Get File Info

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/files.info?file=F1234567890" -Headers $h

if ($r.ok) {
    Write-Host "Name: $($r.file.name)"
    Write-Host "Size: $($r.file.size) bytes"
    Write-Host "Type: $($r.file.mimetype)"
    Write-Host "URL: $($r.file.url_private)"
}
```

### List Files in Channel

```powershell
$h = @{"Authorization"="Bearer $env:SLACK_TOKEN"}
$r = Invoke-RestMethod -Uri "https://slack.com/api/files.list?channel=C1234567890&count=10" -Headers $h

$r.files | Select-Object name, size, timestamp, mimetype
```

---

## Troubleshooting

### File Download Returns HTML

**Problem:** Bot is not a member of the channel.

**Solution:** Invite bot to the channel:

1. `/invite @slack_skill_bot` in Slack
2. Or add bot via channel settings → Integrations → Add apps

### Permission Denied

**Problem:** Token lacks `files:read` or `files:write` scope.

**Solution:**

- For downloads: Use bot token with `files:read` scope
- For uploads: Use bot token with `files:write` scope
- Verify scopes: `https://slack.com/api/auth.test`

---

## Resources

- **Parent skill**: [slack](../SKILL.md)
- **Files API**: <https://docs.slack.dev/reference/methods/files.upload>
- **Files List**: <https://docs.slack.dev/reference/methods/files.list>
