# Current-Head Review Loop

Use this reference for the concrete evidence contract behind `process-pr`. Commands are PowerShell-compatible; replace placeholders with resolved values and quote comma-separated `--json` field lists.

## Baseline Evidence

```powershell
gh pr view <pr> --repo <owner/repo> --json 'number,url,state,isDraft,author,baseRefName,baseRefOid,headRefName,headRefOid,mergeStateStatus,reviewDecision,reviewRequests,reviews,statusCheckRollup'
gh pr checks <pr> --repo <owner/repo>
gh run list --repo <owner/repo> --branch <head-branch> --limit 30
```

Fetch full thread state with paginated GraphQL because `gh pr view` does not expose review threads reliably:

```graphql
query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      headRefOid
      reviewThreads(first: 100, after: $cursor) {
        nodes {
          id
          isResolved
          isOutdated
          comments(first: 100) {
            nodes {
              id
              url
              body
              createdAt
              author { login }
              commit { oid }
              path
              line
              originalLine
            }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
```

Follow `pageInfo` until `hasNextPage` is false. Keep reviewer identity matching evidence-based: prefer exact live bot logins from the repository instead of broad substring matches.

## Reviewer Discovery

Inspect the default branch, not only the PR branch:

```powershell
gh repo view <owner/repo> --json 'defaultBranchRef,nameWithOwner,viewerPermission'
gh api "repos/<owner>/<repo>/contents/.github/workflows?ref=<default-branch>"
gh label list --repo <owner/repo> --limit 100
gh pr list --repo <owner/repo> --state merged --limit 10 --json 'number,reviews,statusCheckRollup'
```

Also read repository instructions and automation documentation. A workflow file's presence is not enough: verify it is active, inspect its live triggers and declared inputs, and confirm that the PR is eligible.

Classify each reviewer as:

- `automatic`: configured to review this PR event or synchronization;
- `manual`: repository documentation provides a supported API, comment, label, or workflow trigger;
- `unavailable`: configured but cannot run, with exact evidence;
- `not configured`: no live repository evidence supports requesting it.

Only `automatic` and `manual` reviewers belong to the active reviewer set.

## Request Rules

### GitHub Copilot PR Review

When configured, request Copilot through GitHub's reviewer request path:

```powershell
gh pr edit <pr> --repo <owner/repo> --add-reviewer "@copilot"
```

Request once per unchanged head and verify that GitHub retained or acted on the request. Copilot often submits a `COMMENTED` review rather than an approval. Completion means a current-head review with no actionable findings and no unresolved Copilot threads; do not report formal approval unless GitHub actually returned one.

### SFL

Detect SFL only from the default branch and live Actions state. Current installations commonly use:

- `.github/workflows/sfl-pr-review-auto.yml` for automatic review;
- `.github/workflows/sfl-pr-review.lock.yml` for the reviewer workflow.

Honor explicit disabling such as `SFL_ENABLED=false`. Do not infer that SFL is absent merely because the variable is missing.

For an eligible non-draft same-repository PR targeting the default branch, allow the automatic review to run first. If a manual rerun is needed, inspect the live workflow's `workflow_dispatch` inputs and pass exactly those declared on the default branch. Do not reuse a remembered dispatch shape.

SFL is clean only when its current-head evidence shows:

- its approval verdict or approval check passed;
- Critical, High, Medium, Low, and unclassified finding counts are zero;
- no unresolved SFL-authored thread remains.

Do not manually resolve live SFL findings just to lower the thread count. Push the fix and let the next current-head run obsolete or close the finding according to the installed workflow.

### Other AI Reviewers

Codex, CodeRabbit, Macroscope, Greptile, and repository-specific reviewers have different installation, quota, and trigger contracts. Request one only when live repository policy or established PR behavior proves that it is configured. Use that repository's documented request mechanism and verify the resulting run or review.

Do not copy trigger comments from another repository. In particular, do not spend a metered review or enable an optional reviewer without repository policy or user authorization.

Define the completion signal before requesting the reviewer. Accept formal approval when provided; otherwise require a current-head clean review/check plus zero unresolved actionable threads.

## Thread Decisions

Use this decision table for each current-head thread:

| State | Action |
| --- | --- |
| Valid and actionable | Fix, validate, push, then resolve when permitted |
| False positive | Reply with code, test, or contract evidence; resolve only after the evidence is recorded |
| Duplicate | Address the shared cause once, link the fixing evidence, then resolve each duplicate thread |
| Out of scope | Explain scope and residual risk; obtain user direction when deferral affects human readiness |
| Outdated after a fix | Verify the finding is absent on the new head; resolve if the workflow permits it |
| Contradictory or repeatedly recurring | Stop before risky churn and report the conflict with evidence |

An outdated thread with `isResolved: false` is still unresolved. A reply alone does not resolve a thread.

## Evidence Epochs

The head SHA is the review epoch identifier:

1. Record the current head SHA.
2. Request each active reviewer at most once.
3. Wait for reviewer completion and checks.
4. Process all findings from that SHA.
5. If code changes, validate, commit, and push.
6. Read the new head SHA and begin a new epoch.

Reviewer evidence from an earlier epoch can explain history but cannot satisfy the final gate.

## Final Gate

Re-run the baseline queries after the last reviewer and required check complete. The final report must distinguish these states:

| Result | Meaning |
| --- | --- |
| `human-ready` | All required checks pass; the PR is mergeable; every configured, available AI reviewer is current-head clean or approved; no actionable thread remains |
| `blocked` | A required reviewer/check is unavailable or pending, permissions are insufficient, product direction is required, or safe iteration cannot continue |

An optional reviewer that is demonstrably unavailable may be reported as a limitation without blocking. A configured required reviewer that is unavailable prevents `human-ready` completion.
