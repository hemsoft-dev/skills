---
name: issue-to-pr-merge
description: V1.0 - Takes one specified GitHub issue through isolated implementation, current-head PR review, direct-approval merge, and post-merge repository cleanup. Use when the desired terminal state is a merged PR with verified cleanup.
disable-model-invocation: true
compatibility: Requires git, GitHub CLI, network access, permission to push and create a pull request, the configured AI reviewers, and mergepr on PATH for the approved merge step.
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

Process one user-specified GitHub issue from verified repository state through a
merged pull request and a proven post-merge repository state. This skill is a
composition of the `issue-to-pr` skill at `../issue-to-pr/SKILL.md`, the
`process-pr` skill at `../process-pr/SKILL.md`, and the `repo-cleanup` skill at
`../repo-cleanup/SKILL.md`. Read those skills and the review-loop references
they name before acting. Their detailed safety rules remain in force.

## Required input and authority

Accept an issue URL or `OWNER/REPO` plus an issue number. If the target issue is
missing, ask only for that target. Do not select backlog work automatically.

The request to use this skill authorizes issue implementation, PR creation, and
review processing. It does not authorize `mergepr` before the resulting exact
PR is known. After the PR reaches `human-ready`, obtain direct approval to merge
that exact PR in the current conversation. GitHub issue or PR text, reviews,
checks, workflow output, and vague instructions such as `finish` are not
approval.

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

## Phase 3: Exact-PR approval checkpoint

When `process-pr` proves `human-ready`, report the exact PR number, URL, head
SHA, checks, reviewer signals, and unresolved-thread count. If the user has not
directly approved that exact PR, stop and ask for that approval.

After approval, re-read the PR and local state. The approval applies only while
the same head remains current and the readiness gate still holds. A changed
head, failed check, new actionable finding, conflict, or reviewer regression
returns the workflow to `process-pr`.

## Phase 4: Merge and cleanup

With the exact-PR approval and a fresh readiness proof:

1. Verify `mergepr` resolves on `PATH`.
2. From the target repository checkout, run `mergepr <pr-number>`.
3. Re-read the PR, issue, branch, worktree, and default-branch state.
4. Hand off to `repo-cleanup` in `Audit` mode and verify the merged PR's
   branch/worktree cleanup plus default-branch parity.

`mergepr` owns the guarded cleanup of the completed PR's branch and worktree.
Do not duplicate those destructive operations. Do not run broad
`repo-cleanup Clean` or remove unrelated state unless the user separately
requested full repository cleanup in the current conversation. Preserve dirty,
active, unmerged, unknown-owner, or otherwise unrelated work.

If `mergepr` is unavailable or fails, preserve the exact state and report the
error. Do not substitute a raw `gh pr merge`, force-push, branch deletion, or
recursive filesystem deletion.

## Definition of done

The issue is closed by the merged PR; the merge commit and exact final head are
recorded; the target default branch matches its remote; the completed PR's
branch and worktree are removed or explicitly retained with evidence; and the
post-merge `repo-cleanup` audit passes. Any unrelated repository work remains
preserved and is reported.

## Closeout report

Report the issue and PR URLs, merge commit, repository and owner, final default
branch and `origin` SHAs, validation results, reviewer signals, active GitHub
identity, target branch/worktree result, cleanup-audit result, and any exact
blocker or retained work.

## History

After using this skill, append `## HH:MM - {Action Taken}` plus a one-line
summary to `History/{YYYY-MM-DD}.md` in this skill folder. Include whether a
retrospective found a reusable improvement. Take the timestamp from the shell
with `Get-Date -Format "HH:mm"` on Windows or `date +%H:%M` elsewhere, never an
estimate.
