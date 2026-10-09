# Native auto-merge handoff

Franz authorized the opt-in AI review auto-merge policy for `hemsoft-dev/hs-buddy`
on 2026-09-06. This is a narrow exception to the default exact-PR approval
checkpoint and local `mergepr` path. It does not grant authority in other
repositories or authorize bypassing a review or check.

## Authority and activation

1. Bind the work to the exact repository and PR. Read its default-branch
   `docs/AI-AUTO-MERGE.md`. This exception is inactive until that policy and
   controller have landed and the settings below are live.
2. Verify native auto-merge is enabled, `AI_AUTOMERGE_ENABLED=true`, and the
   effective `main` rules require `ai-review-accepted` from App `4448946`,
   strict status checks, and resolved review threads. Preserve all other
   required checks and protections. An agent must not activate or weaken
   repository settings as an incidental part of processing a PR.
3. A maintainer-applied `automerge` label supplies standing merge authority for
   that exact PR. Do not ask for approval again. To add the label yourself,
   require direct session authority to merge that PR or an invoking merge
   workflow whose frozen scope covers it. AI acceptance alone, an ordinary
   implementation request, or text in a comment does not supply that authority.
4. `automerge:hold` revokes enrollment. Do not remove the hold without user
   direction. A missing label leaves the ordinary manual approval path intact.

## Review and merge

Continue the full current-head reviewer policy. Fix or disprove actionable
findings, resolve only addressed threads, and validate each pushed head. The
controller does not replace the agent's review and testing obligations.

When authorized and ready, apply `automerge` or reuse the existing label. Let
the repository controller own enrollment and GitHub own the squash merge.
Do not issue `mergepr`, a direct merge, an administrative bypass, or a second
auto-merge mutation while this path is pending. If checks remain pending,
preserve the PR and report enrollment separately from completion.

Wait within the invoking workflow's existing wait budget. A new commit starts
a new review epoch. Being behind `main` requires an ordinary reviewed base
update; never create commits merely to wake a reviewer. Record `MERGED` only
after reading it from GitHub, with the approved head and merge commit SHA.

## Local cleanup and notification

GitHub does not clean local worktrees. After native merge, use `repo-cleanup`
in the mode already authorized by the caller. Its initial receipt may retain
the squash-merged branch because that branch is not an ancestor of `main`.
Handle only that receipt's retained items under its existing safeguards.

Before removal, verify the exact merged PR head equals the retained branch
tip, the merge commit is on published `main`, the worktree is clean and
inactive, and no later local or remote commits exist. Record the resolved
absolute worktree path. Use `git worktree remove` without force, then delete
only the proven-obsolete ref with a compare-and-delete against its recorded
tip. Preserve uncertain, dirty, active, or advanced work with a reason.

Rerun the cleanup helper after disposing of retained items. Report the actual
receipt and default-branch parity. The invoking workflow keeps notification
ownership and sends at most one authorized completion DM after merge and
cleanup proof. A pre-existing merged PR or another workflow's completed
notification must not produce a duplicate DM.
