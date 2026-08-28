---
name: issue-to-pr-merge
description: "V1.3 - Commands: Issue, Oldest. Takes one exact or lease-selected oldest GitHub issue through isolated implementation, current-head review, guarded merge, cleanup, and a final Slack notification; Oldest supports hourly resume and stalled-run escalation."
disable-model-invocation: true
compatibility: Requires git, GitHub CLI, network access, permission to push and create a pull request, the configured AI reviewers, mergepr on PATH, and the slack-dm skill.
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

Process one exact or lease-selected GitHub issue from verified repository state
through a merged pull request and a proven post-merge repository state. This skill is a
composition of the `issue-to-pr` skill at `../issue-to-pr/SKILL.md`, the
`process-pr` skill at `../process-pr/SKILL.md`, and the `repo-cleanup` skill at
`../repo-cleanup/SKILL.md`. Read those skills and the review-loop references
they name before acting. Their detailed safety rules remain in force.

Use one of two modes:

- `Issue {ISSUE_URL_OR_OWNER_REPO_NUMBER}` processes one exact issue. This is
  the default when the invocation includes an issue number.
- `Oldest {OWNER/REPO}` processes at most one lease-selected issue for a
  recurring run. Read
  [references/scheduled-oldest-lease.md](references/scheduled-oldest-lease.md)
  before selecting, resuming, or changing an issue in this mode.

## Required input and authority

In `Issue` mode, accept an issue URL or `OWNER/REPO` plus an issue number. If
the target issue is missing, ask only for that target. Do not select backlog
work automatically.

In `Oldest` mode, accept one `OWNER/REPO` and a stable automation ID. Select
only issues labeled `agent:ready`. Default to a 120-minute lease TTL and
escalation after three consecutive completed runs with no movement. Process at
most one issue per invocation. Resume this automation's unfinished issue or
linked pull request before selecting new work.

Invoking this skill authorizes issue implementation, PR creation, review
processing, guarded merge, and cleanup for the one pull request created or
resumed for the specified issue. The invocation is direct merge authority once
the exact pull request is known and every readiness gate below passes. Do not
pause for a second approval prompt. The authority remains valid for this skill
run unless the user pauses or revokes it.

This skill overrides only the separate merge-approval checkpoints in
`issue-to-pr` and `process-pr` when they are composed as phases of this
workflow. Their identity, scope, review, validation, head-freshness, merge, and
cleanup safeguards remain in force. The repository instruction to merge only
when explicitly asked is satisfied by the user's direct invocation of this
skill.

The authority is narrow. It covers only a pull request that maps one-to-one to
the specified issue and contains no unrelated work. It does not cover a
pre-existing unrelated pull request, a mixed-scope replacement, a force merge,
an administrative bypass, or any merge method other than the guarded path in
this skill.

An explicit `Oldest` invocation supplies the same narrow authority for the one
issue that the lease protocol selects or resumes. Record the exact issue before
implementation. The authority does not extend to a second issue in the same
run, an issue reserved by a human, or an issue blocked for human input.

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

## Phase 1: Issue to pull request

Follow `issue-to-pr` sections 1 through 5 for:

- repository identity, default branch, access, and local instructions;
- resume detection for existing issue work;
- branch and isolated worktree naming;
- the smallest complete implementation and repository-native validation;
- commit, push, and one pull request against the verified default branch.

Read `issue-to-pr` section 6 for the owner-specific reviewer policy for the
resulting PR. Let `process-pr` carry out those reviewer requests and collect
the current-head evidence so there is one review loop. Do not change repository
identity, switch accounts without restoring the original account, edit a dirty
primary checkout, or create a duplicate PR.

Do not run a second independent review loop from `issue-to-pr` section 7. Once
the pull request exists, hand the exact PR URL and current head to `process-pr`.

## Phase 2: Process the pull request

Invoke `process-pr` for the exact PR and use its current-head review loop at
`../process-pr/references/current-head-review-loop.md`. The process must:

1. capture the immutable current-head baseline;
2. discover and request the configured reviewers without duplicate requests;
3. fix or disprove every actionable finding, with focused validation;
4. repeat on every new head SHA; and
5. prove the `human-ready` contract immediately before any merge decision.

The reviewer set must include every reviewer required by the verified
repository policy and the owner routing established by `issue-to-pr`. If the
PR is blocked, retain the worktree and branch, report the exact blocker, and do
not merge or clean it up.

## Phase 3: Autonomous guarded-merge gate

When `process-pr` proves `human-ready`, report the exact PR number, URL, head
SHA, checks, reviewer signals, and unresolved-thread count in the final receipt,
not as an intermediate approval request. Immediately re-read the PR and local
state. Confirm the head is unchanged, required checks pass, every configured
current-head reviewer is clean, no live review thread remains unresolved,
GitHub reports the PR mergeable, and the diff still maps only to the specified
issue.

Proceed directly to Phase 4 when those conditions pass. A changed head, failed
check, new actionable finding, conflict, or reviewer regression returns the
workflow to `process-pr`. Stop without merging if authority is revoked, scope
is mixed or uncertain, or any readiness condition cannot be proven.

## Phase 4: Merge and cleanup

With the invocation-derived authority and a fresh readiness proof:

1. Verify `mergepr` resolves on `PATH`.
2. From the repository's clean primary checkout, run `mergepr <pr-number>`.
   Do not run it from the pull-request worktree that `mergepr` will remove.
   Preserve dirty primary-checkout changes before invoking it.
3. Re-read the PR, issue, branch, worktree, and default-branch state.
4. Hand off to `repo-cleanup` in `Audit` mode and verify the merged PR's
   branch/worktree cleanup plus default-branch parity.
5. Complete any Oldest-mode lease and durable-state updates, then invoke the
   `slack-dm` skill at `../slack-dm/SKILL.md`. Send Franz one `merged` DM with
   the canonical `OWNER/REPO` project, `PR #<number> — <exact current title> —
   merged` outcome, PR URL, merge commit, and cleanup result. Send only after
   GitHub reports `MERGED`. This is the final workflow phase before the
   user-facing response.

`mergepr` owns the guarded cleanup of the completed PR's branch and worktree.
Do not duplicate those destructive operations. Do not run broad
`repo-cleanup Clean` or remove unrelated state unless the user separately
requested full repository cleanup in the current conversation. Preserve dirty,
active, unmerged, unknown-owner, or otherwise unrelated work.

If `mergepr` is unavailable or fails, preserve the exact state and report the
error. Do not substitute a raw `gh pr merge`, force-push, branch deletion, or
recursive filesystem deletion.

This composing skill owns the notification. Its `issue-to-pr` and `process-pr`
phases must not send duplicate DMs. A waiting, blocked, failed, or no-op run
does not send a merged notification.

## Definition of done

The issue is closed by the merged PR; the merge commit and exact final head are
recorded; the target default branch matches its remote; the completed PR's
branch and worktree are removed or explicitly retained with evidence; and the
post-merge `repo-cleanup` audit passes. Any unrelated repository work remains
preserved and is reported. A successful run ends its operational work by
sending the Slack merge notification.

For one `Oldest` run, `waiting` is also a valid safe terminal result when the
exact issue and pull request are durably recorded, the run lease is released,
all work remains resumable, and the unchanged-run count is updated. A blocked
result must retain the branch and worktree and must name the required human
decision or repair.

## Closeout report

Report the issue and PR URLs, merge commit, repository and owner, final default
branch and `origin` SHAs, validation results, reviewer signals, active GitHub
identity, target branch/worktree result, cleanup-audit result, and any exact
blocker or retained work.

For `Oldest`, also report the automation ID, lease result, selection or resume
reason, previous and final progress fingerprints, unchanged-run count, and the
next scheduled action. True no-ops may use a one-line receipt.

## History

After using this skill, append `## HH:MM - {Action Taken}` plus a one-line
summary to `History/{YYYY-MM-DD}.md` in this skill folder. Include whether a
retrospective found a reusable improvement. Take the timestamp from the shell
with `Get-Date -Format "HH:mm"` on Windows or `date +%H:%M` elsewhere, never an
estimate.
