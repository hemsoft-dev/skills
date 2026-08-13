---
name: codex-pr-processor
description: V1.2 - Process an existing GitHub pull request through Codex, CodeRabbit, Macroscope, and optional Greptile feedback until current-head actionable comments are addressed, review threads are resolved, and normal PR checks pass.
disable-model-invocation: true
compatibility: Requires PowerShell 7, GitHub CLI, GitHub network access, and authenticated gh. Helper scripts support Windows, macOS, and Linux when these dependencies are installed.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the codex-pr-processor directory (path contains 'codex-pr-processor'), verify that history logging occurred.

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
            Before stopping, if codex-pr-processor was used (check if any files in codex-pr-processor directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in codex-pr-processor directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Codex PR Processor

Default behavior: take the existing PR supplied by the user, address actionable Codex review feedback, request another Codex review, and use CodeRabbit plus Macroscope as secondary reviewers. Include Greptile only when the user requests it or the repository workflow explicitly requires it. Repeat until the latest current-head review signal has no actionable comments, all addressed review threads are explicitly resolved, and normal PR checks pass.

## Target State

Codex reviews currently behave like automated PR comments/reviews, not guaranteed branch-protection approvals. Treat success as a clean feedback signal unless live GitHub evidence shows an approval.

| State | Meaning | Done? |
| --- | --- | --- |
| Latest Codex review/comment for current head has no actionable comments | Codex reviewed the current head and found nothing to fix | Yes, after checks pass and all relevant threads are resolved |
| CodeRabbit status is success and no current-head actionable CodeRabbit threads remain | Secondary review is clean | Yes |
| Macroscope Correctness is success and no current-head actionable Macroscope threads remain | Secondary review is clean; Approvability may be neutral | Yes |
| Requested Greptile review has no current-head actionable comments | Optional review is clean; use the live Greptile status check when configured | Yes |
| No unresolved addressed review threads remain | Prior comments were fixed, obsolete, or non-actionable and explicitly resolved in GitHub | Yes |
| Any reviewer leaves current-code actionable feedback | There is feedback to triage and address | No |

## Inputs

| Input | Accepted form |
| --- | --- |
| PR URL | `https://github.com/OWNER/REPO/pull/123` |
| Repository plus number | `OWNER/REPO` and `123` |
| Current checkout PR | A repository checkout where `gh pr view` resolves the PR |

## Preflight

1. Verify GitHub CLI and auth:

   ```powershell
   $gh = (Get-Command gh -CommandType Application -ErrorAction Stop).Source
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

## Review Requests

Request the standard reviewers through their documented PR trigger comments, not the Copilot `requestReviewsByLogin` API path:

```powershell
.\codex-pr-processor\scripts\Request-CodexPrReview.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
```

By default the script posts these comments:

- `@codex review`
- `@coderabbitai review`
- `@Macroscope-App review`

To request Greptile too, add `-IncludeGreptile`:

```powershell
.\codex-pr-processor\scripts\Request-CodexPrReview.ps1 `
  -Url "https://github.com/OWNER/REPO/pull/123" `
  -IncludeGreptile `
  -GreptileReady
```

This adds the official manual Greptile trigger comment, `@greptileai`. Before
requesting it, verify that the repository is enabled and indexed in Greptile.
Greptile reviews can consume review quota, so do not enable this option without
user or repository-workflow authorization. The request helper requires
`-GreptileReady` as an explicit attestation when `-IncludeGreptile` is used.

Use `-DryRun` first when validating a PR identity or troubleshooting permissions.

Official Greptile references:

- [Manual review triggers](https://www.greptile.com/docs/code-review-bot/trigger-code-review)
- [Developer essentials](https://www.greptile.com/docs/code-review/developer-essentials)

## Automatic Codex Reviews

Codex can be configured in Codex settings to review every pull request automatically. Before relying on automation, verify:

1. Codex cloud is set up for the target repository.
2. Code review is enabled for the repository.
3. Automatic reviews are enabled.
4. The pull request event matches the configured review trigger settings.

If automatic reviews are configured to run on PR updates, use the automatic review result as the first signal and only post `@codex review` when a manual re-review is needed or the expected review did not appear.

## Processing Loop

1. Fetch current reviewer state:

   ```powershell
   .\codex-pr-processor\scripts\Get-CodexPrReviewState.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
   ```

2. Triage every unresolved Codex, CodeRabbit, Macroscope, and requested Greptile thread:

   | Comment type | Required action |
   | --- | --- |
   | Correct bug, security, test, or maintainability issue | Fix code and add or update tests when practical |
   | Valid but out of scope | Reply with a specific reason and note residual risk |
   | Stale after code changes | Re-review before resolving; do not hide live feedback |
   | Duplicate of another thread | Address once and reference the shared fix |

3. Implement the smallest defensible code change that answers the feedback.
4. Run the repository's relevant checks: tests, lint, typecheck, build, and any PR-specific diagnostics.
5. Commit and push only the intended changes.
6. Explicitly resolve every addressed reviewer thread in GitHub before requesting another review. This is mandatory even when a thread is outdated: `isOutdated: true` with `isResolved: false` is still incomplete.
7. Re-query `reviewThreads` and require `isResolved: true` for every addressed thread before moving on.
8. Request fresh reviews:

   ```powershell
   .\codex-pr-processor\scripts\Request-CodexPrReview.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
   ```

   Add `-IncludeGreptile` when Greptile is part of the active review set.

9. Wait for review/check completion. Poll more frequently for status checks, but give review bots several minutes before deciding they did not respond.
10. Re-fetch state and repeat while any reviewer leaves new actionable comments.

## Readiness Check

Before reporting that the PR is ready:

1. Confirm the PR head SHA that reviewers evaluated matches the current PR head SHA.
2. Confirm every addressed Codex, CodeRabbit, Macroscope, and requested Greptile review thread has `isResolved: true`. Do not count stale/outdated threads as resolved unless GitHub also reports `isResolved: true`.
3. Confirm normal PR checks and merge state are acceptable:

   ```powershell
   & $gh pr view <pr-url-or-number> --json headRefOid,reviewDecision,mergeStateStatus,statusCheckRollup
   ```

4. Report the actual reviewer signal. Do not call Codex or Macroscope an approval unless GitHub reports an approval or success status that means that.

## Closeout

Return:

1. PR URL and current head SHA.
2. Latest Codex, CodeRabbit, Macroscope, and requested Greptile review URLs or check URLs, states, submitted/completed times, and body summaries.
3. Unresolved reviewer thread count after explicit resolution; this must be zero for completed work.
4. Commands run and exact pass/fail results.
5. Any unavailable API, rate-limit, duplicate-review, or permission evidence.

## Avoid

- Using the Copilot `requestReviewsByLogin` API path for Codex.
- Requesting Greptile without explicit user or repository-workflow authorization.
- Mass-resolving review threads without addressing or documenting them.
- Treating outdated/stale review comments as complete while `isResolved` is still false.
- Treating Codex comments as branch-protection approval.
- Treating a Greptile comment or confidence score as approval without a successful configured status check.
- Declaring readiness before checking PR head SHA, checks, merge state, and latest reviewer feedback.
