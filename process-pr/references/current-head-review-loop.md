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
gh x status
```

Run `gh x status` from the target repository. Capture the row for the exact PR
number. Its exit code is not a cleanliness signal; the command exits zero even
when the row says `fail` or `pending`.

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

## Cancelled checks and preserved event payloads

A passing branch run does not necessarily replace checks attached to a PR's
synthetic merge revision. Inspect the exact check URLs and revisions when
`gh pr checks` or `gh x status` still reports a stale cancellation or failure.
Record the synthetic revision's parents and tree before associating its results
with the reviewed head.

A rerun retains its original event payload. Rerunning a cancelled draft event
can still defer memory qualification after the PR is marked ready. Do not count
that deferral as a pass. When the caller authorizes CI execution and a verified
non-draft PR run already exists for the unchanged head, rerun that correct event
once, then wait for its real checks. A branch `workflow_dispatch` run can provide
additional evidence but may not clear the PR-merge contexts.

Do not create empty commits, change labels, retrigger paid reviews, manufacture
check results, or weaken policies to clear stale state. If no safe authorized
run can replace the context, preserve the evidence and report the blocker.

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

Re-run the baseline queries after the last reviewer and required check complete.
Then run `gh x status` from the target repository and locate the exact PR number.
A clean aggregate row has `State open`, `AI pass`, `Checks pass`, and a `Cmts`
value with the clean `!` marker and no unresolved threads. Apply the shared
[formal-approval policy](pr-reviewer-policy.md#ai-review-and-formal-approval)
to `Rev`: require approval only when effective repository rules, applicable
instructions or explicit user direction require it. Otherwise a verified
`Rev -` or comment-only clean review is acceptable. Report that state truthfully;
do not manufacture approval or ask for it just to fill a display column.
Required approvals, live change requests and unknown approval requirements
still block readiness.

A zero command exit code does not satisfy this requirement. A failed or pending
required gate, unknown value, missing row or unresolved-comment result requires
more processing or an explicitly incomplete handoff.

The final report must distinguish these states:

| Result | Meaning |
| --- | --- |
| `human-ready` | All required checks pass; the PR is mergeable; every reviewer required by the shared policy and repository is current-head clean or approved; no actionable thread remains; the exact `gh x status` PR row is clean |
| `blocked` | The exact `gh x status` PR row is not clean and further progress requires unavailable infrastructure, permissions, product direction, an unsafe scope expansion, or another hard blocker |

Optional runs do not block readiness, but their actionable findings still need assessment. A required reviewer that is pending, refused, or unavailable prevents `human-ready` completion.
