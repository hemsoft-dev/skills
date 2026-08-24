---
name: repo-cleanup
description: "V1.2 - Commands: Audit, Clean. Use automatically whenever repository work finishes, a pull request merges, or the user asks to clean, tidy, synchronize, or return a Git repository to main; preserve and integrate uncommitted, unpushed, stashed, and branch-only work before removing obsolete branches and worktrees."
disable-model-invocation: false
compatibility: Requires git. Remote ownership and pull request checks require GitHub CLI, GitHub access, and permission to fetch or delete refs.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the repo-cleanup directory, verify that History/{YYYY-MM-DD}.md contains an entry for this interaction in this format:

            ## HH:MM - {Action Taken}
            {One-line summary}

            Get the timestamp from `Get-Date -Format "HH:mm"`, never from an estimate. If the entry is missing or incomplete, state exactly what must be added.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if repo-cleanup was used or modified, verify both requirements:

            1. History/{YYYY-MM-DD}.md contains an accurate `## HH:MM - {Action Taken}` entry with a one-line summary.
            2. A brief retrospective checked whether this run revealed a reusable improvement to the skill. If so, update the skill and record the update in history; otherwise record that no skill change was needed.

            Obtain the timestamp with `Get-Date -Format "HH:mm"`. Block completion when either requirement is missing.
---

# Repository cleanup

Leave one repository on clean, current `main` without losing unfinished work. Inventory first, integrate intended work, remove only proven obsolete state, and report anything retained.

## Commands

- `Audit` inventories and classifies state. It may fetch remote refs, but it does not commit, push, delete, drop, or remove anything.
- `Clean` performs the full workflow. Use it when the user asks to clean, tidy, synchronize, return to `main`, or clean up after a merge.

Automatic skill loading is not deletion permission. If the skill triggers only because work finished, run `Audit`. Run `Clean` only when the user requested cleanup in the current conversation. Approval to merge one pull request permits cleanup of that pull request's branch and worktree only. Broader repository cleanup needs a broader cleanup request.

If `mergepr` already cleaned the approved pull request, verify its result instead of repeating the deletion.

## Safety rules

- Work on one resolved repository root. Read its `AGENTS.md` and repository instructions first.
- This skill targets `main`. Confirm that `origin/main` exists and that GitHub reports `main` as the default branch. If either check fails, stop and ask whether to use the actual default branch.
- Treat uncommitted files, untracked files, unpushed commits, stashes, reflogs, and unreachable commits as work until evidence proves otherwise.
- Do not use `git reset --hard`, `git clean`, `git stash clear`, bulk branch deletion, force-push, or recursive filesystem deletion.
- Never delete the primary checkout. Never remove a dirty worktree or a branch checked out in any worktree.
- Run destructive commands one item at a time. Record the exact path or ref and expected SHA before each command, then verify the result.
- Do not bypass branch protection or repository-required validation. Do not commit secrets, credentials, generated output, ignored dependencies, or unrelated changes merely to make the tree clean.
- Preserve uncertain work and report the blocker. A smaller cleanup with no data loss is a valid outcome.

## Resolve repository family and identity

Determine the repository from `origin`, not the directory name. Record the GitHub owner, repository, authenticated login, configured Git author name and email, and default branch.

Use these policies:

| Repository owner | Policy |
| --- | --- |
| `HemSoft` | Franz is the sole routine contributor. Local branches and remote branches proven to be his are cleanup candidates when no ongoing work remains. Preserve any remote branch that is not proven to be his. An explicit `Clean` request also authorizes immediate removal of proven-obsolete unreachable objects after the concurrency checks below pass. |
| `relias-engineering` | Treat the repository as shared. Never delete another person's remote branch. Delete Franz's remote branch only when its pull request merged, the remote tip still matches the recorded pull request head, and no later work exists. Route new work through the repository's pull request process instead of pushing directly to `main`. |
| Any other owner | Preserve remote branches unless the user supplies an ownership and deletion policy. |

Prove branch ownership with an authenticated GitHub login plus at least one strong signal: the related pull request author and head ref, a local branch and reflog tied to the work, or a direct user statement. Commit author, branch-name style, or recency alone is not proof.

## Inventory before changing anything

Fetch current refs, then capture the baseline:

```powershell
git rev-parse --show-toplevel
git remote -v
git fetch origin --tags
git remote prune --dry-run origin
git status --porcelain=v2 --branch
git branch -vv
git for-each-ref --sort=-committerdate --format='%(refname:short)%09%(objectname)%09%(upstream:short)%09%(upstream:track)%09%(committerdate:iso8601)' refs/heads refs/remotes/origin
git worktree list --porcelain
git stash list --format='%gd%x09%H%x09%ci%x09%gs'
git reflog --all --date=iso
git fsck --full --no-reflogs --unreachable
git fsck --full --unreachable
gh auth status
gh api user --jq .login
gh repo view --json nameWithOwner,defaultBranchRef
```

For every worktree, run `git -C {WORKTREE_PATH} status --porcelain=v2 --branch`. For every local and remote feature branch, record:

- tip SHA, upstream, worktree path, and ahead/behind counts from `git rev-list --left-right --count origin/main...{BRANCH}`;
- commits and file changes absent from `origin/main`;
- whether the same patch is already on `origin/main`, including squash merges;
- related pull request state, author, base, head SHA, merge commit, and current head ref;
- related open issue, recent push or review activity, stash base, or other evidence of ongoing work.

Inspect each stash with `git stash show --stat --include-untracked {STASH}` and `git stash show -p --include-untracked {STASH}`. Refresh the stash list after every drop because stash indexes move.

For squash-merge cases, compare patches with `git cherry origin/main {BRANCH}` and, when needed, stable patch IDs. Commit messages and matching filenames are not proof.

Compare the commit lines from both `git fsck` runs. A commit reported only with `--no-reflogs` is still protected by a reflog. A commit reported by both runs is truly unreachable and needs manual relevance review. Ignore blob and tree noise unless it belongs to a commit being recovered.

Classify every item as `INTEGRATE`, `KEEP`, `DELETE`, or `BLOCKED`, with evidence. Age alone never makes an item deletable.

## Decide whether work is ongoing

Keep an item when any of these apply:

- its worktree is dirty or another process or agent may be using it;
- it has an open or draft pull request, an open linked issue, pending review, or active checks;
- it contains commits or a patch not present on `origin/main`;
- it is ahead of or has diverged from its upstream and its purpose is unresolved;
- a stash, reflog entry, or unreachable commit contains unique work;
- remote branch ownership is unknown or belongs to someone else;
- a closed, unmerged pull request still contains work whose disposition is unclear.

A local branch is a deletion candidate when it has no worktree, no dirty state, no unique work, and either Git ancestry proves it merged into `origin/main` or a merged pull request proves its exact recorded head was integrated with no later commits.

A remote branch is a deletion candidate only when family policy permits it, ownership is proven, no open work depends on it, and a fresh remote SHA still matches the SHA that was audited.

## Preserve and integrate work

Handle each independent change separately. Do not sweep unrelated files into one cleanup commit.

1. Inspect staged, unstaged, and untracked files. Separate intended source changes from generated files, dependencies, caches, logs, build output, and secrets.
2. Preserve dirty work before switching branches. Use its existing branch when the purpose is clear. Otherwise create an intentionally named preservation branch and isolated worktree.
3. Inspect stashes without popping them. Apply a relevant stash in an isolated worktree based on its original base, resolve it, validate it, and commit it. Drop the stash only after the resulting commit is safely integrated.
4. Recover relevant unreachable commits onto a named branch before any pruning.
5. Run the repository's declared quality gates for each change. Inspect hook-created changes and final Git identity before committing.
6. For `HemSoft`, commit and push intended work to `main` only when the current cleanup request authorizes that write, repository policy permits direct `main` updates, validation passes, and the update is fast-forward safe. Otherwise use the repository's pull request workflow.
7. For `relias-engineering`, push the feature branch and use the repository's pull request workflow. Do not push new work directly to `main`.
8. Do not call work integrated until it is present on `origin/main`. An open pull request or preserved branch is `KEEP`, not completed cleanup. Report any approval or review needed to finish it.

Never drop the last copy of work. Before deleting its source ref, prove the exact commits or equivalent patch are on `origin/main`, or preserve them under a named branch approved by the user.

## Remove obsolete state

Re-fetch immediately before deletion and compare the live SHA with the audited SHA. If it changed, stop and reclassify it.

Use this order for each item:

1. Remove a clean, non-primary worktree with `git worktree remove {EXACT_PATH}`.
2. Verify the worktree registration disappeared. If Windows leaves ignored files behind, verify the exact directory is the former worktree, contains no `.git` metadata or unique files, and is outside the primary checkout. Move only that directory to the Recycle Bin.
3. Delete the local branch with `git branch -d {BRANCH}`. Use `-D` only when a squash-merged pull request or patch-equivalence proof satisfies every deletion condition and the cleanup request authorizes it.
4. Delete an allowed remote branch with `git push --force-with-lease="refs/heads/{BRANCH}:{EXPECTED_SHA}" origin ":refs/heads/{BRANCH}"`, one ref at a time. Never delete another author's remote branch.
5. Drop one stash only after its content is on `origin/main` or exact comparison proves it is a duplicate. Record its object ID first.
6. Run `git worktree prune --dry-run` and `git remote prune --dry-run origin`. Run the corresponding commands without `--dry-run` only after inspecting what they will remove.

For a `HemSoft` `Clean`, remove unreachable recovery objects during the same cleanup when every unreachable commit is classified `DELETE`, `main` is safely on `origin/main`, no Git process is writing objects, and no Git lock file exists. Git's normal expiry depends on time limits and garbage-collection triggers, so waiting for it is not proof of cleanup.

Run the dry-runs first:

```powershell
git prune --dry-run --expire=now
```

For each audited `reflog-only` commit, locate every exact reflog selector that names it with `git reflog show --all --format='%gD%x09%H%x09%gs'`. Delete only those selectors with `git reflog delete --dry-run --rewrite '{REF}@{INDEX}'` first. Process numeric indexes from highest to lowest within each ref so later selectors do not shift before use. Do not use a repository-wide `git reflog expire --expire-unreachable=now --all` as a shortcut because it may remove unrelated recovery history.

If the exact reflog deletions and prune dry-run contain only audited obsolete work, run each approved `git reflog delete --rewrite '{REF}@{INDEX}'`, then run:

```powershell
git gc --prune=now
```

Immediate pruning is irreversible and Git warns that `--prune=now` can corrupt a repository when another process is writing objects. Do not run it while a commit, fetch, receive, index-pack, maintenance job, or another object-writing Git command is active. Do not accelerate reflog or object expiry in `relias-engineering`, another shared repository, or any repository with uncertain work unless the user separately authorizes that exact cleanup after reviewing the audit.

## Final proof

Return the primary checkout to `main`, then verify live state:

```powershell
git switch main
git pull --ff-only origin main
git status --porcelain=v2 --branch
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git branch -vv
git worktree list --porcelain
git stash list
git ls-remote --heads origin
git fsck --full --no-reflogs --unreachable
git fsck --full --unreachable
git count-objects -vH
```

Report:

- repository, family, GitHub login, Git author, and exact `main` and `origin/main` SHAs;
- every uncommitted file, unpushed commit, stash, local branch, remote branch, worktree, and unreachable commit found;
- the `INTEGRATE`, `KEEP`, `DELETE`, or `BLOCKED` decision and evidence for each;
- validation, commits, pushes, pull requests, deletions, and retained work;
- final cleanliness, ahead/behind count, remaining stashes, worktrees, local branches, and remote branches.

Cleanup is complete when `main` is clean and matches `origin/main`, all intended work is on `origin/main` or explicitly retained with a named owner and next step, no proven-obsolete local state remains, and every remaining remote branch has evidence of ongoing work or a documented ownership precaution. A completed `HemSoft` `Clean` also has no audited-obsolete commit reported by either final `git fsck` command.

## History

After using this skill, append `## HH:MM - {Action Taken}` plus a one-line summary to `History/{YYYY-MM-DD}.md` in this skill folder. Note whether a retrospective found a reusable improvement. Get the timestamp from `Get-Date -Format "HH:mm"`, never from an estimate.
