---
name: copilot-pr-processor
description: V1.5 - Process an existing GitHub pull request through GitHub Copilot PR Reviewer and, when installed, the SFL full-spectrum reviewer until both current-head reviews have zero findings and all review threads are explicitly resolved. Requests Copilot through the API and SFL through workflow dispatch, with legacy label fallback. Use for exhaustive PR readiness loops that include Critical, High, Medium, and Low findings.
disable-model-invocation: true
---

# Copilot PR Processor

Default behavior: take the existing PR supplied by the user, address feedback from GitHub Copilot PR Reviewer and
the SFL full-spectrum reviewer when available, explicitly resolve fixed review threads, and repeat until both
reviewers report zero findings on the current head.

## Target State

GitHub Copilot PR Reviewer does not create a real branch-protection approval. Treat success as a clean Copilot
feedback signal, not as `reviewDecision: APPROVED`.

| Copilot state | Meaning | Done? |
| --- | --- | --- |
| Latest Copilot review body says it has no comments | Copilot reviewed the current head and found nothing to flag | Yes, after checks pass and all Copilot threads are resolved |
| No unresolved Copilot review threads remain | Prior comments were fixed, obsolete, or non-actionable and explicitly resolved in GitHub | Yes, after re-review |
| Copilot left comments on current code | There is feedback to triage and address | No |
| Copilot is unavailable, rate-limited, or refuses duplicate review | Record exact evidence and continue with normal PR checks | Blocked or partial |

The SFL reviewer can formally approve a PR and publishes an `SFL Reviewer Approval` check. Its built-in verdict
allows Medium and Low findings, but this skill uses a stricter zero-finding target.

The HemSoft installation is authored by `sfl-app[bot]`; the bundled state
helper recognizes both that login and legacy `set-it-free-loop` reviewer names.

| SFL state | Meaning | Done? |
| --- | --- | --- |
| Active reviewer workflow supports `workflow_dispatch` | Current SFL review is available in the repository | Continue |
| Active reviewer workflow and `sfl-review` label exist | Legacy SFL review is available | Continue through label fallback |
| Latest current-head verdict is `APPROVE` and the approval gate passes | SFL's merge threshold passed | Not by itself |
| Critical, High, Medium, Low, or unclassified current-run findings remain | The review sheet is not clean | No |
| All current-run severity counts are zero and all SFL threads are resolved | The SFL review sheet is clean | Yes |
| Workflow is absent, inactive, or has no supported trigger | SFL is unavailable on the default branch | Partial; do not claim dual-review completion |

## Inputs

| Input | Accepted form |
| --- | --- |
| PR URL | `https://github.com/OWNER/REPO/pull/123` |
| Repository plus number | `OWNER/REPO` and `123` |
| Current checkout PR | A repository checkout where `gh pr view` resolves the PR |

## Preflight

1. Verify GitHub CLI and auth:

   ```powershell
   $gh = (Get-Command gh.exe).Source
   & $gh auth status
   ```

2. Resolve PR identity:

   ```powershell
   & $gh pr view <pr-url-or-number> --json number,url,headRefName,headRefOid,baseRefName,isDraft,state,mergeStateStatus
   ```

3. Check local worktree hygiene before editing:

   ```powershell
   git status --short --branch
   git branch --show-current
   git worktree list
   ```

4. If the worktree has unrelated user changes, stop and ask before editing.
5. Do not merge the PR unless the user explicitly asks.

6. Detect the SFL reviewer on the repository default branch:

   ```powershell
   .\copilot-pr-processor\scripts\Get-SflPrReviewState.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
   ```

   Current SFL is available when the active workflow is present and supports
   `workflow_dispatch`:

   - Workflow: `.github/workflows/sfl-pr-review.lock.yml`
   - Trigger: `workflow_dispatch`

   The helper also recognizes the retired `sfl-review` label as a compatibility
   fallback for older installations. It checks the live default branch through
   the GitHub API. Do not infer availability from a feature branch, a stale
   local checkout, `sfl-pr`, `agent:pr`, or analyzer labels.

## Review Requests

### GitHub Copilot

Always request Copilot through the API. Do not post `@copilot review`, `@coderabbitai review`, or
`@Macroscope-App review` comments.

Use the bundled request script:

```powershell
.\copilot-pr-processor\scripts\Request-CopilotPrReview.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
```

Use `-DryRun` first when validating a PR identity or troubleshooting permissions.

The default reviewer login is the GitHub-documented `copilot-pull-request-reviewer[bot]`. The script uses the
REST review-request endpoint and verifies that GitHub actually returns Copilot in `requested_reviewers`.
An HTTP success without that reviewer is reported as unavailable rather than as a successful request.

### SFL Full-Spectrum Reviewer

When SFL is available, request it with the bundled script:

```powershell
.\copilot-pr-processor\scripts\Request-SflPrReview.ps1 -Url "https://github.com/OWNER/REPO/pull/123" -DryRun
.\copilot-pr-processor\scripts\Request-SflPrReview.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
```

For current installations, the script dispatches `sfl-pr-review.lock.yml` on
the PR base branch with `item_number` and `aw_context` inputs. The authenticated
actor must have `write`, `maintain`, or `admin` repository permission. Older
installations fall back to applying `sfl-review`.

The SFL reviewer performs three evidence-based passes:

1. Security
2. Correctness and Reliability
3. Quality and Maintainability

It posts one inline thread per finding with a Critical, High, Medium, or Low
severity and submits a structured review sheet. Do not use SFL pipeline state
labels to trigger this standalone review.

## Processing Loop

1. Fetch both review states:

   ```powershell
   .\copilot-pr-processor\scripts\Get-CopilotPrReviewState.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
   .\copilot-pr-processor\scripts\Get-SflPrReviewState.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
   ```

2. Triage every unresolved Copilot and SFL thread:

   | Finding type | Required action |
   | --- | --- |
   | Critical or High | Fix before proceeding; add or update tests when practical |
   | Medium | Fix all material correctness, maintainability, and operational issues |
   | Low | Fix actionable improvements unless doing so would create greater risk |
   | Valid but genuinely out of scope | Reply with a specific reason and residual risk; completion still requires a clean rerun |
   | False positive | Reply with concrete evidence; completion still requires a clean rerun |
   | Stale after code changes | Re-review before resolving; do not hide live feedback |
   | Duplicate | Address once and reference the shared fix |

   SFL's formal `APPROVE` verdict is not enough when Medium or Low findings remain. The skill target is zero
   Critical, High, Medium, Low, and unclassified findings.

3. Implement the smallest defensible changes that answer all findings.
4. Run the repository's relevant checks: tests, lint, typecheck, build, and any PR-specific diagnostics.
5. Commit and push only the intended changes.
6. Explicitly resolve every addressed Copilot and SFL review thread in GitHub before requesting new reviews.
   This is mandatory even when a thread is outdated: `isOutdated: true` with `isResolved: false` is incomplete.
   Use GraphQL `resolveReviewThread` or the MCP `resolve_thread` operation on each fixed thread ID.
7. Re-query both helpers and require `isResolved: true` for every addressed reviewer-authored thread before
   moving on.
8. Request both new reviews against the same pushed head:

   ```powershell
   .\copilot-pr-processor\scripts\Request-CopilotPrReview.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
   .\copilot-pr-processor\scripts\Request-SflPrReview.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
   ```

   Skip the SFL request only when the detection helper reports that the reviewer is unavailable.

9. Wait for both reviewers. Copilot normally needs at least three minutes. For
   current SFL, find and watch the workflow-dispatch run:

   ```powershell
   Start-Sleep -Seconds 180
   gh run list --repo OWNER/REPO --workflow sfl-pr-review.lock.yml --event workflow_dispatch --limit 5
   gh run watch RUN_ID --repo OWNER/REPO --exit-status
   ```

10. Re-fetch both states and repeat while either reviewer has any current-head finding or unresolved thread.

Automatic SFL reviews run on non-draft internal PRs when opened, reopened,
marked ready, or synchronized. Use the request helper for explicit reruns. The
workflow concurrency group cancels an older run for the same PR.

## Readiness Check

Before reporting that the PR is ready:

1. Confirm the PR head SHA that both reviewers analyzed matches the current PR head SHA.
2. Confirm the latest Copilot review has no comments and every Copilot-authored review thread has
   `isResolved: true`. Do not count stale/outdated threads as resolved unless GitHub also reports `isResolved: true`.
3. When SFL is available, require all of the following from `Get-SflPrReviewState.ps1`:

   - `reviewMatchesHead: true`
   - `verdictApproved: true`
   - Critical, High, Medium, Low, and Unknown counts all equal zero
   - `unresolvedSflThreadCount: 0`
   - `approvalGatePassed: true`
   - `cleanSheet: true`

4. Confirm normal PR checks and merge state are acceptable:

   ```powershell
   & $gh pr view <pr-url-or-number> --json headRefOid,reviewDecision,mergeStateStatus,statusCheckRollup
   ```

5. Report the two products separately:

   - Copilot has no actionable comments; do not call its `COMMENTED` review an approval.
   - SFL has a current-head zero-finding sheet and its formal approval gate passes.

If SFL is unavailable, report partial completion with the exact missing or
unsupported workflow evidence. Do not claim that both reviewers are clean.

## Closeout

Return:

1. PR URL and current head SHA.
2. Latest Copilot review URL, author, state, submitted time, and body summary.
3. Latest SFL review URL, author, state, run ID, submitted time, verdict, and severity table.
4. Unresolved Copilot and SFL thread counts after explicit resolution; both must be zero for completed work.
5. `SFL Reviewer Approval` check result for the current head.
6. Commands run and exact pass/fail results.
7. Any unavailable workflow, missing label, API, rate-limit, duplicate-review, authorization, or permission evidence.

## Avoid

- Posting trigger comments to request Copilot review.
- Using CodeRabbitAI or Macroscope in this workflow.
- Mass-resolving review threads without addressing or documenting them.
- Treating outdated/stale review comments as complete while `isResolved` is still false.
- Treating Copilot's `Comment` review as branch-protection approval.
- Treating an SFL `APPROVE` verdict with Medium or Low findings as a clean sheet.
- Applying the retired `sfl-review` label to current installations.
- Dispatching a reviewer from a feature-branch workflow unless bootstrapping the
  PR that installs the default-branch reviewer.
- Confusing standalone SFL review with SFL pipeline state labels.
- Declaring readiness before checking PR head SHA, checks, merge state, and latest Copilot feedback.
