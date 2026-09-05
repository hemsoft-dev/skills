---
name: repo-cleanup
description: "V1.4 - Commands: Audit, Clean. Runs a deterministic PowerShell fast path to commit all pending main-checkout changes, synchronize, push, and remove merged unused local branches; handles retained work separately. Explicit invocation means Clean, automatic use means Audit."
disable-model-invocation: false
compatibility: Requires PowerShell 7 and git. Automatic publication targets HemSoft GitHub repositories with main as the default branch; exceptional PR checks require GitHub CLI.
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

For HemSoft repositories, an explicit Clean authorizes staging all non-ignored
changes, running validation, committing, synchronizing and pushing unprotected
main, and deleting proven-obsolete local state. Follow the PR workflow for shared
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
# Read-only local inventory; does not fetch, stage, commit, or delete.
& "$HOME/.agents/skills/repo-cleanup/scripts/repo-cleanup.ps1" -RepoPath . -Audit

# Same read-only behavior through PowerShell's standard preview switch.
& "$HOME/.agents/skills/repo-cleanup/scripts/repo-cleanup.ps1" -RepoPath . -WhatIf

# Supply a commit message and a repository validation script when needed.
& "$HOME/.agents/skills/repo-cleanup/scripts/repo-cleanup.ps1" -RepoPath . `
  -Message 'chore: publish pending repository work' `
  -ValidationScript ./validate.ps1
```

The script performs these steps in order:

1. Check main, origin ownership/destination, unfinished Git operations, and an
   exclusive guard against another cleanup-script invocation.
2. Verify the remote default branch and fetch once with stale remote refs pruned.
   Stop on pre-existing divergence before staging files.
3. Stage every non-ignored addition, modification, and deletion from the root.
   Check the staged diff and commit once when needed, with normal commit hooks.
4. Fast-forward a clean checkout behind origin. If a dirty checkout was behind,
   replay only its new cleanup commit; abort a conflict and preserve that commit.
5. Run `-ValidationScript`, when provided, against the final tree before pushing.
   Use it for required gates not already covered by commit hooks. It runs under
   PowerShell 7 with the repository as its working directory and must exit nonzero
   or throw on failure. The script does not discover or invent test commands.
6. Push main without force and verify its SHA against the live remote.
7. Remove local branches whose exact tips are ancestors of published main and
   which are not checked out anywhere. Use compare-and-delete against each tip.
8. Return one receipt with SHAs, commit, removed/retained branches, worktrees,
   stashes, remote refs, and elapsed seconds. A clean rerun creates no commit.

`Complete` means the main checkout is clean and published, with no retained
feature refs, linked worktrees, or stashes. `PublishedWithRetainedWork` means main
is published but the listed items still need disposition. A terminating error
means publication or verification did not complete; read the concrete error.
No automatic retry, force push, hook bypass, or stash/drop cycle is performed.

Trust a successful receipt for the checks it covers. Do not repeat fetches,
identity queries, Git inventories, or quality gates without a new change or
failure. Do not run `fsck`, expire reflogs, or force garbage collection on every
cleanup. Git's normal recovery retention is intentional and does not make a
routine cleanup incomplete.

`-LocalRemote` is only for offline tests with a local bare origin. It cannot
authorize a network origin or another GitHub owner.

## Retained work and errors

Handle only the items the receipt or error identifies, then rerun the fast path
once if needed. The script preserves linked worktrees, unique branches, stashes,
remote feature branches, and recovery objects. It never merges an unknown PR.

- For dirty worktrees, inspect ownership and integrate intended changes onto main
  using a clean patch application or the repository PR workflow. Verify content
  on origin/main before clearing the original copy. Preserve active or uncertain
  edits with a named owner, reason, and next step.
- For branch-only commits, check ancestry or patch equivalence and related PR
  state. Integrate intended work; do not assume a squash-merged branch is obsolete
  from its name or age. Merge authority must cover the exact PR.
- For stashes, inspect each patch before applying it in its original context.
  Drop the exact current stash only after its work is verified on origin/main.
- Remove a worktree only when it is clean, inactive, non-primary, and its content
  is integrated. Record its resolved absolute path and expected tip; use
  `git worktree remove` without force. Never recursively delete a worktree.
- Remove a remote feature branch only after ownership, merged PR, absence of later
  work, and fresh exact tip are verified. Use a lease against that tip. Preserve
  another contributor's branches. For other owners, use their repository policy.
- On validation or push failure, fix the actual problem and rerun. Local commits
  and files remain recoverable. Do not hide a conflict, rejected push, or failed
  hook to obtain a clean status.

Never use `git reset --hard`, `git clean`, bulk stash deletion, force push, or
unverified deletion. Do not overwrite active work. Runtime controls still apply;
report an actual rejection with its reason and complete unaffected work.

## Deep audit

Only when explicitly requested, inspect both `git fsck --full --unreachable` and
`git fsck --full --no-reflogs --unreachable`. Recover unique commits onto named
branches. Classify every unreachable commit before removing anything.

For explicit HemSoft deep cleanup, immediate pruning is permitted only after all
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
and preservation of worktrees, unique branches, and stashes.

## History

Before the final cleanup run, append `## HH:MM - {Action Taken}` and a truthful
one-line summary to `History/{YYYY-MM-DD}.md`. Get the timestamp from `Get-Date
-Format "HH:mm"`. Record whether the run revealed a reusable improvement. Include
planned verification as planned, then report the actual result from the receipt;
do not add a redundant history-only commit merely to restate successful checks.
