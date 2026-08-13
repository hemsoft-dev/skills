---
name: commit-and-cleanup
description: "V1.3 - Commit, push, and cleanup branches/worktrees/stashes with git hygiene."
version: "1.3"
lastModified: "2026-08-07"
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the commit-and-cleanup directory (path contains 'commit-and-cleanup'), verify that history logging occurred.

            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp

            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if commit-and-cleanup was used (check if any files in commit-and-cleanup directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in commit-and-cleanup directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}"
            3. Ensure the entry includes a one-line summary of what was done
            4. Verify retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
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
