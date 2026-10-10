---
name: repo-cleanup
description: "V1.7 - Commands: Audit, Clean. Checks gh x status, publishes pending main work, and attempts cleanup of every local/remote branch, linked worktree, and stash with verified content and ownership. Explicit invocation means Clean, automatic use means Audit."
compatibility: Requires PowerShell 7, git, authenticated GitHub CLI, and gh-x with status --refresh. Automatic publication targets HemSoft and hemsoft-dev GitHub repositories with main as the default branch.
---

# Repository cleanup

Use `scripts/repo-cleanup.ps1` first. Routine cleanup should be one script run,
not an agent rebuilding the Git workflow command by command.

## Commands

- A direct `$repo-cleanup` invocation means `Clean` unless Franz asks for `Audit`.
- Automatic loading because work finished means `Audit` unless the current
  workflow or user already authorizes cleanup.
- `Deep audit` additionally inspects recovery objects. It is not a prerequisite
  for ordinary cleanup.

## Authority

Franz's 2026-09-05 instruction authorizes repository-wide cleanup, including
intended work from earlier tasks and other sessions. His follow-up explicitly
requests a deterministic script that commits and pushes all uncommitted changes.
For this workflow, one commit containing all pending main-checkout changes is
intentional. Do not split it by task, create preservation worktrees, or ask again
solely because files are unrelated, include skill instructions, or were discovered
later. Honor explicit exclusions and active ownership conflicts.

For HemSoft and hemsoft-dev repositories, an explicit Clean authorizes staging all non-ignored
changes, running validation, committing, synchronizing and pushing unprotected
main, and deleting proven-obsolete local and remote branches, worktrees, and stashes. Follow the PR workflow for shared
repositories or protected branches. Never bypass hooks or server protections.

The script does not inspect file contents for secrets or infer whether another
agent is still editing. Before running it, read repository instructions, inspect
the pending diff once, and resolve any actual secret, generated-file, explicit
exclusion, or active-edit problem. Ordinary intended changes need no extra gate.

## Fast path

Record any required skill history before running cleanup. Resolve the checkout
on `main` using `git worktree list --porcelain` if the current checkout is on a
feature branch. Run from that main checkout:

```powershell
& "$HOME/.agents/skills/repo-cleanup/scripts/repo-cleanup.ps1" -RepoPath .
```

Optional arguments:

```powershell
# Read-only local inventory; also run gh x status --refresh from this checkout.
# Does not fetch, stage, commit, or delete.
& "$HOME/.agents/skills/repo-cleanup/scripts/repo-cleanup.ps1" -RepoPath . -Audit

# Same read-only behavior through PowerShell's standard preview switch.
& "$HOME/.agents/skills/repo-cleanup/scripts/repo-cleanup.ps1" -RepoPath . -WhatIf

# Supply a commit message and a repository validation script when needed.
& "$HOME/.agents/skills/repo-cleanup/scripts/repo-cleanup.ps1" -RepoPath . `
  -Message 'chore: publish pending repository work' `
  -ValidationScript ./validate.ps1

# Preserve needed release/evidence refs both locally and remotely.
& "$HOME/.agents/skills/repo-cleanup/scripts/repo-cleanup.ps1" -RepoPath . `
  -PreserveBranch 'release/1.4.0-rc-54b2a48'

# After verifying inactivity and ownership, permit eligible cleanup.
& "$HOME/.agents/skills/repo-cleanup/scripts/repo-cleanup.ps1" -RepoPath . `
  -InactiveWorktree '/absolute/path/to/inactive-worktree' `
  -OwnedBranch 'obsolete-owned-branch'
```

The script commits with `git commit -m $Message` exactly as given. When the
session requires commit trailers (for example `Co-Authored-By:`), pass a
multi-line `-Message` that ends with them; the default message has none.

Fetch and push may use different recognized transports for the same approved
HemSoft or hemsoft-dev repository. Preserve both URLs and all other native settings. Reject
different repositories, unknown transport equivalence, and multiple push URLs.

Before Clean, inspect all worktree owners and explicitly preserve needed release
or evidence refs. `-InactiveWorktree` records a verified inactive absolute path;
it does not override dirty, ignored-file, lock, or integration safeguards.
`-OwnedBranch` records verified ownership of an origin branch without a merged
PR; it never overrides an open PR, later work, or a preserved ref. Do not infer
ownership or inactivity from age or a branch name.

The script performs these steps in order:

1. Check main, origin ownership/destination, unfinished Git operations, and an
   exclusive guard against another cleanup-script invocation.
2. Run `gh x status --refresh` in the repository and retain its actual output.
   Missing CLI/extension, failed auth, or a failed status command stops Clean
   before any Git mutations. Obtain current-user and paginated PR evidence.
3. Verify the remote default branch and fetch once with stale remote refs pruned.
   Stop on pre-existing divergence before staging files.
4. Stage every non-ignored addition, modification, and deletion from the root.
   Check the staged diff and commit once when needed, with normal commit hooks.
5. Fast-forward a clean checkout behind origin. If a dirty checkout was behind,
   replay only its new cleanup commit; abort a conflict and preserve that commit.
6. Run `-ValidationScript`, when provided, against the final tree before pushing.
   Use it for required gates not already covered by commit hooks. It runs under
   PowerShell 7 with the repository as its working directory and must exit nonzero
   or throw on failure. The script does not discover or invent test commands.
7. Push main without force and verify its SHA against the live remote.
8. Assess every linked worktree. Remove only clean, unlocked, confirmed inactive
   worktrees whose exact tips are integrated and which contain no ignored files.
   Verify both directory removal and removal of registration.
9. Inspect every stash's working, staged, and untracked layers. Drop individual
   exact-OID stashes only when every changed path, blob, and mode matches published
   main. Preserve unique content. Never bulk-clear or apply/drop to test a stash.
10. Query live branch refs on every configured remote. Remove eligible origin
    refs only after ownership, integration, no open PR, and exact tip are verified.
    Use an exact-tip lease for deletion; never rewrite remote history. Classify
    other remotes without assuming their ownership or publication policy.
11. Remove integrated unused local refs using compare-and-delete. Integration
    means tip ancestry, or the exact merged PR head and its published merge commit
    for squash/rebase merges. Preserve unique, active, and explicitly needed work.
12. Run `gh x status --refresh` again and retain its output. Return before/after
    status evidence and per-item dispositions, reasons, SHAs, and elapsed seconds.
    A clean rerun creates no commit.

`Complete` means the main checkout is clean and published, with no retained
feature refs, linked worktrees, or stashes. `PublishedWithRetainedWork` means main
is published but the listed items still need disposition. A terminating error
means publication or verification did not complete; read the concrete error.
`PublishedGitHubVerificationIncomplete` means publication finished but the final
GitHub status command failed. Do not declare cleanup verified until it succeeds.
A successful status command means its output was captured, not that every CI job
or PR shown is healthy. Report failed, pending, or unavailable checks truthfully;
do not merge unknown PRs, trigger reviews, or dispatch CI just to make status green.
Audit/WhatIf remain a local read-only script preview; the agent also runs
`gh x status --refresh` when auditing a GitHub repository and reports failure.
No automatic retry, history rewrite, hook bypass, or stash/apply cycle is performed.

Trust a successful receipt for the checks it covers. Do not repeat fetches,
identity queries, Git inventories, or quality gates without a new change or
failure. Do not run `fsck`, expire reflogs, or force garbage collection on every
cleanup. Git's normal recovery retention is intentional and does not make a
routine cleanup incomplete.

`-LocalRemote` is only for offline tests with a local bare origin. It cannot
authorize a network origin or another GitHub owner.

## Retained work and errors

For a PR merged by GitHub native auto-merge, use the local cleanup section in `../process-pr/references/native-auto-merge.md`. Enrollment is not merge proof. A squash-merged branch may remain in the first receipt; verify the exact merged head and published merge commit before disposing of its clean, inactive worktree and unchanged refs. The existing caller still owns the cleanup scope and any completion DM.

Handle every item the receipt or error identifies, then rerun after resolving
eligible items. It never merges an unknown PR or prunes normal recovery objects.

A `PublishedWithRetainedWork` receipt is not a finished Clean. In the same run,
triage every retained item: compare stash and branch tips (a stash is often
duplicated by a `preserve/*` branch), compare LFS pointer oids against main, and
check whether later main commits replaced the item. Dispose of anything proven
integrated. Continue the same Clean through all safe, authorized actions. Report genuinely
needed work with its owner, reason, and next step. If disposition requires a new
choice, bundle only those choices with a recommendation for each. Do not stop at
counts or ask again for already-authorized cleanup. Include final local/remote
branch, worktree, and stash counts from both the receipt and fresh `gh x status`.

- For dirty worktrees, inspect ownership and integrate intended changes onto main
  using a clean patch application or the repository PR workflow. Verify content
  on origin/main before clearing the original copy. Preserve active or uncertain
  edits with a named owner, reason, and next step.
- For branch-only commits, check ancestry or patch equivalence and related PR
  state. Integrate intended work; do not assume a squash-merged branch is obsolete
  from its name or age. Merge authority must cover the exact PR.
- For stashes, inspect each patch before applying it in its original context.
  Drop the exact current stash only after every useful layer is verified on origin/main.
  Check duplicate preserve branches and later replacements as additional evidence;
  a matching working file alone does not prove staged or untracked work is redundant.
- Remove a worktree only when it is clean, inactive, non-primary, and its content
  is integrated. Record its resolved absolute path and expected tip; use
  `git worktree remove` without force. Never recursively delete a worktree.
  A failed removal can unregister the worktree while leaving files behind.
  The receipt will not list that unregistered directory. Record its absolute
  path and preserve it for separate disposition; disappearance from the
  worktree inventory is not proof that its files were removed.
- Before removing any worktree, list its ignored content with
  `git -C <worktree> status --porcelain --ignored`. `git worktree remove`
  deletes ignored files without warning, and folders such as `Saved/` can hold
  the only copy of evaluation projects or source exports; a 2026-10-03 cleanup
  lost #153's MetaHuman project this way. Preserve or explicitly dispose of
  anything beyond rebuildable caches (`Binaries/`, `Intermediate/`, `DerivedDataCache/`).
- To reach a main-only state with unpublished work the owner wants kept but not
  pushed, archive it outside the repository. Write a `git bundle` of
  `main..<branch>`, copy the uncommitted files, and also copy the branch's
  objects from `.git/lfs/objects`, because a bundle holds only LFS pointers.
  Verify everything by hash and add restore instructions before removing the
  worktree and branch.
- Remove a remote feature branch only after ownership, merged PR, absence of later
  work, and fresh exact tip are verified. Use a lease against that tip. Preserve
  another contributor's branches. For other owners, use their repository policy.
- On validation or push failure, fix the actual problem and rerun. Local commits
  and files remain recoverable. Do not hide a conflict, rejected push, or failed
  hook to obtain a clean status.

Never use `git reset --hard`, `git clean`, bulk stash deletion, history-rewriting force push, or
unverified deletion. Do not overwrite active work. Runtime controls still apply;
report an actual rejection with its reason and complete unaffected work.

## Deep audit

Only when explicitly requested, inspect both `git fsck --full --unreachable` and
`git fsck --full --no-reflogs --unreachable`. Recover unique commits onto named
branches. Classify every unreachable commit before removing anything.

For explicit HemSoft or hemsoft-dev deep cleanup, immediate pruning is permitted only after all
unreachable commits are proven obsolete, main is published, and no Git writer or
lock exists. Dry-run `git prune --dry-run --expire=now`. If obsolete commits are
reflog-only, dry-run and remove their exact reflog selectors in descending numeric
index order within each ref. Do not globally expire reflogs. Then, and only then,
run `git gc --prune=now` and verify both fsck outputs. Count commits, reflog records,
and Git objects separately. Shared repositories require their own authorization.

## Verification of this helper

```powershell
Invoke-Pester -Path "$HOME/.agents/skills/repo-cleanup/tests/RepoCleanup.Tests.ps1" -Output Detailed
```

The tests use isolated local bare remotes and cover all-change publication,
idempotence, previews, hook/push failures, synchronization, conflicts, divergence,
remote deletion, inactive worktree removal, ignored-file protection, all stash
layers, status command failures, and preservation of unique or protected work.

## History

Before the final cleanup run, append `## HH:MM - {Action Taken}` and a truthful
one-line summary to `History/{YYYY-MM-DD}.md` in this skill's directory
(`$HOME/.agents/skills/repo-cleanup/History/`), never in the target repository.
Get the timestamp from `Get-Date
-Format "HH:mm"`. Record whether the run revealed a reusable improvement. Include
planned verification as planned, then report the actual result from the receipt;
do not add a redundant history-only commit merely to restate successful checks.
