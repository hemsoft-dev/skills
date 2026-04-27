# Device Inventory — hemmer.us Email

All devices currently configured with hemmer.us email accounts.
Must be reconfigured during Phase 4 (MX cutover to Google Workspace).

## Franz Hemmer (`franz@hemmer.us`)

| Device | Type | Email Client | Send As | Notes |
|--------|------|-------------|---------|-------|
| PC (Windows) | Desktop | Outlook | `franz@hemmer.us` | Primary desktop client |
| iPhone | Mobile | Mail.app | `franz@hemmer.us` | — |
| iPad | Tablet | Mail.app | `franz@hemmer.us` | — |

## Rebecca Hemmer (`rebecca@hemmer.us`)

| Device | Type | Email Client | Send As | Notes |
|--------|------|-------------|---------|-------|
| PC (Windows) | Desktop | Outlook | `rebecca@hemmer.us`, **`rebecca@nowleadershipgroup.com`** | ⚠️ "Send as" NLG configured here |
| iPhone | Mobile | Mail.app | `rebecca@hemmer.us` | May also send as NLG — verify |
| iPad | Tablet | Mail.app | `rebecca@hemmer.us` | — |

## Send As Configuration

Only **Rebecca** has "Send as" configured:

- **From address**: `rebecca@nowleadershipgroup.com`
- **Reply-to**: `rebecca@nowleadershipgroup.com`
- **Configured in**: Outlook desktop (confirmed), possibly iPhone Mail.app
- **Known issue**: Display name shows `"rebecca@hemmer.us"` instead of `"Rebecca Hemmer"` (see TODO.md)

## Phase 4 Cutover Checklist

When switching to Google Workspace, each device needs:

1. Remove old hemmer.us IMAP/POP account
2. Add Google account (sign in with `{user}@hemmer.us`)
3. Verify send/receive works
4. For Rebecca: verify "Send as `rebecca@nowleadershipgroup.com`" works (after Phase 5)

| Device | Owner | Reconfigured? |
|--------|-------|---------------|
| Franz PC | Franz | ☐ |
| Franz iPhone | Franz | ☐ |
| Franz iPad | Franz | ☐ |
| Rebecca PC | Rebecca | ☐ |
| Rebecca iPhone | Rebecca | ☐ |
| Rebecca iPad | Rebecca | ☐ |
