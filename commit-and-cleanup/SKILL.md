---
name: commit-and-cleanup
description: "V1.0 - Commit, push, and cleanup branches/worktrees with git hygiene."
---

# Commit and Cleanup

Commit, push, and cleanup local/remote branches and worktrees.

## Default Behavior

When activated, commit current changes, push, then perform full git hygiene cleanup.

## Workflow

1. **Commit and push** current changes following pre-commit verification
2. **Delete merged branches** — remove local branches that have been merged into main
3. **Delete remote branches** — remove remote branches that have been merged
4. **Clean up worktrees** — remove any stale or orphaned worktrees
5. **Verify clean state** — ensure commit history is clean and organized

## Rules

- Commit messages must be clear, concise, and accurately reflect changes
- Delete only branches confirmed as merged
- Ask before deleting anything ambiguous
- Follow the commit message guidelines in AGENTS.md
