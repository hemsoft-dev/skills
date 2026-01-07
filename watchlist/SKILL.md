---
name: watchlist
description: V1.0 - Tracks items you want to monitor with status and optional expiration dates.
---

# Watchlist

Manage a personal watchlist of items to keep an eye on.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Data File

All entries are stored in `WATCHLIST.md` (same directory as this skill).

## Commands

| Command | Description |
|---------|-------------|
| `add` | Add a new item to the watchlist |
| `list` | Show all watchlist items |
| `update` | Modify status or details of an item |
| `remove` | Delete an item from the watchlist |
| `expired` | Show items past their expiration date |

## Entry Format

Each entry in WATCHLIST.md follows this structure:

```markdown
## {Item Name}
- **Status**: {Active|Watching|Resolved|On Hold}
- **Added**: {YYYY-MM-DD}
- **Expires**: {YYYY-MM-DD|Never}
- **Notes**: {Optional context}
```

## Status Values

| Status | Meaning |
|--------|---------|
| Active | Actively monitoring |
| Watching | Passive observation |
| Resolved | No longer needs tracking |
| On Hold | Temporarily paused |

## Workflow

1. Read `WATCHLIST.md` to get current state
2. Perform requested operation
3. Write updated content back to `WATCHLIST.md`
4. Report what changed

## Examples

- "Add Tesla stock to watchlist, expires 2025-03-01"
- "Update my laptop repair to Resolved"
- "Show expired items"
- "Remove the job application entry"
