---
name: merge-pr
description: V1.3 - Merge one or more explicitly selected GitHub pull requests from oldest to newest, cleaning the repository between each merge and sending one final Slack notification per successful merge.
disable-model-invocation: true
compatibility: Requires git, GitHub CLI, GitHub access, mergepr on PATH, the repo-cleanup skill, and the slack-dm skill.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the merge-pr directory (path contains 'merge-pr'), verify that history logging occurred.

            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp obtained with Get-Date -Format "HH:mm"

            If history is missing or incomplete, state what must be added. Otherwise acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if merge-pr was used, verify that History/{YYYY-MM-DD}.md contains an accurate "## HH:MM - {Action Taken}" entry and a one-line summary. Obtain the time with Get-Date -Format "HH:mm". Block completion if the entry is missing.
---

# Merge PRs

Invoke from any checkout of the target repository. Supported selectors are:

- one PR: `$merge-pr 42`
- several PRs: `$merge-pr 42 47 51` or `$merge-pr 42,47,51`
- an inclusive range: `$merge-pr 42-51`
- a mixture: `$merge-pr 42,47-49 51`

## Authorization

The invocation directly authorizes merging only the expanded set of pull request numbers in the current repository. It also authorizes an admin merge when the guarded fallback below permits it and authorizes `repo-cleanup Clean` after each selected PR. Never reuse this authority for another PR or repository.

Accept positive integers, comma-separated values, and inclusive `N-M` ranges. Normalize descending ranges, remove duplicates, and reject malformed or empty selectors. Before changing anything, expand the complete set and verify that every number resolves to a pull request, not an issue. If any selector is invalid, stop without merging any PR.

"Oldest" means the earliest GitHub `createdAt` timestamp among the selected PRs. Sort by `createdAt` ascending, then by PR number ascending when timestamps match. Do not use numeric order as a substitute for creation time.

## Reviewer policy

Read `../process-pr/references/pr-reviewer-policy.md` before evaluating review
readiness. Use its required reviewer set and current-head evidence rules.
If review processing is needed, hand the exact PR and existing requests to
`../process-pr/SKILL.md`; preserve this skill's merge and notification ownership.
Do not add optional reviewers, duplicate requests, or restart refused waits.

## Workflow

1. Resolve the repository from `git remote get-url origin`, the primary checkout from `git worktree list --porcelain`, the active GitHub login, and the default branch. Read the repository's applicable `AGENTS.md` instructions.
2. Expand and validate the full selector set. Read each PR's `number`, `createdAt`, title, URL, state, draft state, base branch, head branch, and head SHA. Sort the selected PRs by `createdAt`, then number. Show the resolved order before the first merge.
3. Process each PR in that fixed order. Refresh its live state, mergeability, merge state, reviews, review threads, checks, and exact head SHA immediately before deciding whether it can merge.
4. Mark the current PR `BLOCKED` without merging when it is closed without merge, is a draft, has conflicts, has failing or pending required checks, lacks a current-head review required by the shared policy or repository, or changed head after validation. Use the shared policy for reviewer selection; installed optional bots do not add requirements. Continue to step 7 so cleanup runs before the next selected PR.
5. From the clean primary checkout, run `mergepr {PR_NUMBER}`. Do not run it from a linked PR worktree that it may remove.
6. If `mergepr` returns an error, re-read the PR before deciding what happened:
   - If GitHub reports it merged, continue to cleanup.
   - If it remains open and otherwise satisfies step 4, use `gh pr merge {PR_NUMBER} --squash --delete-branch --admin` only when the normal merge was refused by branch protection, merge queue policy, or an equivalent administrative gate.
   - Never use `--admin` to override conflicts, draft state, test failures, pending required checks, missing required current-head review, or a changed head.
7. Re-read the PR. Record `MERGED`, `BLOCKED`, `SKIPPED_ALREADY_MERGED`, or `FAILED`, whether the admin fallback ran, and the merge commit SHA when present. A PR already merged before this invocation is a no-op and must not trigger a duplicate Slack notification.
8. Invoke the `repo-cleanup` skill in `Clean` mode from the primary checkout after every selected PR, including a blocked, failed, or already-merged item. If the current PR remains open, classify its branch and worktree as `KEEP`. Cleanup must preserve unrelated or uncertain work.
9. Do not start the next PR until cleanup proves the primary checkout is clean on the default branch and matches `origin/{DEFAULT_BRANCH}`. If cleanup cannot reach that safe state, stop the batch and report the remaining PRs as `NOT_ATTEMPTED`.
10. For each PR newly proven `MERGED`, invoke the `slack-dm` skill at `../slack-dm/SKILL.md` after cleanup. Send Franz one `merged` DM with the canonical `OWNER/REPO` project, `PR #<number> - <exact current title> - merged` outcome, PR URL, merge commit, merge method, and cleanup result. Do not send a merged notification for blocked, failed, already-merged, or not-attempted items.
11. After the last PR, prove the final repository state. Report the ordered input set and one result per PR, including URL, exact reviewed head, state, merge commit, merge method, admin-fallback use, cleanup result, and retained work. Also report primary branch cleanliness, `HEAD == origin/{DEFAULT_BRANCH}`, and ahead/behind counts.

## History

After using or modifying this skill, append `## HH:MM - {Action Taken}` and a one-line summary to `History/{YYYY-MM-DD}.md`. State whether a retrospective found a reusable improvement. Get the time from `Get-Date -Format "HH:mm"`, never from an estimate.
