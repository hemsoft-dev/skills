---
name: resolving-merge-conflicts
description: "Use when you need to resolve an in-progress git merge/rebase conflict."
---

1. **Inspect the state.** Read repository instructions and `git status`.
   Identify the merge/rebase, conflicting paths, and existing staged and
   unstaged work. Preserve unrelated changes.

2. **Establish intent.** Read both changes and their commit history.
   Consult linked PRs or tickets when needed to settle ambiguity.
   During rebase, `ours` is the rebased result so far; `theirs` is the
   commit being replayed.

3. **Resolve conflicts.** Preserve both intents where compatible.
   Follow the stated goal for trade-offs and explain them. Avoid
   unrelated behavior changes. If evidence cannot settle a decision,
   preserve progress and ask. Do not abort or skip commits merely
   to bypass conflicts.

4. **Review and validate.** Stage only resolved paths and required
   integration fixes. Inspect the full staged diff, confirm no
   unmerged entries or accidental conflict markers remain, and run
   repository-prescribed checks. Fix failures caused by the resolution.

5. **Complete the operation.** Use `git merge --continue` or
   `git rebase --continue`, repeating for further conflicts.
   Run required checks on the final result. Report resolutions,
   trade-offs, check results, and final Git status.
