---
name: commit-and-cleanup
description: "V1.1 - Commit, push, and cleanup branches/worktrees/stashes with git hygiene."
version: "1.1"
lastModified: "2026-05-03"
---

# Commit and Cleanup

Commit, push, and cleanup local/remote branches, worktrees, and stashes.

## Default Behavior

When activated, commit current changes, push, then perform full git hygiene cleanup.

## Workflow

1. **Commit and push** current changes following pre-commit verification
2. **Delete merged branches** — remove local branches that have been merged into main
3. **Delete remote branches** — remove remote branches that have been merged
4. **Clean up worktrees** — remove any stale or orphaned worktrees
5. **Clear stashes** — drop stashes from deleted or merged branches; clear all if
   no active feature branches remain
6. **Verify clean state** — ensure commit history is clean and organized

## Rules

- Commit messages must be clear, concise, and accurately reflect changes
- Delete only branches confirmed as merged
- Clear stashes whose parent branch no longer exists
- Ask before deleting anything ambiguous
- Follow the commit message guidelines in AGENTS.md
