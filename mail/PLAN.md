# Mail Skill Architecture Plan

## Overview

Unified multi-account email skill with parent/child script architecture for simplicity and maintainability.

## Email Accounts

| Account | Folder | Provider | Status |
|---------|--------|----------|--------|
| Personal Outlook | `outlook/` | Microsoft Graph | ✅ Working |
| Personal Gmail | `gmail/` | Gmail API | ✅ Working |
| Work Outlook | `work/` | Microsoft Graph | ⏸️ Blocked (awaiting org admin consent) |
| Personal IMAP | `hemmer.us/` | IMAP (MailKit) | ✅ Working |

## Architecture: Parent/Child Scripts

### Design Principles
- **One use case = one parent script** - deterministic, no runtime discovery
- **Hardcoded account list** - parent knows all 4 accounts, calls each child
- **Unless `-Account` specified** - query all accounts by default
- **Same script name** - parent and children share name (e.g., `mail-today.ps1`)
- **Aggregated output** - parent combines all child results into single TOON output

### Folder Structure

```
~/.claude/skills/my-mail/
├── SKILL.md                    # Compact use case reference
├── PLAN.md                     # This file
│
├── lib/                        # Shared utilities
│   └── toon-encode.ps1         # TOON CLI wrapper
│
└── tasks/                      # Use case scripts
    ├── mail-today.ps1          # Parent: today's email count/list
    ├── mail-unread.ps1         # Parent: unread emails
    │
    ├── outlook/                # Personal Outlook (Graph API)
    │   ├── mail-today.ps1
    │   └── mail-unread.ps1
    │
    ├── gmail/                  # Personal Gmail (Gmail API)
    │   ├── mail-today.ps1
    │   └── mail-unread.ps1
    │
    ├── work/                   # Work Outlook (Graph API, different tenant)
    │   ├── mail-today.ps1
    │   └── mail-unread.ps1
    │
    └── hemmer.us/              # Personal IMAP (hemmer.us)
        ├── mail-today.ps1
        └── mail-unread.ps1
```

### Script Interface Pattern

**Parent scripts** accept:
```powershell
param(
    [ValidateSet("outlook", "gmail", "work", "hemmer.us")]
    [string]$Account,  # If omitted, queries ALL accounts
    [int]$Count = 10   # Use case specific params
)
```

**Child scripts** accept same params minus `-Account` (implicit from folder).

### Execution Flow

```
User: "How many emails today?"
           │
           ▼
    tasks/mail-today.ps1 (parent)
           │
           ├──► tasks/outlook/mail-today.ps1 ──► TOON result
           ├──► tasks/gmail/mail-today.ps1 ──► TOON result
           ├──► tasks/work/mail-today.ps1 ──► TOON result (or skip if not set up)
           └──► tasks/hemmer.us/mail-today.ps1 ──► TOON result (or skip if not set up)
           │
           ▼
    Aggregate into single TOON output
```

```
User: "How many emails on my work account?"
           │
           ▼
    tasks/mail-today.ps1 -Account work
           │
           └──► tasks/work/mail-today.ps1 only
           │
           ▼
    Single account TOON output
```

## Provider Implementation Notes

### Personal Outlook
- Microsoft Graph API
- Personal Microsoft accounts (consumers tenant)
- Device code flow auth
- Env: `GRAPH_CLIENT_ID`
- Token cache: `~/.my-mail-outlook.json`

### Personal Gmail
- Gmail API
- OAuth 2.0 with localhost redirect
- Env: `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`
- Token cache: `~/.my-mail-gmail.json`

### Work Outlook ⏸️ BLOCKED (Awaiting Admin Consent)
- Microsoft Graph API
- Work/school account (Azure AD tenant)
- Code complete, blocked by organization policy requiring admin consent for third-party apps
- Env: `GRAPH_WORK_CLIENT_ID` (or reuse with multi-tenant)
- Token cache: `~/.my-mail-work.json`
- **TODO:** Re-test once admin grants consent, or register app directly in work Azure AD

### Personal IMAP (hemmer.us)
- MailKit library (loaded from `packages/` folder)
- IMAP4 over SSL (port 993)
- Env: `IMAP_HEMMER_HOST`, `IMAP_HEMMER_PORT` (default 993), `IMAP_HEMMER_USER`, `IMAP_HEMMER_PASS`
- Use App Password if 2FA enabled on mail provider

## Use Cases

| Use Case | Parent Script | Description |
|----------|---------------|-------------|
| Today's count | `mail-today.ps1` | Count/list emails received today |
| Unread list | `mail-unread.ps1` | List unread emails |
| Recent inbox | `mail-recent.ps1` | Most recent emails (any status) |
| Search | `mail-search.ps1` | Keyword search across accounts |
| Daily summary | `mail-summary.ps1` | Aggregated daily digest with highlights |

## Output Format: TOON

All scripts output TOON format for token efficiency (60-70% reduction vs JSON).

```
counts[4]{account,today,unread}:
  outlook,5,2
  gmail,17,7
  work,23,12
  imap,2,0
total: 47
unread: 21
```

## Implementation Phases

### Phase 0: TOON Encoder ✅ COMPLETE
- [x] Implement `toon-encode.ps1` wrapper for official `@toon-format/cli`

### Phase 1: Initial Structure ✅ COMPLETE
- [x] Create task scripts for existing accounts (monolithic)
- [x] Restructure SKILL.md to two-layer format
- [x] Test with Gmail/Outlook

### Phase 1.5: Refactor to Parent/Child Architecture ✅ COMPLETE
- [x] Create account subfolders: `outlook/`, `gmail/`, `work/`, `imap/`
- [x] Extract provider-specific logic from current scripts into children
- [x] Create parent orchestrator scripts
- [x] Migrate auth/token logic into child scripts (via lib/)
- [x] Remove `mail.ps1` (functionality migrated to task scripts and lib/)
- [x] Update SKILL.md for new structure
- [x] Test parent/child flow with existing accounts

### Phase 2: Work Outlook ⏸️ BLOCKED
- [x] Create `work/` child scripts
- [x] Create `lib/work-auth.ps1` (device code flow, "organizations" tenant)
- [x] Configure app for multi-tenant (`signInAudience: AzureADandPersonalMicrosoftAccount`)
- [ ] ~~Test work account integration~~ **Blocked: work org requires admin consent for third-party apps**
- Options when unblocked: wait for admin approval, or register app directly in work Azure AD

### Phase 3: IMAP Support ✅ COMPLETE
- [x] Choose IMAP library (MailKit)
- [x] Install MailKit DLLs to `packages/` folder
- [x] Create `lib/imap-auth.ps1` helper (connection, auth, message fetching)
- [x] Create `hemmer.us/mail-today.ps1` (today's messages via DeliveredAfter query)
- [x] Create `hemmer.us/mail-unread.ps1` (unread messages via NotSeen query)
- [x] Create `hemmer.us/mail-recent.ps1` (recent messages via All query)
- [x] Test IMAP integration - working with 83 messages

### Phase 3.5: mail-recent.ps1 Use Case ✅ COMPLETE
- [x] Create parent `mail-recent.ps1`
- [x] Create `outlook/mail-recent.ps1`
- [x] Create `gmail/mail-recent.ps1`
- [x] Create `hemmer.us/mail-recent.ps1`
- [x] Create `work/mail-recent.ps1` (stub - blocked)

### Phase 4: Additional Use Cases ✅ COMPLETE
- [x] Implement `mail-search.ps1` (parent + children) - keyword search across accounts
- [x] Implement `mail-summary.ps1` (parent + children) - daily digest with counts + highlights
- [ ] Any other use cases as needed

## Changelog

| Date | Change |
|------|--------|
| 2025-12-19 | Phase 4 complete: mail-search.ps1 and mail-summary.ps1 |
| 2025-12-19 | Phase 3.5 complete: mail-recent.ps1 for all accounts |
| 2025-12-19 | Phase 3 complete: hemmer.us IMAP working (83 messages) |
| 2025-12-19 | Phase 2 blocked: work org requires admin consent, code ready |
| 2025-12-18 | Phase 1.5 complete: parent/child architecture tested |
| 2025-12-18 | Architecture redesign: parent/child script pattern |
| 2025-12-18 | Phase 1 complete: initial task scripts |
| 2025-12-18 | Phase 0 complete: TOON encoder |
| 2025-12-18 | Initial plan created |
