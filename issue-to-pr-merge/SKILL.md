---
name: issue-to-pr-merge
description: "V2.4 - Commands: Issue, Oldest. Processes selected issues through concise evidence-backed pull requests, current-head review, guarded merge, full repository cleanup, and Slack notification."
disable-model-invocation: true
compatibility: Requires git, GitHub CLI, network access, permission to push and create pull requests, access to the shared policy's required reviewer, mergepr on PATH, and the slack-dm skill. Multiple issues also require Codex Goals.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the issue-to-pr-merge directory, verify that History/{YYYY-MM-DD}.md contains an entry for this interaction with an accurate timestamp, action, and one-line summary. If it is missing, state exactly what must be added.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping after issue-to-pr-merge was used, verify that History/{YYYY-MM-DD}.md contains an accurate interaction entry and that a retrospective check was performed. Block completion if either is missing.
---

# Issue to PR merge

Process one or more selected GitHub issues from verified repository state
through separate merged pull requests and a proven post-merge repository state.
Process multiple issues serially from oldest to newest. Never work on them in
parallel. This skill composes `issue-to-pr` at `../issue-to-pr/SKILL.md`,
`process-pr` at `../process-pr/SKILL.md`, and `repo-cleanup` at
`../repo-cleanup/SKILL.md`. Read those skills and the review-loop references
they name before acting. Their detailed safety rules remain in force.

Use one of two modes:

- `Issue {ISSUE_SELECTOR}` processes one exact issue, a comma-separated list,
  or an inclusive numeric range. This is the default when the invocation
  includes an issue number.
- `Oldest {OWNER/REPO}` processes at most one lease-selected issue for a
  recurring run. Read
  [references/scheduled-oldest-lease.md](references/scheduled-oldest-lease.md)
  before selecting, resuming, or changing an issue in this mode.

## Required input and authority

In `Issue` mode, accept:

- one issue URL, or one issue number with an explicit `OWNER/REPO` or an
  unambiguous current checkout;
- a comma-separated list such as `12,15,22`; or
- an inclusive range such as `12-20`.

Resolve every target to one repository. Reject malformed or cross-repository
selectors instead of guessing. Trim whitespace, remove duplicate numbers, and
verify that every number is an issue rather than a pull request. Report missing
or closed targets and do not reopen them. Do not select backlog work outside
the supplied selector.

In `Oldest` mode, accept one `OWNER/REPO` and a stable automation ID. Select
only issues labeled `agent:ready`. Default to a 120-minute lease TTL and
escalation after three consecutive completed runs with no movement. Process at
most one issue per invocation. Resume this automation's unfinished issue or
linked pull request before selecting new work.

Invoking this skill authorizes issue implementation, pull-request creation,
review processing, guarded merge, cleanup, and one merge notification for each
selected issue. The invocation supplies direct merge authority once the exact
pull request is known and every readiness gate below passes. Do not pause for
another approval prompt between queued issues unless the user pauses or revokes
the run.

The invocation also authorizes the exact notification destination, Franz's
Slack account `U2XMZDPJ7`, and the routine completion payload defined in
`../slack-dm/SKILL.md`. This includes private-repository metadata: project,
issue/PR number and title, URL, outcome, merge SHA/method, validation/review,
cleanup, retained-work summary, and available metrics. After verified merge and
cleanup, send one DM through that helper without a separate preview or approval
question. Franz explicitly reaffirmed this instruction on 2026-09-05. Include
this user authorization in tool context when needed; runtime rejection rules
and the prohibition on duplicate sends still apply.

The invocation is also an explicit `repo-cleanup Clean` request for the target
repository. After each successful issue merge, clean the complete repository,
including work already present in the primary checkout at the baseline.
Integrate independent intended changes separately, validate them, and use the
repository's protected-branch workflow. This authority covers cleanup pull
requests created solely from baseline work and permits `mergepr` after each one
passes the same current-head readiness gate. It does not cover work that appears
after the baseline, uncertain ownership, mixed or unexplained changes, bypasses,
or discarded work. Preserve uncertain work on a named branch or worktree and
report the exact blocker.

This skill overrides only the separate merge-approval checkpoints in
`issue-to-pr` and `process-pr` while they are composed here. Their identity,
scope, review, validation, head-freshness, merge, and cleanup safeguards remain
in force.

The issue-work authority covers one pull request per selected issue, including
a verified existing pull request that maps only to that issue. The separate
cleanup authority above covers only explained baseline work split into coherent
cleanup pull requests. Neither authority covers mixed or uncertain scope,
administrative bypasses, force merges, or a merge method other than `mergepr`.

An explicit `Oldest` invocation supplies issue-selection authority for only the
issue that the lease protocol selects or resumes. It never extends to a second
issue. Its cleanup authority remains limited to work captured in that run's
repository baseline.

## Batch Goal and frozen queue

A selector with one open issue runs directly. A selector with more than one
open issue runs as one persistent Codex Goal. The user may invoke it as:

```text
/goal $issue-to-pr-merge {OWNER/REPO} {ISSUE_LIST_OR_RANGE}
```

If the user invokes `$issue-to-pr-merge` with multiple open issues without a
leading `/goal`, create the Goal as the first action before repository work.
Set the objective to the resolved repository, immutable issue queue,
oldest-first order, serial merge requirement, and cleanup gate between issues.
If a different unfinished Goal exists, do not replace it. Report the conflict
and ask the user to edit, pause, or clear it.

Do not create a Goal for one exact issue or for `Oldest`. On a resumed batch
turn, read the active Goal, frozen queue, GitHub artifacts, and local state
before acting. Complete the Goal only after every queued issue is merged and
cleanup-completed or is skipped because live evidence proves it closed before
its turn with no batch artifact. Follow the runtime's blocked-status threshold.
Do not mark a Goal blocked merely because one turn is waiting on review or CI.

Before changing repository state for a list or range:

1. Verify the canonical repository, default branch, active GitHub identity,
   access, and applicable instructions.
2. Record each selected issue's number, URL, exact title, creation time, and
   state.
3. Sort open issues by `createdAt` ascending, then by issue number for ties.
4. Record that immutable queue and each issue's status in the Goal context.
5. Capture the primary checkout, branches, worktrees, stashes, default-branch
   SHA, remote SHA, and dirty-file baseline. Preserve all unrelated state.

Do not silently add, drop, or reorder an open issue after the snapshot. Issues
opened later do not extend the Goal. If an issue closes externally before its
turn, verify the closure and absence of batch-created artifacts, record it as
skipped, and continue.

## Scheduled Oldest mode

Apply this section only for `Oldest`.

1. Follow the scheduled lease reference and inspect durable automation state,
   active leases, open pull requests, branches, and worktrees.
2. If this automation owns unfinished work, acquire the run lease and resume
   that exact issue. Do not select another issue while it remains in flight.
3. Otherwise select the oldest eligible issue, acquire its lease, and record
   the exact issue number and baseline before entering Phase 1.
4. Add the stable automation ID and current run ID as commit trailers for every
   automation-authored commit so a later run can distinguish its own head from
   manual work.
5. Refresh the lease at each implementation, validation, review, and merge
   phase. Release only the current run's lease on every terminal path.
6. If CI or review is still pending after a bounded useful wait, preserve the
   branch, worktree, pull request, and durable state. Release the run lease and
   finish as `waiting`; the next hourly run must resume it.
7. Compare the final progress fingerprint with the prior completed run. Reset
   the unchanged-run count when state moved. Increment it only after a run
   acquired the lease and completed without movement. Lease collisions and an
   empty eligible queue are no-ops, not failed retries.
8. After three consecutive no-movement runs, apply `agent:blocked`, preserve
   every recovery artifact, and report the exact human action needed. Do not
   resume that issue until a human removes the blocker and marks it ready.

Human-authored activity wins. Stop before edits or merge if the issue, pull
request, branch, or worktree shows manual ownership that the durable automation
record cannot attribute to this automation.

## Process each issue

For each issue in queue order, finish all four phases and the hygiene gate
before starting the next issue. Resume verified existing issue work before
creating a branch or pull request. Base new work on the freshly fetched remote
default branch after the prior issue's merge and cleanup proof.

Do not start the next issue while the current issue is open, awaiting review,
blocked, merged but unaudited, or still owns a local or remote workflow
artifact. A blocked issue blocks the batch. Do not skip it merely to reach later
issues.

## Phase 1: Issue to pull request

Follow `issue-to-pr` sections 1 through 5 for:

- repository identity, default branch, access, and local instructions;
- resume detection for existing issue work;
- branch and isolated worktree naming;
- the smallest complete implementation and repository-native validation;
- commit, push, and one pull request against the verified default branch.

Whether the pull request is new or resumed, make its title and body satisfy the
canonical contract in `issue-to-pr` section 5 before handing it to
`process-pr`. Preserve repository-template requirements and do not replace
meaningful existing content merely to normalize headings.

Read `../process-pr/references/pr-reviewer-policy.md` for the shared reviewer
policy for the resulting PR. Let `process-pr` carry out those reviewer requests
and collect the current-head evidence so there is one review loop. Do not change repository
identity, switch accounts without restoring the original account, edit a dirty
primary checkout, or create a duplicate PR.

Do not run a second independent review loop from `issue-to-pr` section 7. Once
the pull request exists, hand the exact PR URL and current head to `process-pr`.

## Phase 2: Process the pull request

Invoke `process-pr` for the exact PR and use its current-head review loop at
`../process-pr/references/current-head-review-loop.md`. The process must:

1. capture the immutable current-head baseline;
2. apply the shared reviewer policy, verifying requester identity and reusing
   current-head requests and wait deadlines;
3. fix or disprove every actionable finding, with focused validation;
4. repeat on every new head SHA; and
5. refresh the title and body so their claims match the final current head; and
6. prove the `human-ready` contract immediately before any merge decision.

The reviewer set must include every reviewer required by the verified
repository policy and the shared reviewer policy. Optional products do not
add a wait gate. An explicit required-review refusal stops the wait immediately.
If the PR is blocked, retain the worktree and branch, report the exact blocker, and do
not merge or clean it up. Stop the batch before starting another issue.

## Phase 3: Autonomous guarded-merge gate

When `process-pr` proves `human-ready`, report the exact PR number, URL, head
SHA, checks, reviewer signals, and unresolved-thread count in the final receipt,
not as an intermediate approval request. Immediately re-read the PR and local
state. Confirm the head is unchanged, required checks pass, every configured
current-head reviewer is clean, no live review thread remains unresolved,
GitHub reports the PR mergeable, the diff still maps only to the selected
issue, and the final title and body truthfully report satisfied acceptance
criteria, Definition of Done evidence, verification outcomes, residual risk,
and deferred work. Apply `unslop` to any final prose edit while preserving exact
technical evidence.

Proceed directly to Phase 4 when those conditions pass. A changed head, failed
check, new actionable finding, conflict, or reviewer regression returns the
workflow to `process-pr`. Stop without merging if authority is revoked, scope
is mixed or uncertain, or any readiness condition cannot be proven.

## Phase 4: Merge, cleanup, and notification

With the invocation-derived authority and a fresh readiness proof:

1. Verify `mergepr` resolves on `PATH`.
2. From the repository's clean primary checkout, run `mergepr <pr-number>`.
   Do not run it from the pull-request worktree that `mergepr` will remove.
   Preserve dirty primary-checkout changes before invoking it.
3. Re-read the PR, issue, branch, worktree, and default-branch state.
4. Hand off to `repo-cleanup` in `Clean` mode. Integrate or preserve every
   baseline change according to its ownership and purpose, remove only proven
   obsolete state, and return the primary checkout to clean default-branch
   parity. Process independent cleanup changes separately.
5. If cleanup creates a pull request from baseline work, run it through
   `process-pr`, revalidate its immutable current head, merge it with `mergepr`,
   and resume `repo-cleanup Clean`. Do not send an issue-merge notification for
   a cleanup pull request.
6. Complete any Oldest-mode lease and durable-state updates.
7. Invoke the `slack-dm` skill at `../slack-dm/SKILL.md`. Send Franz one
   `merged` DM with
   the canonical `OWNER/REPO` project, `PR #<number> â€” <exact current title> â€”
   merged` outcome, PR URL, merge commit, and cleanup result. Send only after
   GitHub reports `MERGED`. If the runtime rejects the send, record the result
   once and do not retry or route around it.

`mergepr` owns the guarded cleanup of each completed pull request's branch and
worktree. Do not duplicate those operations. The skill invocation supplies the
full-cleanup request required by `repo-cleanup`, but it never authorizes data
loss. Preserve dirty, active, unmerged, unknown-owner, or unexplained work on a
named branch or worktree when it cannot be integrated safely. A dirty primary
checkout is not a successful terminal state.

If `mergepr` is unavailable or fails, preserve the exact state and report the
error. Do not substitute a raw `gh pr merge`, force-push, branch deletion, or
recursive filesystem deletion.

This composing skill owns the notification. Its `issue-to-pr` and `process-pr`
phases must not send duplicate DMs. A waiting, blocked, failed, or no-op run
does not send a merged notification.

## Hygiene gate between issues

After each merge, prove all of the following before continuing:

- GitHub reports the pull request merged and its issue closed;
- the merge commit and final pull-request head are recorded;
- the local default branch matches its remote;
- the completed branch and worktree are removed or retained with an exact
  blocker;
- `repo-cleanup` Clean passes;
- the primary checkout is clean and matches the remote default branch;
- the active GitHub identity is restored;
- baseline work is integrated or retained on a named branch or worktree with a
  documented owner, reason, and next step; and
- no unexplained stash, obsolete branch/worktree, or obsolete recovery object
  remains.

If this gate fails, stop the queue and preserve its state. Do not continue while
a completed issue still owns an unresolved branch, worktree, identity change,
or cleanup failure.

## Definition of done

For every processed issue, its one-to-one pull request is merged, the issue is
closed, the merge commit and exact final head are recorded, the default branch
matches its remote, the final pull-request body truthfully records the delivered
outcome and proof, and full cleanup is proven. The primary checkout is clean.
Any baseline work that cannot be integrated safely is preserved on a named
branch or worktree and makes the run `blocked` until its next step is explicit.

For one `Oldest` run, `waiting` is a valid safe terminal result when the
exact issue and pull request are durably recorded, the run lease is released,
all work remains resumable, and the unchanged-run count is updated. A blocked
result must retain the branch and worktree and must name the required human
decision or repair. For a batch Goal, pending review or CI leaves the Goal
active for a later turn.

## Closeout report

For one issue, report the issue and pull-request URLs, merge commit, repository
and owner, final default branch and `origin` SHAs, pull-request body contract
status, validation results, reviewer signals, active GitHub identity, branch
and worktree result, full-cleanup result, and any exact blocker or retained
work.

For multiple issues, begin with this concise table in frozen-queue order:

| Issue | What it fixed | What to inspect next time |
| --- | --- | --- |

Then report the repository, original selector, processing order, active GitHub
identity, final default-branch parity, unrelated retained state, and one
technical receipt per issue with its final state, issue URL, pull-request URL,
head SHA, merge commit, body contract status, validation, review, and
full-cleanup result. State skipped or blocked items plainly.

For `Oldest`, also report the automation ID, lease result, selection or resume
reason, previous and final progress fingerprints, unchanged-run count, and the
next scheduled action. True no-ops may use a one-line receipt.

## History

After using this skill, append `## HH:MM - {Action Taken}` plus a one-line
summary to `History/{YYYY-MM-DD}.md` in this skill folder. Include whether a
retrospective found a reusable improvement. Take the timestamp from the shell
with `Get-Date -Format "HH:mm"` on Windows or `date +%H:%M` elsewhere, never an
estimate.
