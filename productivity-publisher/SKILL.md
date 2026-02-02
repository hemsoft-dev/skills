---
name: productivity-publisher
description: V1.0 - Publishes monthly productivity HTML reports to participating repos under .relias-metrics with PR creation and .gitattributes configuration.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the productivity-publisher directory (path contains 'productivity-publisher'), verify that history logging occurred.
            
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
            Before stopping, if productivity-publisher was used (check if any files in productivity-publisher directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in productivity-publisher directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Productivity Publisher Skill

Publishes monthly productivity HTML reports to participating repositories' `.relias-metrics/` folders via pull requests.

## Purpose

Distributes pre-generated monthly productivity metrics to configured repositories for visibility and tracking, while excluding these reports from GitHub language statistics using `.gitattributes` configuration.

## Related Skills

- **[Productivity Skill](../productivity/SKILL.md)** - Generates the HTML reports that this skill publishes
- **[GitHub Skill](../github/SKILL.md)** - Account structure and authentication (uses `fhemmerrelias` for commits)

## How It Works

1. **User provides full path** to monthly HTML report file
2. **Parse repo information** from the file path
3. **Check participation** - Verify repo has `"publish": true` in productivity config
4. **Navigate to clone** - Use existing clones in `D:\github\temp\{org}/{repo}`
5. **Sync repo** - `git fetch` to get latest changes
6. **Create branch** - Format: `productivity-metrics-{YYYY-MM}`
7. **Copy HTML** - Place report in `.relias-metrics/` folder
8. **Configure .gitattributes** - Ensure reports excluded from language stats
9. **Commit** - Under `fhemmerrelias` identity
10. **Create PR** - Simple description, one PR per month per repo

## Configuration

Repos participate by having `"publish": true` in their productivity config:

```json
{
  "repo": "relias-engineering/some-repo",
  "publish": true
}
```

**Config location**: `productivity/repos/use-cases/*.json`

## Git Attributes

Reports are committed but excluded from GitHub statistics:

```
.relias-metrics/** linguist-generated=true
```

This ensures:

- ✅ Files are versioned and auditable
- ✅ Excluded from language statistics
- ✅ Excluded from contribution metrics
- ✅ Marked as "generated" in PRs

## Local Clone Policy

**Uses existing read-write clones** for publishing:

| Organization | Local Path |
|--------------|------------|
| HemSoft / fhemmer (personal) | `D:\github\temp\hemsoft` |
| relias-engineering (work) | `D:\github\temp\relias` |

**Publishing is the exception** - these clones are generally read-only (per productivity skill policy), but publishing requires write access to create PRs.

## PR Strategy

- **One PR per month per repo** - Clean, individual review
- **Simple description**: `Monthly productivity metrics for [Month Year]`
- **Code owners notified** - Configured per-repo via CODEOWNERS file
- **Branch naming**: `productivity-metrics-{YYYY-MM}` (e.g., `productivity-metrics-2026-01`)

## Invocation Examples

**Publish single report:**

```
User: "Publish this report: C:\Users\User\.claude\skills\productivity\reports\2026-01\relias-engineering\some-repo\2026-01-31_productivity.html"
```

**Publish all reports for a month:**

```
User: "Publish all January 2026 productivity reports to participating repos"
```

The skill will:

1. Scan `productivity/repos/use-cases/*.json` for repos with `"publish": true`
2. Find corresponding HTML reports in `productivity/reports/2026-01/`
3. Publish each to its respective repo

## Scripts

All publishing logic is in `scripts/Publish-ProductivityReport.ps1`.

## Error Handling

- **Clone doesn't exist**: Report error, suggest running productivity skill first to create clone
- **No publish flag**: Skip repo, log info message
- **PR already exists**: Check if branch exists, offer to update or create new PR
- **Git conflicts**: Abort publish, report conflict, suggest manual resolution
- **Missing .relias-metrics folder**: Create it automatically
- **Missing .gitattributes**: Create or append linguist rule automatically

## Future Enhancements

- Email notifications when PRs are created
- Automatic merge if CI passes and approvals received
- Dashboard view of published reports across all repos
- Quarterly/yearly rollup reports
