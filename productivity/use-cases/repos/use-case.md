# Repos - Repository Commit Tracking

## Overview

The Repos use case tracks all commits from specific monitored GitHub repositories, regardless of author. Unlike the Daily Code use case which focuses on personal productivity metrics, this use case provides a complete view of repository activity for team visibility and collaboration awareness.

## Related Skills

- **[GitHub Skill](../../../github/SKILL.md)** - Account structure, organizations, authentication
  - Work repos (`relias-engineering`) require `fhemmerrelias` account
  - Personal repos (`HemSoft`, `fhemmer`) require `HemSoft` account
  - Script automatically switches accounts based on repo config

## Data Structure

Data is organized by repository for clean per-repo statistics:

```
data/
├── relias-assistant/
│   ├── commits-2026-01-30.json
│   ├── commits-2026-01-31.json
│   └── commits-2026-02-01.json
├── another-repo/
│   └── commits-2026-01-30.json
└── ...
```

## Purpose

- Track all commit activity in monitored repositories
- Understand team contribution patterns
- Monitor repository health and activity levels
- Support code review and collaboration workflows

## Data Collection

Data is collected using the **GitHub CLI** (`gh`) to query commit, pull request, and issue information from remote repositories.

### Collection Method

Unlike the daily-code use case which scans local repositories, this use case:

1. Uses GitHub API via `gh` CLI to fetch remote commit data
2. Includes ALL commits (not filtered by author)
3. Supports repositories you may not have cloned locally
4. Tracks both organization and personal repositories
5. Collects pull request and issue activity for comprehensive tracking

### Collection Scripts

- **Script**: `scripts/collect-repo-commits.ps1`
- **Purpose**: Query monitored GitHub repositories for commit data
- **Output**: Raw commit data stored in `data/<repo-name>/commits-YYYY-MM-DD.json`

- **Script**: `scripts/collect-repo-issues-prs.ps1`
- **Purpose**: Query monitored GitHub repositories for issues and pull requests
- **Output**: Issues/PR data stored in `data/<repo-name>/issues-prs-YYYY-MM-DD.json`

## Configuration

Repository configuration is stored in:

- **File**: `config/repo-config.json`
- **Content**: List of monitored repositories with metadata

### Configuration Schema

```json
{
  "metadata": {
    "description": "Repositories monitored for commit activity",
    "lastUpdated": "ISO timestamp"
  },
  "repositories": [
    {
      "name": "repo-name",
      "owner": "github-org-or-user",
      "url": "https://github.com/owner/repo",
      "source": "work|personal|community",
      "description": "Optional description",
      "enabled": true
    }
  ]
}
```

### Repository Sources

- **work** - Work/organization repositories (e.g., relias-engineering)
- **personal** - Personal or HemSoft repositories
- **community** - Open source or community projects being monitored

## Metrics Collected

### Commit Data (per commit)

- Commit SHA (short and full)
- Author name and email
- Commit timestamp
- Commit message/subject
- Files changed count
- Additions and deletions
- Pull request association (if applicable)

### Pull Request Data

- PR number and title
- Author
- State (open/closed/merged)
- Action type (opened/merged/closed)
- Action date
- Additions, deletions, changed files
- URL

### Issue Data

- Issue number and title
- Author
- State (open/closed)
- Action type (opened/closed)
- Action date
- Labels
- URL

## Output

Generated data is stored in:

- **Location**: `data/<repo-name>/` directory (per-repo subfolders)
- **Format**: JSON files
- **Filename Pattern**: `commits-YYYY-MM-DD.json`

## Data Retention

- **Raw Data** (`data/`): Retained for historical analysis
- **Reports** (`output/`): Generated on demand

## Reports & Analytics

### Repository Analytics Dashboard

Generate visual analytics for any repository with contributor breakdowns:

- **Script**: `scripts/generate-repo-report.ps1`
- **Output**: `output/<repo-name>/repo-analytics.html` (interactive dashboard)
- **Output**: `output/<repo-name>/repo-analytics.txt` (text report)

### Dashboard Features

- **Summary Metrics**: Total commits, net LOC, contributors, active days, additions/deletions, pull requests, issues
- **Time Series Charts**: Daily LOC trend, daily commits, additions vs deletions, daily contributors, PR activity, issue activity
- **Contributor Analysis**: Table with per-contributor stats, commit distribution pie chart
- **Key Insights**: Most active day, top contributor, code velocity, activity rate, code churn ratio, PR/issue summaries
- **SVG Icons**: Modern iconography for all metrics and sections

## Common Commands

### Data Collection

```powershell
# Collect commits for all monitored repos (last 7 days)
.\scripts\collect-repo-commits.ps1

# Collect commits for a specific date range
.\scripts\collect-repo-commits.ps1 -StartDate "2026-01-25" -EndDate "2026-02-01"

# Collect commits for a specific repository
.\scripts\collect-repo-commits.ps1 -RepoName "relias-assistant"

# Collect entire month for a repo (one day at a time)
1..31 | % { $d = "2026-01-{0:D2}" -f $_; .\scripts\collect-repo-commits.ps1 -StartDate $d -EndDate $d -RepoName "relias-assistant" }

# Collect issues and PRs for all monitored repos (last 7 days)
.\scripts\collect-repo-issues-prs.ps1

# Collect issues and PRs for a specific date range
.\scripts\collect-repo-issues-prs.ps1 -StartDate "2026-01-01" -EndDate "2026-01-31"

# Collect issues and PRs for a specific repository
.\scripts\collect-repo-issues-prs.ps1 -RepoName "relias-assistant"
```

### Report Generation

```powershell
# Generate report for a repository (all available data)
.\scripts\generate-repo-report.ps1 -RepoName "relias-assistant"

# Generate report for a specific date range
.\scripts\generate-repo-report.ps1 -RepoName "relias-assistant" -StartDate "2026-01-01" -EndDate "2026-01-31"

# Generate report for last N days
.\scripts\generate-repo-report.ps1 -RepoName "relias-assistant" -Days 30
```
