# Reviewer discovery and iteration

Use this reference only after a pull request exists and is ready for review.
All observations must be tied to the pull request's current head SHA.

For the wider multi-reviewer evidence contract (thread decision table,
evidence epochs, final gate), see
`../../process-pr/references/current-head-review-loop.md`.

## Baseline state

Capture the pull request identity and current head, then inspect checks:

```text
gh pr view <pr> --repo <owner/repo> --json number,url,state,isDraft,baseRefName,headRefName,headRefOid,mergeStateStatus,reviewDecision,reviewRequests,reviews
gh pr checks <pr> --repo <owner/repo>
```

Use `gh pr checks --watch --interval 10` only when checks are already running
and waiting is useful. Inspect failed Actions logs before editing.

GitHub's ordinary PR JSON does not expose full review-thread resolution state.
Use the GitHub GraphQL `reviewThreads` connection, with pagination, when inline
thread state matters. If a current dedicated GitHub review-comment skill is
available in the runtime, it may provide the same thread-level evidence.

## Copilot

The supported GitHub CLI request is:

```text
gh pr edit <pr> --repo <owner/repo> --add-reviewer "@copilot"
```

Request once per unchanged head. A current-head Copilot review with no findings
and no unresolved Copilot threads is clean. If it leaves findings:

1. Verify each against the current code.
2. Fix actionable findings and run relevant tests.
3. Push the fix.
4. Reply with concise evidence where explanation is useful.
5. Resolve a Copilot thread only after its finding is fixed, obsolete, or
   disproven with evidence.
6. Request or await review of the new head according to repository behavior.

Copilot PR Review commonly leaves comments rather than a branch-protection
approval. Record its clean feedback state separately from GitHub's
`reviewDecision`.

## SFL detection

Inspect the repository default branch, not the feature branch, for these active
workflows:

```text
.github/workflows/sfl-pr-review-auto.yml
.github/workflows/sfl-pr-review.lock.yml
```

The auto workflow may be either a dispatcher for the reviewer lock or an
observer named `SFL Codex Review Observer` that validates registered native
Codex reviews without a reviewer lock. Also inspect live workflow state through
the Actions API. If the repository variable `SFL_ENABLED` is readable and
explicitly equals `false`, SFL is disabled. Absence of that variable does not by
itself disable SFL.

Classify SFL as:

- **automatic**: the active auto-trigger and compatible reviewer lock exist on
  the default branch;
- **observer**: an active `SFL Codex Review Observer` publishes the live required
  SFL gate and accepts registered exact-head reviews through `gh sfl review`;
- **manual only**: the active reviewer lock supports `workflow_dispatch` but no
  active auto-trigger exists;
- **not configured**: no active compatible reviewer workflow exists;
- **misconfigured**: repository rules expect `SFL Reviewer Approval`, but the
  reviewer cannot produce it.

Current automatic SFL review requires an open, ready, same-repository pull
request targeting the default branch. The auto-trigger reacts to pull-request
events including `opened`, `synchronize`, `reopened`, `ready_for_review`,
`edited`, `review_requested`, and the explicit `sfl-review` label.

When automatic SFL is configured, let the normal ready/synchronize event run
first. Do not manually dispatch a duplicate run while one is queued or active.

For an observer deployment, inspect `gh sfl status --repo <owner/repo>` and use
the installed extension's documented request shape, normally:

```text
gh sfl review --repo <owner/repo> <pr-number>
```

If status reports the observer installed but the review command reports that
SFL is not installed, the extension and deployment are incompatible. Classify
SFL as misconfigured and preserve the failing required gate. Do not run
`gh sfl init`, `gh sfl sync`, or manually recreate the observer's registry and
comment protocol without explicit deployment-repair authority.

## SFL explicit rerun

Use an explicit rerun only when the pull request is eligible, no exact-head SFL
run is active, and either a rerun is needed after feedback or normal automation
did not start. Prefer the repository's documented trigger. Current SFL reviewer
locks accept a manual dispatch shaped like:

```text
gh workflow run sfl-pr-review.lock.yml \
  --repo <owner/repo> \
  --ref <default-branch> \
  -f item_number=<pr-number> \
  -f base_sha=<base-sha> \
  -f head_sha=<head-sha> \
  -f review_effort=low \
  -f 'aw_context={"item_type":"pull_request","item_number":<pr-number>,"base_sha":"<base-sha>","head_sha":"<head-sha>"}'
```

Before dispatching, read the live workflow's declared inputs; deployments may
evolve. If the repository documents `sfl-review` as its explicit trigger, use
that label instead. Never add or toggle unrelated SFL pipeline labels.

## SFL result rules

The current SFL contract publishes review findings plus an immutable-head
required check or status, such as `SFL Reviewer Approval` or
`SFL Reviewer Gate Runner`. Discover the live required context instead of
hard-coding one name. Completion requires that context to succeed for the
current head and all actionable findings to be fixed.

Do not manually resolve a live SFL finding merely to make the thread count look
clean. After pushing a fix, let the next exact-head SFL run determine whether
the old finding is outdated and whether the new head is clean. Resolve only
when the installed SFL contract or GitHub state makes that safe and the finding
no longer applies.

If `SFL Reviewer Approval` is expected but absent, inspect the auto-trigger and
reviewer workflow runs. Report the precise missing permission, secret,
installation, workflow, or eligibility failure. Never bypass the gate.

## Bounded loop

For each new head SHA, allow at most one outstanding Copilot request and one
outstanding SFL review. Continue useful local work while reviews run. Stop and
report evidence when:

- the current head is clean and all applicable checks pass;
- a reviewer is unavailable after one valid request;
- a repository configuration failure prevents a required check;
- feedback requires a product decision or materially expands the issue; or
- repeated identical feedback cannot be resolved without greater risk.
