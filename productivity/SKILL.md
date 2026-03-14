---
name: productivity
description: V1.1 - Commands: DailyLOC, UserSummary, UserBreakdown. Tracks personal productivity metrics including daily lines of code, per-user commits, pull requests, issues, workflow runs, and premium requests over a time range.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the productivity directory (path contains 'productivity'), verify that history logging occurred.
            
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
            Before stopping, if productivity was used (check if any files in productivity directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in productivity directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Productivity Skill

Tracks personal productivity metrics with deep insights into coding activity, collaboration, and issue resolution. Currently supports daily lines of code (LOC) tracking as the primary use case, with extensibility for additional metrics.

## Default Behavior

When user activates this skill without specifying an action, choose the smallest matching report:

| User asks for | Use |
|--------------|-----|
| Today or daily coding activity | `Get-TodayProductivity.ps1` |
| One user's premium requests, commits, and total PR count over a period | `Get-UserOrgProductivity.ps1` |
| One user's premium requests plus detailed PR, issue, and workflow breakdown over a period | `Get-UserProductivityBreakdown.ps1` |
| Organization-wide repository productivity ranking | `Get-OrgProductivity.ps1` |

## ⚠️ CRITICAL: Local Clone Policy (READ-ONLY)

**NEVER commit, push, or modify files in the local clone directories.**

For performance reasons, repositories are cloned to persistent local directories rather than temporary locations. These clones are used for:

- LOC snapshot calculations (checking out historical states)
- Code analysis operations
- Git history queries

### Local Clone Directories

| Organization | Local Path |
|--------------|------------|
| HemSoft / fhemmer (personal) | `D:\github\temp\hemsoft` |
| relias-engineering (work) | `D:\github\temp\relias` |

### Rules

1. **ALWAYS read-only** - Never stage, commit, or push changes
2. **Pull only** - `git fetch` and `git checkout` are safe operations
3. **No working changes** - Never leave uncommitted changes in these repos
4. **Disposable state** - If corrupted, delete and re-clone
5. **Never switch branches for work** - These are for analysis only

If user explicitly requests write operations, require confirmation and document the exception.

## Related Skills

- **[GitHub Skill](../github/SKILL.md)** - Account structure, organizations, authentication. MUST consult for:
  - Which `gh` account to use (`fhemmerrelias` for work, `HemSoft` for personal)
  - Organization names (`relias-engineering`, `fhemmer`, etc.)
  - SSH key aliases and token scopes
- **[Productivity Publisher Skill](../productivity-publisher/SKILL.md)** - Publishes monthly HTML reports to participating repos' `.relias-metrics/` folders via PRs

## Data Collection

The skill queries two sources for comprehensive productivity tracking:

1. **GitHub API** - For public/private repositories, pull requests, code reviews, and issues
2. **Local Git Repositories** - For commits and code changes across all local projects

### Premium Request Source

For Relias per-user premium request reporting, use the enterprise billing usage API:

| Field | Value |
|-------|-------|
| Enterprise slug | `bertelsmann` |
| Organization scope | `relias-engineering` |
| Product filter | `Copilot` |
| User filter | GitHub username |
| Quantity used | `grossQuantity` |

**Important**:

1. The billing endpoint rejects requests that specify both `organization` and `user` together.
2. For user-level premium request totals, query with the `user` filter only.
3. The active `gh` token needs enterprise billing access.

## Primary Use Cases

### Daily Lines of Code (LOC) Tracking

Calculate the total lines of code committed in a single day, filtered to your own commits:

- **Calculation Method**: Net changes (additions minus deletions)
- **File Scope**: Code files only (.js, .ts, .py, .cs, .ps1, .go, .rs, .java, etc.)
- **Exclusions**: Generated code, node_modules, build artifacts, documentation, images, config files
- **Time Window**: Calendar day (00:00 - 23:59 local time, or UTC if preferred)
- **Author Filtering**: Only counts commits from recognized author identities (Franz Hemmer and variations)

**Metrics Included in Daily Report**:

- Total net LOC committed
- Number of commits made
- Pull requests opened/merged
- Code reviews submitted
- Issues closed
- List of repositories touched
- File types changed
- Suspicious commits logged to Alerts skill for review

### Per-User Period Productivity

Report productivity for one GitHub username over a chosen date range in `relias-engineering`.

#### UserSummary

Use [scripts/Get-UserOrgProductivity.ps1](scripts/Get-UserOrgProductivity.ps1) when the user wants a compact summary.

| Parameter | Required | Purpose |
|-----------|----------|---------|
| `Username` | Yes | GitHub username to analyze |
| `Since` | Yes | Inclusive start date |
| `Until` | No | Inclusive end date/time; defaults to now |
| `Enterprise` | Usually | Enterprise slug for premium request lookup |

| Output | Meaning |
|--------|---------|
| Start Date | Start of reporting window |
| End Date | End of reporting window |
| Premium Requests | Total gross premium requests for the user |
| Commits | Total authored commits across org repos |
| Pull Requests | Total PRs created in the period |

#### UserBreakdown

Use [scripts/Get-UserProductivityBreakdown.ps1](scripts/Get-UserProductivityBreakdown.ps1) when the user wants the full monthly or period breakdown.

| Parameter | Required | Purpose |
|-----------|----------|---------|
| `Username` | Yes | GitHub username to analyze |
| `Since` | Yes | Inclusive start date |
| `Until` | No | Inclusive end date/time; defaults to now |

| Output | Meaning |
|--------|---------|
| Start Date | Start of reporting window |
| End Date | End of reporting window |
| Username | GitHub username analyzed |
| Premium Requests | Total gross premium requests for the user |
| Commits | Total authored commits across non-archived, non-forked org repos |
| Lines Added | Total added lines across all files in those commits |
| Lines Deleted | Total deleted lines across all files in those commits |
| Net LOC | Net lines changed across all files: additions minus deletions |
| Total Changed Lines | Total churn across all files: additions plus deletions |
| Open PRs | PRs created in the period that are still open |
| Merged PRs | PRs created in the period that were merged |
| Closed PRs | PRs created in the period that were closed without merge |
| Approved Reviews | Submitted PR reviews with `APPROVED` state in the period |
| Comment Reviews | Submitted PR reviews with `COMMENTED` state in the period |
| Open Issues | Issues created in the period that are still open |
| Closed Issues | Issues created in the period that are now closed |
| Workflow Runs | GitHub Actions workflow runs triggered by that user in the period |

### How UserBreakdown Works

1. Validate `gh` authentication and confirm the user exists.
2. Query the Bertelsmann enterprise billing usage API once per day in the requested date range using the user filter.
3. Sum `grossQuantity` from returned `usageItems` to get premium requests.
4. List non-archived, non-forked repositories in `relias-engineering`.
5. Count authored commits across those repositories with the REST commits API.
6. Fetch commit details for those commits and sum additions, deletions, net LOC, and total changed lines across all committed files.
7. Count PR states with GitHub search queries scoped to `org:relias-engineering`, `author:{username}`, and the `created:` date range.
8. Count submitted `APPROVED` and `COMMENTED` PR reviews during the period.
9. Count issue states with GitHub search queries scoped to `org:relias-engineering`, `author:{username}`, and the `created:` date range.
10. Count workflow runs with the Actions runs API using `actor={username}` and the selected date range.

### Examples

```powershell
# Compact summary for one month
.\scripts\Get-UserOrgProductivity.ps1 -Username ssadhula-relias -Since '2026-02-01' -Until '2026-02-28' -Enterprise bertelsmann

# Full monthly breakdown for one user
.\scripts\Get-UserProductivityBreakdown.ps1 -Username ssadhula-relias -Since '2026-03-01' -Until '2026-03-31'

# Month-to-date breakdown
.\scripts\Get-UserProductivityBreakdown.ps1 -Username fhemmerrelias -Since '2026-03-01' -Until (Get-Date)
```

## Scripts

Scripts for collecting and calculating productivity metrics are stored in the `scripts/` directory.

| Script | Purpose |
|--------|---------|
| `Get-TodayProductivity.ps1` | Daily LOC and activity summary |
| `Get-UserOrgProductivity.ps1` | Compact per-user premium requests, commits, and total PR count for a date range |
| `Get-UserProductivityBreakdown.ps1` | Full per-user premium requests, commits, PR states, issue states, and workflow runs for a date range with table or JSON output |
| `Get-UserProductivityScores.ps1` | Multi-user universal productivity scoring using all numeric breakdown metrics with normalized weighted ranking |
| `Get-OrgProductivity.ps1` | Organization-wide repository productivity ranking and HTML report |

## Common Commands

```powershell
# Today
.\scripts\Get-TodayProductivity.ps1

# User summary
.\scripts\Get-UserOrgProductivity.ps1 -Username ssadhula-relias -Since '2026-02-01' -Until '2026-02-28' -Enterprise bertelsmann

# User breakdown
.\scripts\Get-UserProductivityBreakdown.ps1 -Username ssadhula-relias -Since '2026-03-01' -Until '2026-03-11'

# Month-to-date user breakdown
.\scripts\Get-UserProductivityBreakdown.ps1 -Username ssadhula-relias -Since '2026-03-01'

# Universal score for multiple users
.\scripts\Get-UserProductivityScores.ps1 -Usernames ssadhula-relias,fhemmerrelias -Since '2026-03-01' -Until '2026-03-31'

# Org report
.\scripts\Get-OrgProductivity.ps1 -Org relias-engineering
```
