---
name: commit-and-cleanup
description: "V1.2 - Commit, push, and cleanup branches/worktrees/stashes with git hygiene."
version: "1.2"
lastModified: "2026-05-04"
---

# Commit and Cleanup

Commit, push, and cleanup local/remote branches, worktrees, and stashes.

## Default Behavior

When activated, commit current changes, push, then perform full git hygiene cleanup.

## Workflow

1. **Commit and push** current changes following pre-commit verification
2. **Delete merged branches** — remove local branches that have been merged into main
3. **Delete remote branches** — remove remote branches that have been merged
4. **Clean up worktrees** — remove any stale or orphaned worktrees (see below)
5. **Clear stashes** — drop stashes from deleted or merged branches; clear all if
   no active feature branches remain
6. **Verify clean state** — ensure commit history is clean and organized

## Worktree Cleanup (detailed)

`git worktree list` only shows worktrees registered to the current repo. That
misses orphaned directories on disk. Perform all three checks:

1. **Registered worktrees** — run `git worktree list` and prune any that point
   to missing directories (`git worktree prune`).
2. **Sibling `.worktrees` directories** — scan the parent directory for folders
   matching `<repo>.worktrees/`. For each subdirectory inside:
   - If the branch it tracks has been merged → offer to remove the worktree
     directory and run `git worktree remove` from the main repo.
   - If the branch is unmerged → leave it alone, report it as active.
   - If the `.worktrees` folder is empty → delete the empty directory.
3. **Orphaned worktree directories** — scan the parent directory for folders
   whose name suggests they were a worktree (e.g., `<repo>-worktree-*`) but
   are no longer a valid git repository (no `.git` file/folder, or
   `git rev-parse` fails). These are safe to remove after confirmation.

Always ask before deleting worktree directories unless they are clearly empty
or orphaned (not a git repo at all).

## Rules

- Commit messages must be clear, concise, and accurately reflect changes
- Delete only branches confirmed as merged
- Clear stashes whose parent branch no longer exists
- Ask before deleting anything ambiguous
- Follow the commit message guidelines in AGENTS.md
