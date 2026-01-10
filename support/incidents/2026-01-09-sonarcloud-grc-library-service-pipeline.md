# SonarCloud Project grc-library-service Pipeline Issue

## Metadata

| Field | Value |
|-------|-------|
| **Date/Time** | 2026-01-09 ~16:17 EST |
| **Reported By** | Drazen Jovanovic |
| **Status** | Investigating |

## Links

- [Slack Thread](https://relias-engineering.slack.com/archives/C06F7RT6U6L/p1767994015054559)
- [SonarCloud Project](https://sonarcloud.io/project/overview?id=relias-engineering_grc-library-service)
- [GitHub Repo](https://github.com/relias-engineering/grc-library-service)

## Issue Description

SonarCloud scanner fails during Azure DevOps pipeline execution with error:

```
##[error]ERROR: Error during SonarScanner execution
ERROR: Could not find a default branch for project with key 'relias-engineering_grc-library-service'. Make sure project exists.
ERROR:
ERROR: Error during SonarScanner execution
ERROR: Could not find a default branch for project with key 'relias-engineering_grc-library-service'. Make sure project exists.
ERROR:
##[error]The SonarScanner did not complete successfully
The SonarScanner did not complete successfully
##[error]21:17:19.418  Post-processing failed. Exit code: 1
```

## Troubleshooting Notes

### Initial Investigation

1. **Verified SonarCloud project exists**: Navigated to SonarCloud and confirmed project `relias-engineering_grc-library-service` exists in the `Relias-GitHub` organization.

2. **Checked Background Tasks**: Found only ONE successful analysis:
   - Date: January 8, 2026 - 3:14:40 PM
   - Submitted By: Anonymous
   - Status: Success
   - Duration: 3.30s

3. **Quality Gate Status**: Showed "Not computed" - this is the root cause indicator.

### Pipeline Run Analysis

Reviewed GRC Library Service related pipelines:

| Pipeline | ID | Purpose |
|----------|-----|---------|
| GRC Library Service PR | 646 | PR validation |
| GRC Library Service Deploy | 644 | Deployment |
| GRC Library Service Infra PR | - | Infrastructure |
| GRC Library Service Gitops PR | - | GitOps |

Recent runs on Pipeline 646 (GRC Library Service PR):

- Run 80235 (main): Failed - code formatting issue
- Run 80232 (PR #2): Canceled
- Run 80229 (PR #2): Failed - code formatting issue
- Run 80227 (PR #2): Failed - code formatting issue

Note: Some runs failed on "Verify Code Formatting" step before reaching SonarCloud.

### Root Cause Identified

**SonarCloud requires TWO analyses on the main branch to compute a Quality Gate baseline.**

The project was scaffolded by Cortex and only had one initial analysis. When feature branches or PRs attempt to analyze, SonarCloud cannot find a "default branch" because:

1. The main branch has been analyzed once
2. But Quality Gate is "Not computed" (needs second analysis)
3. Feature/PR branches fail because they can't compare against a baseline

This same pattern was observed on another Cortex-scaffolded project (`relias-engineering_authorization`).

### Similar Affected Projects

| Project | First Analysis | Quality Gate |
|---------|---------------|--------------|
| `relias-engineering_grc-library-service` | Jan 8, 3:14 PM | Not computed |
| `relias-engineering_authorization` | Jan 9, 12:04 PM | Not computed |

## Resolution

**Pending** - Requires re-running the pipeline on `main` branch to establish Quality Gate baseline.

Proposed fix:

```powershell
az pipelines run --id 646 --branch main --organization https://dev.azure.com/ReliasEngineering --project PlatformDevelopment
```

**Note**: The `main` branch currently has code formatting issues that need to be fixed first, otherwise the pipeline will fail before reaching SonarCloud analysis.

## Lessons Learned

1. **Cortex scaffolded projects need a second main branch pipeline run** after initial creation to establish SonarCloud Quality Gate baseline.

2. **Error message is misleading**: "Could not find a default branch" suggests the project doesn't exist, but the actual issue is that Quality Gate hasn't been computed yet.

3. **Check Background Tasks in SonarCloud**: The number of successful analyses and Quality Gate status are key diagnostic indicators.

4. **Azure DevOps timestamps are UTC**: When correlating pipeline run times with local screenshots, remember to convert (UTC = EST + 5 hours).

5. **Multiple pipelines per repo**: GRC Library Service has 4 different pipelines (PR, Deploy, Infra PR, Gitops PR) - ensure you're investigating the correct one.
