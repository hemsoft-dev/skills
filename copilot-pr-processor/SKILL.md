---
name: copilot-pr-processor
description: V1.2 - Process an existing GitHub pull request through GitHub Copilot PR Reviewer feedback until the latest Copilot API-requested review has no actionable comments and all Copilot review threads are explicitly resolved. Requires resolving addressed Copilot comments before requesting another review. Use for PR readiness loops that must request Copilot through the GitHub API instead of posting chat-style trigger comments such as @copilot review.
---

# Copilot PR Processor

Default behavior: take the existing PR supplied by the user, address actionable Copilot PR Reviewer feedback,
request another Copilot review through the GitHub API, explicitly resolve fixed Copilot review threads, and repeat
until Copilot reports no comments and no unresolved Copilot threads remain.

## Target State

GitHub Copilot PR Reviewer does not create a real branch-protection approval. Treat success as a clean Copilot
feedback signal, not as `reviewDecision: APPROVED`.

| State | Meaning | Done? |
| --- | --- | --- |
| Latest Copilot review body says it has no comments | Copilot reviewed the current head and found nothing to flag | Yes, after checks pass and all Copilot threads are resolved |
| No unresolved Copilot review threads remain | Prior comments were fixed, obsolete, or non-actionable and explicitly resolved in GitHub | Yes, after re-review |
| Copilot left comments on current code | There is feedback to triage and address | No |
| Copilot is unavailable, rate-limited, or refuses duplicate review | Record exact evidence and continue with normal PR checks | Blocked or partial |

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

## API Review Request

Always request Copilot through the API. Do not post `@copilot review`, `@coderabbitai review`, or
`@Macroscope-App review` comments.

Use the bundled request script:

```powershell
.\copilot-pr-processor\scripts\Request-CopilotPrReview.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
```

Use `-DryRun` first when validating a PR identity or troubleshooting permissions.

The default reviewer login is `copilot-pull-request-reviewer`. The script uses GraphQL
`requestReviewsByLogin` with `botLogins` by default, then can fall back to the REST review-request endpoint.

## Processing Loop

1. Fetch current Copilot review state:

   ```powershell
   .\copilot-pr-processor\scripts\Get-CopilotPrReviewState.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
   ```

2. Triage every unresolved Copilot thread:

   | Comment type | Required action |
   | --- | --- |
   | Correct bug, security, test, or maintainability issue | Fix code and add or update tests when practical |
   | Valid but out of scope | Reply with a specific reason and note residual risk |
   | Stale after code changes | Re-review before resolving; do not hide live feedback |
   | Duplicate of another thread | Address once and reference the shared fix |

3. Implement the smallest defensible code change that answers the feedback.
4. Run the repository's relevant checks: tests, lint, typecheck, build, and any PR-specific diagnostics.
5. Commit and push only the intended changes.
6. Explicitly resolve every addressed Copilot review thread in GitHub before requesting another Copilot review.
   This is mandatory even when a thread is outdated: `isOutdated: true` with `isResolved: false` is still
   incomplete. Use GraphQL `resolveReviewThread` (or the MCP `resolve_thread` operation) on each fixed thread ID.
7. Re-query `reviewThreads` and require `isResolved: true` for every addressed Copilot-authored thread before
   moving on. Do not request another Copilot review while any previously addressed Copilot comment remains
   unresolved.
8. Request a new Copilot review through the API:

   ```powershell
   .\copilot-pr-processor\scripts\Request-CopilotPrReview.ps1 -Url "https://github.com/OWNER/REPO/pull/123"
   ```

9. Wait three minutes:

   ```powershell
   Start-Sleep -Seconds 180
   ```

10. Re-fetch state and repeat while Copilot leaves new actionable comments.

## Readiness Check

Before reporting that the PR is ready:

1. Confirm the PR head SHA that Copilot reviewed matches the current PR head SHA.
2. Confirm the latest Copilot review has no comments and every Copilot-authored review thread has
   `isResolved: true`. Do not count stale/outdated threads as resolved unless GitHub also reports `isResolved: true`.
3. Confirm normal PR checks and merge state are acceptable:

   ```powershell
   & $gh pr view <pr-url-or-number> --json headRefOid,reviewDecision,mergeStateStatus,statusCheckRollup
   ```

4. Report that Copilot has no actionable comments. Do not call it an approval unless GitHub changes Copilot's
   review behavior and live evidence proves it.

## Closeout

Return:

1. PR URL and current head SHA.
2. Latest Copilot review URL, author, state, submitted time, and body summary.
3. Unresolved Copilot threads count after explicit resolution; this must be zero for completed work.
4. Commands run and exact pass/fail results.
5. Any unavailable API, rate-limit, duplicate-review, or permission evidence.

## Avoid

- Posting trigger comments to request Copilot review.
- Using CodeRabbitAI or Macroscope in this workflow.
- Mass-resolving review threads without addressing or documenting them.
- Treating outdated/stale review comments as complete while `isResolved` is still false.
- Treating Copilot's `Comment` review as branch-protection approval.
- Declaring readiness before checking PR head SHA, checks, merge state, and latest Copilot feedback.
