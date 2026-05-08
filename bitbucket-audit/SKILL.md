---
name: bitbucket-audit
description: "V1.1 - Commands: audit, report, compare, stale, subset. Expert in Bitbucket Cloud repository auditing using existing Bitbucket and GitHub credentials to assess migration status, archived state, and last-commit staleness across work repos."
compatibility: Requires PowerShell, gh CLI authentication, network access, and Bitbucket Cloud credentials via ATLASSIAN_EMAIL plus BITBUCKET_API_TOKEN or BITBUCKET_API_KEY.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the bitbucket-audit directory (path contains 'bitbucket-audit'), verify that history logging occurred.
            
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
            Before stopping, if bitbucket-audit was used (check if any files in bitbucket-audit directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in bitbucket-audit directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Bitbucket Audit

Use this skill when you need to inventory Bitbucket Cloud repositories, compare them with GitHub, or identify stale repos by last commit age.

## Defaults

- Bitbucket workspace: `relias`
- GitHub owner: `relias-engineering`
- Bitbucket credentials: `ATLASSIAN_EMAIL` + `BITBUCKET_API_TOKEN` (fallback `BITBUCKET_API_KEY`)
- Optional Bitbucket identity fallback: `BITBUCKET_USERNAME`
- GitHub access: authenticated `gh` CLI session
- Script path: `C:\Users\User\.agents\skills\bitbucket-audit\scripts\Invoke-BitbucketMigrationAudit.ps1`
- Exact report export: `C:\Users\User\.agents\skills\bitbucket-audit\scripts\Export-BitbucketAuditReport.ps1`

## Commands

### audit

Run the full Bitbucket + GitHub audit and return PowerShell objects:

```powershell
& 'C:\Users\User\.agents\skills\bitbucket-audit\scripts\Invoke-BitbucketMigrationAudit.ps1'
```

### report

Reproduce the exact CSV layout used for the completed full audit:

```powershell
& 'C:\Users\User\.agents\skills\bitbucket-audit\scripts\Export-BitbucketAuditReport.ps1' -OutputPath 'C:\temp\bitbucket-audit-report.csv' -OpenInExcel
```

### compare

Show migration-focused columns:

```powershell
& 'C:\Users\User\.agents\skills\bitbucket-audit\scripts\Invoke-BitbucketMigrationAudit.ps1' |
  Select-Object BitbucketRepo, BitbucketArchived, GitHubRepoFound, GitHubArchived, GitHubUrl, MigrationStatus
```

### stale

Sort by oldest Bitbucket default-branch commit:

```powershell
& 'C:\Users\User\.agents\skills\bitbucket-audit\scripts\Invoke-BitbucketMigrationAudit.ps1' |
  Sort-Object BitbucketLastCommitAgeDays -Descending |
  Select-Object BitbucketRepo, BitbucketProject, BitbucketArchived, BitbucketLastCommitAt, BitbucketLastCommitAgeDays, BitbucketStaleness
```

### subset

Audit only matching repos or a smaller batch:

```powershell
& 'C:\Users\User\.agents\skills\bitbucket-audit\scripts\Invoke-BitbucketMigrationAudit.ps1' -RepoPattern 'assessment*','identity*'
```

Use `-MaxRepos` when you want a quick sample or staged audit:

```powershell
& 'C:\Users\User\.agents\skills\bitbucket-audit\scripts\Invoke-BitbucketMigrationAudit.ps1' -MaxRepos 25
```

## Key fields

- `BitbucketRepo`
- `BitbucketProject`
- `BitbucketArchived`
- `BitbucketDefaultBranch`
- `BitbucketCommitLookupStatus`
- `BitbucketCommitLookupError`
- `BitbucketLastCommitAt`
- `BitbucketLastCommitAgeDays`
- `BitbucketStaleness`
- `GitHubRepoFound`
- `GitHubArchived`
- `GitHubPushedAt`
- `GitHubLastPushAgeDays`
- `MigrationStatus`

## Heuristics

- `GitHubRepoFound` means a repo with the same name exists in the GitHub owner.
- `Likely migrated` means the same-name GitHub repo exists and the Bitbucket repo is archived.
- `GitHub match found` means the same-name GitHub repo exists but Bitbucket is not archived.
- `Archived in Bitbucket only` means Bitbucket is archived but no same-name GitHub repo was found.
- `Bitbucket only` means no same-name GitHub repo was found.
- `BitbucketLastCommitAgeDays` comes from the latest commit on the Bitbucket default branch when available, otherwise the latest commit returned by the repo commits endpoint.
- `BitbucketCommitLookupStatus` distinguishes normal commit lookups from empty repos and transient API issues.

## Output

Use `-OutputPath` with `.csv` or `.json` to export the report.

The `report` wrapper freezes this CSV column order:

1. `BitbucketRepo`
2. `BitbucketName`
3. `BitbucketProject`
4. `BitbucketArchived`
5. `BitbucketDefaultBranch`
6. `BitbucketCommitLookupStatus`
7. `BitbucketCommitLookupError`
8. `BitbucketLastCommitAt`
9. `BitbucketLastCommitAgeDays`
10. `BitbucketStaleness`
11. `BitbucketUpdatedOn`
12. `BitbucketUrl`
13. `GitHubRepoFound`
14. `GitHubRepo`
15. `GitHubArchived`
16. `GitHubDefaultBranch`
17. `GitHubPushedAt`
18. `GitHubLastPushAgeDays`
19. `GitHubUrl`
20. `MigrationStatus`

## Notes

- Never print or persist token values.
- Use Bitbucket Cloud REST at `https://api.bitbucket.org/2.0`.
- Prefer Bitbucket API tokens over legacy app passwords.
- Commit lookup retries transient Bitbucket API failures and records repo-level lookup errors instead of aborting the full export.
- For exact migration proof beyond same-name matching, inspect the Bitbucket README or description for a moved-to-GitHub notice.
