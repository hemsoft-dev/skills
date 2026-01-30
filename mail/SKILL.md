---
name: mail
description: V1.2 - Query emails across Outlook, Gmail, and IMAP accounts. Supports today, unread, recent, search, and date-filtered queries.
---

# Mail Skill

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Unified multi-account email access. Output uses TOON format (60-70% token savings). The encoding logic is powered by the [token-encoder](../token-encoder/SKILL.md) skill.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Accounts

| Key | Provider | Status |
|-----|----------|--------|
| `outlook` | Personal Outlook/Hotmail | ✅ Working |
| `gmail` | Personal Gmail | ✅ Working |
| `work` | Work Outlook (Azure AD) | ⏸️ Blocked (awaiting org admin consent) |
| `hemmer.us` | Personal IMAP (hemmer.us) | ✅ Working |

## Task Scripts

| Task | Script | Usage |
|------|--------|-------|
| Today's count | `tasks/mail-today.ps1` | `-Account gmail` or omit for ALL |
| Today's list | `tasks/mail-today.ps1` | `-List -Count 10` |
| Unread list | `tasks/mail-unread.ps1` | `-Account outlook -Count 20` |
| Recent inbox | `tasks/mail-recent.ps1` | `-Account hemmer.us -Count 5` |
| Yesterday's emails | `tasks/mail-recent.ps1` | `-Days 1` |
| Specific day | `tasks/mail-recent.ps1` | `-Days 3` (3 days ago) |
| Search | `tasks/mail-search.ps1` | `-Query "invoice" -Account outlook` |
| Daily summary | `tasks/mail-summary.ps1` | `-Account gmail` or omit for ALL |
| Set message status (Read/Unread) | `tasks/mail-setstatus.ps1` | `-Account gmail -Status Unread -MessageId 19b3828cfee82924` |

```powershell
# Query all configured accounts
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-today.ps1"

# Query specific account
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-today.ps1" -Account gmail -List

# Unread emails
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-unread.ps1" -Count 5

# Recent emails (any status) - useful for accounts with no unread/today
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-recent.ps1" -Account hemmer.us

# Yesterday's emails across all accounts
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-recent.ps1" -Days 1

# Emails from 3 days ago
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-recent.ps1" -Days 3 -Account outlook

# Search across all accounts
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-search.ps1" -Query "meeting"

# Daily summary/digest
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-summary.ps1"
```

## Architecture

```
tasks/
├── mail-today.ps1      # Parent: calls children, aggregates results
├── mail-unread.ps1     # Parent: calls children, aggregates results
├── mail-recent.ps1     # Parent: recent emails (any status)
├── mail-search.ps1     # Parent: keyword search
├── mail-summary.ps1    # Parent: daily digest
├── outlook/            # Personal Outlook via Graph API
│   ├── mail-today.ps1
│   ├── mail-unread.ps1
│   ├── mail-recent.ps1
│   ├── mail-search.ps1
│   └── mail-summary.ps1
├── gmail/              # Personal Gmail via Gmail API
│   ├── mail-today.ps1
│   ├── mail-unread.ps1
│   ├── mail-recent.ps1
│   ├── mail-search.ps1
│   └── mail-summary.ps1
├── work/               # Work Outlook (blocked - awaiting admin consent)
│   ├── mail-today.ps1
│   ├── mail-unread.ps1
│   ├── mail-recent.ps1
│   ├── mail-search.ps1
│   └── mail-summary.ps1
└── hemmer.us/          # Personal IMAP via MailKit
    ├── mail-today.ps1
    ├── mail-unread.ps1
    ├── mail-recent.ps1
    ├── mail-search.ps1
    ├── mail-summary.ps1
    └── mail-setstatus.ps1  # Set message status (Read/Unread) via IMAP


Parent scripts call same-named children in account folders. Unconfigured accounts are skipped.

## Set message status examples
```powershell
# Set Gmail message to Unread (Gmail message id)
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-setstatus.ps1" -Account gmail -Status Unread -MessageId 19b3828cfee82924

# Set hemmer.us IMAP message to Read (IMAP UID)
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-setstatus.ps1" -Account hemmer.us -Status Read -MessageId 19140
```

```

Parent scripts call same-named children in account folders. Unconfigured accounts are skipped.

## Search Syntax

| Provider | Date | Sender | Unread |
|----------|------|--------|--------|
| Gmail | `after:YYYY/MM/DD` | `from:x@y` | `is:unread` |
| Outlook | `received:>=YYYY-MM-DD` | `from:x@y` | `isread:false` |

## TOON Output Format

```

counts[2]{account,today,unread}:
  outlook,5,2
  gmail,17,7
total: 22
unread: 9
unconfigured: work,hemmer.us

```

## Setup

### Outlook (one-time)
1. Register app at [Azure Portal](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)
2. Personal accounts only, enable "Allow public client flows"
3. `[Environment]::SetEnvironmentVariable("GRAPH_CLIENT_ID", "your-id", "User")`

### Gmail (one-time)
1. Create project at [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Gmail API, create OAuth credentials
3. Set `GMAIL_CLIENT_ID` and `GMAIL_CLIENT_SECRET` env vars

### hemmer.us IMAP (one-time)
```powershell
[Environment]::SetEnvironmentVariable("IMAP_HEMMER_HOST", "mail.hemmer.us", "User")
[Environment]::SetEnvironmentVariable("IMAP_HEMMER_USER", "you@hemmer.us", "User")
[Environment]::SetEnvironmentVariable("IMAP_HEMMER_PASS", "your-password", "User")
# Optional: IMAP_HEMMER_PORT defaults to 993
```

### Work Outlook ⏸️ BLOCKED

Code complete but blocked by organization policy requiring admin consent for third-party apps.

### First Auth

Run any task script - authentication will be triggered automatically on first use:

```powershell
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-today.ps1" -Account outlook
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-today.ps1" -Account gmail
pwsh -File "$env:USERPROFILE\.claude\skills\mail\tasks\mail-recent.ps1" -Account hemmer.us
```
