---
name: merge-pr
description: V1.0 - Merge one explicitly numbered GitHub pull request, use an admin merge only when a validated PR is blocked by repository policy, then run repository cleanup.
disable-model-invocation: true
compatibility: Requires git, GitHub CLI, GitHub access, mergepr on PATH, and the repo-cleanup skill.
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

# Merge PR

Invoke as `$merge-pr {PR_NUMBER}` from any checkout of the target repository.

## Authorization

The invocation directly authorizes merging only the numbered pull request in the current repository. It also authorizes an admin merge when the guarded fallback below permits it and authorizes `repo-cleanup Clean` in that repository. Never reuse this authority for another PR or repository.

Require one positive integer. Verify that it resolves to a pull request, not an issue, before changing anything.

## Workflow

1. Resolve the repository from `git remote get-url origin`, the primary checkout from `git worktree list --porcelain`, the active GitHub login, and the default branch. Read the repository's applicable `AGENTS.md` instructions.
2. Read the PR with GitHub CLI. Record its URL, state, draft state, base branch, head branch, exact head SHA, mergeability, merge state, reviews, review threads, and checks.
3. Stop before merging when the PR is closed without merge, is a draft, has conflicts, has failing or pending required checks, lacks a repository-required current-head review, or changed head after validation. Do not invent review requirements the repository does not have.
4. From the clean primary checkout, run `mergepr {PR_NUMBER}`. Do not run it from a linked PR worktree that it may remove.
5. If `mergepr` returns an error, re-read the PR before deciding what happened:
   - If GitHub reports it merged, continue to cleanup.
   - If it remains open and otherwise satisfies step 3, use `gh pr merge {PR_NUMBER} --squash --delete-branch --admin` only when the normal merge was refused by branch protection, merge queue policy, or an equivalent administrative gate.
   - Never use `--admin` to override conflicts, draft state, test failures, pending required checks, missing required current-head review, or a changed head.
6. Re-read the PR and require `MERGED` before reporting merge success. Record whether the admin fallback ran and capture the merge commit SHA.
7. After the merge attempt, invoke the `repo-cleanup` skill in `Clean` mode from the primary checkout. If the merge failed, classify the open PR branch and worktree as `KEEP`; cleanup must preserve them.
8. Prove the final repository state. Report the PR URL and state, exact reviewed head, merge commit, merge method, admin-fallback use, cleanup actions, retained work, primary branch cleanliness, `HEAD == origin/{DEFAULT_BRANCH}`, and ahead/behind counts.

## History

After using this skill, append `## HH:MM - {Action Taken}` and a one-line summary to `History/{YYYY-MM-DD}.md`. Get the time from `Get-Date -Format "HH:mm"`, never from an estimate.
