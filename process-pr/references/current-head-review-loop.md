# Current-Head Review Loop

Use this reference for the concrete evidence contract behind `process-pr`. Commands are PowerShell-compatible; replace placeholders with resolved values and quote comma-separated `--json` field lists.

Read [pr-reviewer-policy.md](pr-reviewer-policy.md) for the single product
registry, required reviewer selection, request methods, and bounded waits.
This reference owns evidence collection and thread handling only.

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

## Reviewer selection and requests

Apply [pr-reviewer-policy.md](pr-reviewer-policy.md) before requesting or
waiting. Inspect required repository policy and the current PR's evidence;
do not discover optional reviewers from workflow inventories or older PRs.
A refusal ends that request immediately. Preserve its evidence and use the
shared policy's access-correction rules rather than starting another wait.

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
2. Request each required reviewer under the shared policy, reusing existing requests.
3. Wait for required reviewer completion and checks within the shared limits.
4. Process all findings from that SHA.
5. If code changes, validate, commit, and push.
6. Read the new head SHA and begin a new epoch.

Reviewer evidence from an earlier epoch can explain history but cannot satisfy the final gate.

## Final Gate

Re-run the baseline queries after the last reviewer and required check complete. The final report must distinguish these states:

| Result | Meaning |
| --- | --- |
| `human-ready` | All required checks pass; the PR is mergeable; every reviewer required by the shared policy and repository is current-head clean or approved; no actionable thread remains |
| `blocked` | A required reviewer/check is unavailable or pending, permissions are insufficient, product direction is required, or safe iteration cannot continue |

Optional runs do not block readiness, but their actionable findings still need assessment. A required reviewer that is pending, refused, or unavailable prevents `human-ready` completion.
