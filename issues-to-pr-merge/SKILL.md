---
name: issues-to-pr-merge
description: V1.3 - Runs a Codex Goal that autonomously processes one repository's selected GitHub issues oldest-first, takes each through guarded merge and cleanup without per-PR approval prompts, then gives the user a plain-language recap.
disable-model-invocation: true
compatibility: Requires Codex Goals, git, GitHub CLI, network access, permission to push, create pull requests, and merge the frozen queue, the configured AI reviewers, and mergepr on PATH.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the issues-to-pr-merge directory, verify that History/{YYYY-MM-DD}.md contains an entry for this interaction with an accurate timestamp, action, and one-line summary. If it is missing, state exactly what must be added.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping after issues-to-pr-merge was used, verify that History/{YYYY-MM-DD}.md contains an accurate interaction entry and that a retrospective check was performed. Block completion if either is missing.
---

/goal $issues-to-pr-merge {OWNER/REPO} {ISSUE_SELECTOR}

# Issues to PR merge

Process a frozen batch of GitHub issues as one persistent Codex Goal. Complete
each issue's implementation, review, guarded merge, and cleanup before starting
the next issue. Never work on selected issues in parallel.

The first body line is the canonical invocation. Codex parses `/goal` only when
it leads the submitted user prompt. If the user invokes
`$issues-to-pr-merge` without `/goal`, use the goal-creation capability as the
first action, before repository work. Build the objective from the resolved
repository and selector. If a different unfinished goal already exists, do not
replace it. Report the conflict and ask the user to edit, pause, or clear it.

This skill composes `issue-to-pr-merge` at
`../issue-to-pr-merge/SKILL.md`, which in turn composes `issue-to-pr`,
`process-pr`, and `repo-cleanup`. Read those skills and their named references
before acting. All identity, review, worktree, and cleanup rules remain in
force. This batch skill extends the singular skill's invocation-derived merge
authority to every issue in the frozen queue. It does not add a per-PR approval
checkpoint.

## Input

Accept one repository and one issue selector:

- an inclusive numeric range such as `12-20`;
- a comma-separated list such as `12,15,22`; or
- `all`, meaning every open issue visible when the queue is created.

Resolve the repository from `OWNER/REPO`, an issue URL, or the current
checkout's unambiguous GitHub `origin`. If it cannot be resolved safely, ask
only for the repository. Process one repository per goal.

Reject malformed selectors instead of guessing. Trim whitespace, remove
duplicate issue numbers, and never treat pull requests as issues. For a range
or list, report missing or already-closed numbers and do not reopen them. For
`all`, paginate until every open issue is captured. `all` is a snapshot, so
issues opened after queue creation do not extend the goal.

## Freeze the queue

Before changing repository state:

1. Verify the canonical repository, default branch, active GitHub identity,
   access, applicable instructions, and live issue metadata.
2. Record each selected issue's number, URL, title, creation time, and state.
3. Sort open issues by `createdAt` ascending, then by issue number for ties.
4. Record the immutable queue and per-issue status in the active task plan.
5. Capture the primary checkout, branches, worktrees, stashes, default-branch
   SHA, remote SHA, and dirty-file baseline. Preserve all unrelated state.

Do not silently add, drop, or reorder an open issue after this snapshot. If an
issue closes externally before its turn, verify the closure, mark it skipped
with evidence, and continue only when no batch-created branch or worktree needs
attention.

## Process one issue at a time

For the oldest remaining issue, invoke `issue-to-pr-merge` and follow its full
workflow. Resume existing issue work before creating a branch or pull request.
Create new work only in the singular skill's isolated worktree. Base every new
issue branch on the freshly fetched remote default branch after the previous
issue's merge and cleanup proof.

Do not start the next issue while the current issue is open, awaiting review,
blocked, merged but unaudited, or still owns a local or remote batch artifact.

## Batch invocation extends guarded merge authority

Invoking this batch skill authorizes implementation, pull-request creation,
review processing, guarded merge, and cleanup for every issue in the frozen
queue. Do not pause for separate approval after each pull request is created.
The user's invocation is direct merge authority for only those resulting pull
requests and remains valid for the active Goal unless the user revokes it.

This authority supersedes the default separate-approval rules in `issue-to-pr`
and `process-pr` only while those skills run as phases of this batch. Do not let
a subordinate skill insert an approval prompt after a queued pull request
becomes `human-ready`.

This authorization applies only when the pull request maps one-to-one to a
frozen issue and the singular workflow proves the exact current head is
`human-ready`. Immediately before merging, re-fetch the PR and confirm its head
SHA is unchanged, all required checks pass, every configured current-head
reviewer is clean, no live review thread remains unresolved, and GitHub reports
the PR mergeable. Stop if any condition fails, the PR contains unrelated work,
the head changes after validation, or the user pauses or revokes authority.

After the final revalidation, run the singular skill's guarded `mergepr` step,
finish its cleanup audit, and continue to the next queued issue without another
prompt. Do not use this authorization for pre-existing unrelated PRs, issues
outside the frozen queue, replacement PRs with mixed scope, bypasses, force
merges, or any merge method other than the guarded path. Do not mark the batch
complete at an intermediate `human-ready` checkpoint.

## Hygiene gate between issues

After each guarded merge, prove all of the following before continuing:

- the pull request merged and its backing issue is closed;
- the merge commit and final PR head are recorded;
- the repository default branch matches its remote;
- the completed issue's branch and worktree are removed, or an exact blocker
  explains why the singular skill retained them;
- `repo-cleanup` Audit passes for the completed issue;
- the active GitHub identity is restored; and
- unrelated dirty files, branches, worktrees, stashes, and recovery state still
  match the preserved baseline or have a documented external change.

`mergepr` owns cleanup of the merged PR's branch and worktree. Do not repeat
its destructive operations. Never run broad cleanup, delete unrelated state,
force-push, bypass protection, or substitute `gh pr merge`.

If this gate fails, stop the queue. Preserve the current state and report the
proof, blocker, and safe next action. Do not continue with later issues while a
batch-created branch, worktree, PR, identity switch, or cleanup failure remains.

## Resume and completion

On every resumed turn, re-read the active Goal, queue, GitHub artifacts, Git
state, and current issue before acting. Live evidence overrides stale notes,
but it does not change the frozen queue. Continue from the first item not proven
merged, skipped, or blocked.

Complete the Goal only when every queued issue is either:

- merged through its exact PR, closed, and cleanup-audited; or
- skipped because live evidence proved it was already closed before its turn
  and no batch artifact exists.

A blocked issue blocks the batch. Do not skip it merely to make progress. Keep
its branch and worktree when the singular skill requires retention, and report
what would unblock the Goal.

## Closeout report

Start the closeout with a user-oriented recap table before technical receipts:

| Issue | What it fixed | What to look for next time |
| --- | --- | --- |

Include one row per selected issue. Link the issue number. In `What it fixed`,
describe the actual behavior or problem in one or two plain-language sentences,
not just the issue title. In `What to look for next time`, name a concrete
screen, workflow, control, visual result, or other observable behavior that
will help the user decide what to inspect when they next open the app, website,
service, or repository. Do not tell the user merely to "test" or "retest."

If an issue has no user-visible behavior, say `No manual check needed` and name
the developer or operational effect worth remembering. If an issue was skipped
or blocked, state that plainly in the same table instead of implying a fix was
delivered. Keep this recap concise enough to scan after a large batch.

After the recap, report the repository, frozen selector and processing order,
active GitHub identity, and one technical receipt row per selected issue with
its final state, issue URL, PR URL, head SHA, merge commit, validation, reviewer
result, and cleanup result. Also report final default-branch and remote SHAs,
remaining unrelated state, and any skipped or blocked item with exact evidence.

## History

After using this skill, append `## HH:MM - {Action Taken}` plus a one-line
summary to `History/{YYYY-MM-DD}.md` in this skill folder. Include whether a
retrospective found a reusable improvement. Take the timestamp from the shell
with `Get-Date -Format "HH:mm"` on Windows or `date +%H:%M` elsewhere, never an
estimate.
