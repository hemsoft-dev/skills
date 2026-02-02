---
name: productivity
description: V1.0 - Tracks personal productivity metrics including daily lines of code, commits, pull requests, code reviews, and issues closed. Queries both GitHub API and local git repositories with comprehensive reporting and trend analysis.
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

## Scripts

Scripts for collecting and calculating productivity metrics are stored in the `scripts/` directory.

## Common Commands

(Add examples as the skill is developed)
