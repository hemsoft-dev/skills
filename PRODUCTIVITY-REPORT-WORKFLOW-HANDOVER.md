# Productivity Report — GitHub Actions Workflow Handover

This document provides everything needed to convert the 3-phase PowerShell productivity pipeline
into a scheduled GitHub Actions workflow in the **work-metrics** repository.

## Table of Contents

- [Overview](#overview)
- [Source Material](#source-material)
- [Data Architecture](#data-architecture)
- [Scoring Algorithm](#scoring-algorithm)
- [API Rate Limiting Strategy](#api-rate-limiting-strategy)
- [Recommended Workflow Architecture](#recommended-workflow-architecture)
- [Workflow Job Breakdown](#workflow-job-breakdown)
- [Secrets and Permissions Required](#secrets-and-permissions-required)
- [Artifact and Caching Strategy](#artifact-and-caching-strategy)
- [Resilience Patterns](#resilience-patterns)
- [Output and Publishing](#output-and-publishing)
- [Schedule Recommendations](#schedule-recommendations)
- [Migration Checklist](#migration-checklist)

## Overview

The pipeline collects org-wide developer productivity metrics for the `relias-engineering` GitHub
organization (~408 members, ~213 active repos) and produces a sortable, dark-themed HTML report
with composite scoring, tooltips, and summary stat cards.

### The 3 Phases

| Phase | Script | Purpose | API Calls | Time |
| --- | --- | --- | --- | --- |
| 1 | `1-Get-AllUserProductivityMetrics.ps1` | Repo-centric activity collection (commits, PRs, issues, reviews, workflow runs) | ~2000–4000 | 30–60 min |
| 2 | `2-Get-AllUserPremiumRequestConsumption.ps1` | Per-user Copilot premium request totals from enterprise billing API | ~5000–6000 (user × days) | 20–40 min |
| 3 | `3-Build-AllUserProductivityReport.ps1` | Builds HTML report from JSON — ZERO API calls | 0 | < 5 sec |

Combined, Phases 1 + 2 consume roughly 7000–10000 API calls per full run. The GitHub REST API
core rate limit is **5,000 requests per hour per token**. This is the central constraint.

## Source Material

The reference implementation lives in:

```text
~/.agents/skills/productivity/scripts/
├── 1-Get-AllUserProductivityMetrics.ps1       # Phase 1 (~740 lines)
├── 2-Get-AllUserPremiumRequestConsumption.ps1  # Phase 2 (~310 lines)
├── 3-Build-AllUserProductivityReport.ps1       # Phase 3 (~850 lines)
└── Get-UserProductivityScores.ps1              # Standalone scoring (superseded by Phase 3)
```

All scripts use PowerShell 7.0+ and GitHub CLI (`gh`) for API calls. They should be adapted,
not copy-pasted — the workflow needs idiomatic GitHub Actions patterns.

## Data Architecture

### JSON Schema (Phase 1 output, Phase 2 enrichment)

```json
{
  "Organization": "relias-engineering",
  "Collector": "RepoCentric",
  "PremiumRequestsIncluded": true,
  "StartDate": "2026-03-01 00:00",
  "EndDate": "2026-03-14 16:22",
  "GeneratedAt": "2026-03-14 16:22:45",
  "IsFullRun": true,
  "UserCount": 408,
  "RepositoryCount": 213,
  "Users": [
    {
      "Username": "jdoe-relias",
      "FullName": "Jane Doe",
      "Email": "",
      "ProfileUrl": "https://github.com/jdoe-relias",
      "StartDate": "2026-03-01",
      "EndDate": "2026-03-14 16:22",
      "PremiumRequests": 245.5,
      "Commits": 12,
      "LinesAdded": 340,
      "LinesDeleted": 120,
      "NetLOC": 220,
      "TotalLinesChanged": 460,
      "OpenPRs": 1,
      "MergedPRs": 5,
      "ClosedPRs": 0,
      "ApprovedReviews": 8,
      "CommentReviews": 3,
      "OpenIssues": 0,
      "ClosedIssues": 2,
      "WorkflowRuns": 15
    }
  ],
  "Failures": [],
  "TotalApiCalls": 3421
}
```

### 14 Tracked Metrics Per User

| Metric | Source API | Notes |
| --- | --- | --- |
| Commits | `GET /repos/{org}/{repo}/commits` | Per-commit detail fetched for LOC stats |
| LinesAdded | `GET /repos/{org}/{repo}/commits/{sha}` | Sum of `file.additions` |
| LinesDeleted | Same as above | Sum of `file.deletions` |
| NetLOC | Computed | `LinesAdded - LinesDeleted` |
| TotalLinesChanged | Computed | `LinesAdded + LinesDeleted` |
| OpenPRs | `GET /repos/{org}/{repo}/pulls?state=all` | Created in window, still open |
| MergedPRs | Same endpoint | Has `merged_at` timestamp |
| ClosedPRs | Same endpoint | State `closed`, no `merged_at` |
| ApprovedReviews | `GET /repos/{org}/{repo}/pulls/{number}/reviews` | State `APPROVED` |
| CommentReviews | Same endpoint | State `COMMENTED` |
| OpenIssues | `GET /repos/{org}/{repo}/issues?state=all` | Excludes PRs (has `pull_request` key) |
| ClosedIssues | Same endpoint | State `closed` |
| WorkflowRuns | `GET /repos/{org}/{repo}/actions/runs` | `created` date qualifier |
| PremiumRequests | `GET /enterprises/{ent}/settings/billing/premium_request/usage` | Per-user, per-day, enterprise `bertelsmann` |

## Scoring Algorithm

### Methodology

1. **Log-transform** each raw metric: `ln(1 + x)` (handles zeros, reduces outlier impact,
   negative NetLOC uses `-ln(1 + |x|)`)
2. **Percentile rank** each transformed metric across all users (0–100 scale, ties averaged)
3. **Weighted sum** of percentiles produces composite score (0–100)

### Current Weights (sum = 1.00)

| Metric | Weight | Category |
| --- | --- | --- |
| Commits | 0.13 | Code Output |
| MergedPRs | 0.10 | Code Output |
| LinesAdded | 0.08 | Code Output |
| LinesDeleted | 0.08 | Code Output |
| NetLOC | 0.08 | Code Output |
| TotalLinesChanged | 0.08 | Code Output |
| OpenPRs | 0.07 | Code Output |
| ClosedPRs | 0.07 | Code Output |
| ApprovedReviews | 0.07 | Collaboration |
| ClosedIssues | 0.06 | Collaboration |
| CommentReviews | 0.05 | Collaboration |
| OpenIssues | 0.05 | Collaboration |
| WorkflowRuns | 0.05 | CI/CD |
| PremiumRequests | 0.03 | AI Usage |

### Score Color Thresholds

| Range | Color | Label |
| --- | --- | --- |
| >= 70 | Green (`#00ff88`) | High activity |
| 35–70 | Cyan (`#00d4ff`) | Moderate |
| < 35 | Muted gray | Low |

### When Premium Data Is Unavailable

If Phase 2 is skipped or fails, the 3% PremiumRequests weight is redistributed evenly across
the remaining 13 metrics. The scoring still works — it's gracefully degraded.

## API Rate Limiting Strategy

### Core Constraints

| Limit | Budget | Reset Cadence |
| --- | --- | --- |
| REST Core | 5,000/hour | Rolling 1-hour window |
| REST Search | 30/hour | Rolling 1-hour window |
| GraphQL | 5,000 points/hour | Rolling 1-hour window |

### Current Throttling Patterns (preserve these)

1. **5-second inter-repo sleep** — After each repository is processed in Phase 1, the script
   sleeps 5 seconds before starting the next. This spreads ~213 repos over ~18 minutes of
   deliberate pacing, preventing burst exhaustion.

2. **GraphQL batch user identity lookup** — Instead of 408 individual REST calls, users are
   resolved in batches of 50 via a single GraphQL query with aliased fields (`u0: user(login:...)`,
   `u1: user(login:...)`, etc.). Reduces 408 calls to ~9.

3. **Merged PR + Review single-pass** — PRs are fetched once per repo (`state=all`,
   `sort=updated`, `direction=desc`), then both PR metrics and review metrics are derived from
   the same list. Reviews are fetched per-PR, but only for PRs updated within the date range.

4. **Phase 2 day-level cache** — Premium requests are queried per-user-per-day. A cache JSON
   tracks which (user, day) pairs have been collected. On subsequent runs, only uncached days
   are fetched. On a 14-day window this can eliminate up to 90% of calls on re-runs.

5. **Dynamic rate limit wait** — Phase 2 calls `GET /rate_limit` before each user and sleeps if
   remaining calls drop below threshold (5). Calculates exact seconds until reset + 5s buffer.

### Recommended Workflow Rate Strategy

**Use two separate GitHub tokens** with staggered execution to double the effective budget:

- **Token A** → Phase 1 (repo activity)
- **Token B** → Phase 2 (enterprise billing)

These are independent API scopes and independent rate limit pools. Running them sequentially
(not in parallel) with separate tokens gives 10,000 calls/hour total.

If only one token is available, Phase 1 must complete before Phase 2 starts, and the total
execution window must span at least 2 hours to stay under limits.

## Recommended Workflow Architecture

### Single YAML, Three Jobs

```yaml
name: Monthly Productivity Report

on:
  schedule:
    - cron: '0 6 1 * *'    # 1st of each month at 6 AM UTC
  workflow_dispatch:         # Manual trigger for ad-hoc runs
    inputs:
      since:
        description: 'Start date (YYYY-MM-DD), defaults to first of previous month'
        required: false
      force:
        description: 'Force re-collection even if cache exists'
        type: boolean
        default: false
```

### Why Three Jobs (Not Three Workflows)

| Consideration | Three Jobs in One Workflow | Three Separate Workflows |
| --- | --- | --- |
| Artifact passing | Native (upload/download-artifact) | Requires external storage or dispatch |
| Failure visibility | Single workflow run shows all phases | Must correlate across runs |
| Sequential ordering | `needs:` dependency chain | `workflow_run` triggers — fragile |
| Rate limit isolation | Each job can use a different token | Same, but harder to coordinate |
| Retry granularity | Can re-run failed job only | Can re-run failed workflow only |

**Recommendation: Single workflow, three jobs with `needs:` chain.**

## Workflow Job Breakdown

### Job 1: `collect-metrics` (Phase 1)

```yaml
collect-metrics:
  runs-on: ubuntu-latest
  timeout-minutes: 90
  steps:
    - uses: actions/checkout@v4
    - name: Install PowerShell modules
      shell: pwsh
      run: # Install any needed modules
    - name: Collect org-wide metrics
      shell: pwsh
      env:
        GH_TOKEN: ${{ secrets.METRICS_TOKEN_A }}
      run: |
        ./scripts/1-Get-AllUserProductivityMetrics.ps1 `
          -Since "${{ inputs.since || '' }}" `
          -Force:$${{ inputs.force || false }}
    - uses: actions/upload-artifact@v4
      with:
        name: productivity-json
        path: scripts/relias-engineering-user-productivity.json
        retention-days: 30
```

**Key implementation notes:**

- Walk repos sequentially with 5-second sleep between each
- Use GraphQL batch for user identity resolution (50 per query)
- Fetch PRs once per repo, derive both PR metrics and review metrics from same list
- Each commit gets a detail call for LOC — this is the biggest API cost
- Track `$ApiCallCount` and log it for observability
- The script handles pagination internally (100 per page)

### Job 2: `enrich-premium` (Phase 2)

```yaml
enrich-premium:
  needs: collect-metrics
  runs-on: ubuntu-latest
  timeout-minutes: 60
  steps:
    - uses: actions/checkout@v4
    - uses: actions/download-artifact@v4
      with:
        name: productivity-json
        path: scripts/
    - name: Restore premium cache
      uses: actions/cache@v4
      with:
        path: scripts/relias-engineering-premium-requests-cache.json
        key: premium-cache-${{ github.run_id }}
        restore-keys: premium-cache-
    - name: Enrich with premium requests
      shell: pwsh
      env:
        GH_TOKEN: ${{ secrets.METRICS_TOKEN_B }}
      run: |
        ./scripts/2-Get-AllUserPremiumRequestConsumption.ps1 `
          -Force:$${{ inputs.force || false }}
    - uses: actions/upload-artifact@v4
      with:
        name: productivity-json-enriched
        path: scripts/relias-engineering-user-productivity.json
        retention-days: 30
    - name: Save premium cache
      uses: actions/cache/save@v4
      with:
        path: scripts/relias-engineering-premium-requests-cache.json
        key: premium-cache-${{ github.run_id }}
```

**Key implementation notes:**

- Enterprise billing endpoint: `GET /enterprises/bertelsmann/settings/billing/premium_request/usage`
- Query params: `year`, `month`, `day`, `user`, `product=Copilot`
- One API call per (user, day) pair — cache eliminates already-fetched days
- Dynamic rate limit check before each user — sleeps until reset if budget < 5
- Cache saves every 10 users for crash resilience
- Updates the Phase 1 JSON in-place with `PremiumRequests` values

### Job 3: `build-report` (Phase 3)

```yaml
build-report:
  needs: enrich-premium
  runs-on: ubuntu-latest
  timeout-minutes: 5
  steps:
    - uses: actions/checkout@v4
    - uses: actions/download-artifact@v4
      with:
        name: productivity-json-enriched
        path: scripts/
    - name: Build HTML report
      shell: pwsh
      run: |
        ./scripts/3-Build-AllUserProductivityReport.ps1 -Force
    - uses: actions/upload-artifact@v4
      with:
        name: productivity-report
        path: scripts/relias-engineering-user-productivity.html
        retention-days: 90
```

**Key implementation notes:**

- Zero API calls — pure JSON-to-HTML transformation
- Computes scoring (log-transform → percentile → weighted sum)
- Generates self-contained HTML with inline CSS and JS (no external dependencies)
- Sortable table columns (click headers), dark theme, stat cards with tooltips
- Reports on: Commits, LOC, PRs, Reviews, Issues, Workflow Runs, Premium Requests, Score

## Secrets and Permissions Required

| Secret | Purpose | Scopes Needed |
| --- | --- | --- |
| `METRICS_TOKEN_A` | Phase 1 — org repo data | `repo`, `read:org` |
| `METRICS_TOKEN_B` | Phase 2 — enterprise billing | `read:enterprise`, `repo` |

If using a single token, it needs all scopes: `repo`, `read:org`, `read:enterprise`.

The token(s) must belong to a user who is:

- A member of the `relias-engineering` organization
- Has enterprise billing read access for `bertelsmann`

### GitHub CLI Authentication in Actions

The scripts use `gh api` (not raw `curl`). GitHub CLI reads `GH_TOKEN` automatically:

```yaml
env:
  GH_TOKEN: ${{ secrets.METRICS_TOKEN_A }}
```

No `gh auth login` step is needed when `GH_TOKEN` is set.

## Artifact and Caching Strategy

### Artifacts (ephemeral, per-run)

| Artifact | Produced By | Consumed By | Retention |
| --- | --- | --- | --- |
| `productivity-json` | Job 1 | Job 2 | 30 days |
| `productivity-json-enriched` | Job 2 | Job 3 | 30 days |
| `productivity-report` | Job 3 | Download / publish | 90 days |

### Caches (persistent across runs)

| Cache Key | Content | Purpose |
| --- | --- | --- |
| `premium-cache-*` | `relias-engineering-premium-requests-cache.json` | Skip already-fetched (user, day) pairs |

The premium cache is the single most impactful optimization. On a 14-day month-to-date run,
a re-run the next day only needs to fetch 1 new day per user instead of 14.

## Resilience Patterns

### Failure Modes and Mitigations

| Failure | Impact | Mitigation |
| --- | --- | --- |
| Rate limit exhaustion | Job hangs or errors | Dynamic wait with `/rate_limit` check; 5s inter-repo sleep |
| Single repo API failure | Missing data for that repo | `AllowFailure` pattern — log and continue, track in `Failures[]` |
| GraphQL batch failure | User identity missing | Automatic fallback to individual REST calls |
| Enterprise billing API down | No premium data | Phase 3 gracefully degrades — redistributes weight |
| Job timeout | Partial data | Increase `timeout-minutes`; consider splitting into repo batches |
| Cache corruption | Re-fetches all days | `SkipCache` parameter available; cache is additive-only |

### The `AllowFailure` Pattern

Every API call wrapper accepts `-AllowFailure`. When set, HTTP errors return `$null` instead of
throwing. The caller checks for `$null` and skips that item, logging it to the `Failures` array.
This means one broken repo or commit never crashes the entire run.

### Crash-Resilient Cache Saves

Phase 2 saves the premium cache to disk every 10 users. If the job crashes at user 250,
the next run picks up from user 241 (effectively) because those 240 users' days are cached.

## Output and Publishing

### HTML Report Features

- **Self-contained** — Single `.html` file with all CSS/JS inline
- **Sortable table** — Click any column header to sort ascending/descending
- **Stat cards** — Summary metrics with tooltips explaining each
- **Score column** — Composite productivity score (0–100) with color coding
- **Column tooltips** — Rich explanations for every metric via hoverable headers
- **Dark theme** — Designed for readability
- **Responsive** — Works on desktop and tablet

### Publishing Options

1. **GitHub Pages** — Commit the HTML to a `gh-pages` branch or publish artifact
2. **Artifact download** — Available in the Actions run for 90 days
3. **PR to target repo** — Create a PR with the HTML to a documentation repo
4. **Slack notification** — Post a summary + download link after successful run

## Schedule Recommendations

| Schedule | Cron | Use Case |
| --- | --- | --- |
| Monthly (1st) | `0 6 1 * *` | Full previous-month report |
| Weekly (Monday) | `0 6 * * 1` | Week-over-week tracking |
| On-demand | `workflow_dispatch` | Ad-hoc investigations |

For the monthly run, set `Since` to the first of the previous month and `Until` to the last
day of the previous month. For week-over-week, use a 7-day rolling window.

## Migration Checklist

### Phase 1: Setup

- [ ] Create `work-metrics` repository (or use existing)
- [ ] Copy and adapt the three PowerShell scripts from `~/.agents/skills/productivity/scripts/`
- [ ] Create the workflow YAML file (`.github/workflows/productivity-report.yml`)
- [ ] Configure repository secrets (`METRICS_TOKEN_A`, `METRICS_TOKEN_B`)
- [ ] Validate with a small test run (`-UserLimit 10 -RepoLimit 5`)

### Phase 2: Validate

- [ ] Run workflow manually with `workflow_dispatch`
- [ ] Verify JSON output schema matches the documented structure
- [ ] Verify HTML report renders correctly
- [ ] Check API call count stays within rate limits
- [ ] Confirm premium cache is being created and restored across runs

### Phase 3: Go Live

- [ ] Enable the cron schedule
- [ ] Set up notification (Slack, email, or PR) for report delivery
- [ ] Monitor first automated run end-to-end
- [ ] Archive the skills-repo scripts (they're now superseded)

### Adaptation Notes

When porting the scripts, keep these PowerShell patterns:

- `$ErrorActionPreference = 'Stop'` — fail-fast on unhandled errors
- `& gh api ...` with stderr capture to temp file — this is how `gh` errors are caught
- `ConvertFrom-Json` / `ConvertTo-Json -Depth 8` — JSON round-tripping
- All date math uses UTC internally, display uses local time
- The `New-UserMetricRecord` function defines the per-user schema — keep it as the single
  source of truth for the JSON structure
