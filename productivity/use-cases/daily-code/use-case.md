# Daily Code - Productivity Metrics Use Case

## Overview

The Daily Code use case tracks personal productivity metrics centered around GitHub commits and code contributions. It measures the volume and quality of coding work performed in a single day by aggregating commit data from multiple repositories.

## Primary Metric: Lines of Code (LOC)

Calculate the total lines of code committed in a single calendar day:

- **Calculation**: Net changes (additions minus deletions)
- **Scope**: Code files only
  - Included: `.js`, `.ts`, `.py`, `.cs`, `.ps1`, `.go`, `.rs`, `.java`, etc.
  - Excluded: Build artifacts, node_modules, generated code, documentation, images, config files
- **Time Window**: Single calendar day (00:00 - 23:59, local timezone)

## Data Collection

Data is collected using the **GitHub CLI** (`gh`) to query commit information across all repositories.

### Collection Script

The data collection process is automated by:

- **Script**: `scripts/collect-github-commits.ps1`
- **Purpose**: Query GitHub repositories for daily commit data using GitHub CLI
- **Output**: Raw commit metrics stored in `data/` directory
- **Cache**: 24-hour retention of collected data

### Data Sources

1. **GitHub API via CLI** - Primary source for all repositories accessible via GitHub CLI
2. **Local Git Repositories** - Secondary source for metrics validation and historical tracking

## Supported Metrics

Daily reports include:

- Total net lines of code committed
- Number of commits made
- Pull requests opened/merged
- Code reviews submitted
- Issues closed
- List of repositories touched
- File types modified
- Top modified files

## Configuration

Repository and filtering configuration is stored in:

- **File**: `config/daily-code-config.json`
- **Content**: List of repositories to track, file type filters, exclusion patterns

## Output

Generated reports are stored in:

- **Location**: `output/` directory
- **Format**: Markdown report with daily summary
- **Filename**: `daily-report-{YYYY-MM-DD}.md`

## Data Retention

- **Raw Data** (`data/`): 24-hour cache, auto-refreshed on query
- **Reports** (`output/`): Indefinite retention for historical analysis
