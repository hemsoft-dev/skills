---
name: repo-summarizer
description: V1.1 - Analyzes GitHub repositories with configurable effort levels (Minimal, Normal, Maximum) to generate fun facts.
---

# Repository Summarizer

Analyze a GitHub repository and generate a fun facts report.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Effort Levels

| Level | Script | Scope |
|-------|--------|-------|
| **Minimal** | `scripts/Get-RepoSummary-Minimal.ps1` | Basic metadata + top 5 contributors |
| **Normal** | `scripts/Get-RepoSummary-Normal.ps1` | Full statistics, top 10 contributors, activity trends |
| **Maximum** | `scripts/Get-RepoSummary-Maximum.ps1` | Deep analysis with historical patterns, all contributors, detailed breakdowns |

## Instructions

1. Ask user for the **repository** (owner/repo format or URL)
2. Ask for **effort level** (default: Normal)
3. Run the appropriate PowerShell script to collect data as JSON
4. Format the JSON output into a markdown report

## Data Collection Scripts

Scripts location: `~/.claude/skills/repo-summarizer/scripts/`

```powershell
# Minimal - basic metadata + top 5 contributors
.\scripts\Get-RepoSummary-Minimal.ps1 -Owner "owner" -Repo "repo"

# Normal - includes issues, PRs, recent activity
.\scripts\Get-RepoSummary-Normal.ps1 -Owner "owner" -Repo "repo"

# Maximum - deep analysis with patterns and trends
.\scripts\Get-RepoSummary-Maximum.ps1 -Owner "owner" -Repo "repo"
```

All data is collected via GitHub CLI (`gh`) - no local clone required.

## Output Format

Format the JSON output into this markdown structure:

```markdown
# {repo-name} - Facts (Minimal) / Fun Facts (Normal/Maximum)

*Generated: {generatedAt} | Effort: {effortLevel}*

## Overview
- **Description**: {repository.description}
- **Age**: {repository.ageDays} days (first commit: {repository.firstCommitDate})
- **Stars**: {repository.stars} | **Forks**: {repository.forks}
- **Total Commits**: {repository.totalCommits}

## Top Contributors
| Rank | Contributor | Commits |
|------|-------------|---------|
| 1 | **{username}** | {contributions} |
...

## Statistics (Normal/Maximum only)
- **Issues**: {issues.open} open / {issues.closed} closed
- **PRs**: {pullRequests.merged} merged / {pullRequests.open} open

## Activity (Maximum only)
- Peak development: {peakDevelopment.month} ({peakDevelopment.commits} commits)
- Avg days to close issues: {issues.avgDaysToClose}
- Avg days to merge PRs: {pullRequests.avgDaysToMerge}
```

## Guidelines

- Run the script first, then format the JSON output
- Use exact numbers from the JSON, never approximate
- Include all sections relevant to the effort level
- Handle missing data gracefully (some repos have no issues/PRs)
- Use emojis throughout the report to make it more fun and engaging
