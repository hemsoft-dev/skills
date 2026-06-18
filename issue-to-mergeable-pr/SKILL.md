---
name: issue-to-mergeable-pr
description: V1.1 - Turns the oldest GitHub Issue into a clean branch and PR, then iterates with repo-appropriate automated PR review until the PR is merge-ready.
compatibility: Requires git, GitHub CLI authentication, network access, and a GitHub repository with Issues and Pull Requests enabled.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the issue-to-mergeable-pr directory (path contains 'issue-to-mergeable-pr'), verify that history logging occurred.

            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)

            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if issue-to-mergeable-pr was used (check if any files in issue-to-mergeable-pr directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in issue-to-mergeable-pr directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Issue to Mergeable PR

Use this skill when asked to turn the oldest GitHub Issue into a pull request, or to continue the oldest open pull request until it is ready to merge.

## Goal Start

Start by creating a Codex goal. If a goal tool is available, create the goal with this objective. If only slash commands are available, ask the user to run the slash command exactly.

```text
/goal Take the oldest GitHub Issue and create a branch for it, work the issue to the best of your ability and create a PR. Request the repo-appropriate automated PR review product, wait for feedback, address comments, and keep requesting review until you are confident all issues have been addressed and the repo's required review signal is satisfied. Make sure you have good worktree/branch hygiene. Don't start on dangling branches and clean up before and after yourself.
```

Before branching, deduplicate the open issue queue and separate overlapping scope so the PR implements one clear, non-overlapping issue. The goal is achieved when the PR is ready to merge with the repo-specific automated review signal and no unresolved substantive feedback. Do not merge unless the user explicitly asks for merge.

## Preflight

1. Verify repository context: `git rev-parse --show-toplevel`, `git remote -v`, and `gh repo view`.
2. Check worktree hygiene before editing: `git status --short --branch`, `git branch --show-current`, `git worktree list`, and `git fetch --prune`.
3. Do not start from a dangling, stale, detached, or unrelated feature branch. Switch to the default branch and pull latest before creating a new branch.
4. If the worktree has user changes, stop and ask unless they are clearly part of the same requested issue.
5. Use the `commit-and-cleanup` skill's discipline for stale worktrees: prune registered missing worktrees, never delete ambiguous worktrees without confirmation, and leave active unmerged work alone.

## Automated Reviewer Policy

Select the automated PR reviewer from repository ownership before posting any review trigger.

1. Classify the repository:

   ```powershell
   gh repo view --json owner,name,visibility,url
   ```

2. Use this policy table:

   | Repository | Automated review product | Request method | Readiness signal |
   | --- | --- | --- | --- |
   | Private `HemSoft/*` repos | CodeRabbitAI and Macroscope | Post `@coderabbitai review` and `@Macroscope-App review` PR comments | Both products have reviewed the latest meaningful commit and no substantive feedback remains |
   | Relias-owned repos, including `Relias/*` and `Relias-Engineering/*` | GitHub Copilot PR Reviewer only | Request Copilot through the PR Reviewers menu or verified repo automation | Copilot has reviewed or the configured automatic review has run, actionable Copilot comments are addressed, and normal checks/review requirements are satisfied |
   | Any other repo | Ask the user before using third-party reviewers | Do not assume CodeRabbitAI or Macroscope are allowed | Use the user-approved reviewer path |

3. Never post CodeRabbitAI or Macroscope triggers on Relias work.
4. Treat Copilot PR Reviewer as a code-review feedback source, not an approving reviewer. GitHub's Copilot code review normally leaves a `Comment` review rather than an `Approve` or `Request changes` review.
5. If a Relias repo does not expose Copilot PR Reviewer or automatic Copilot review, record that evidence and continue with human/repository checks instead of falling back to CodeRabbitAI or Macroscope.

## Issue Queue Hygiene

Before selecting or implementing the oldest issue, inspect the open issue queue for duplicates and overlapping scope. Do not create a branch until this pass is complete.

1. Fetch enough issue context to compare intent, scope, and acceptance criteria:

   ```powershell
   gh issue list --state open --limit 1000 --json number,title,createdAt,labels,body,url
   ```

2. Treat issues as duplicates when they ask for the same outcome with no meaningful difference in scope, affected area, or acceptance criteria.
3. For duplicate issues:
   - Keep the issue with the clearest actionable body. Prefer the oldest issue when clarity is equal.
   - Move any unique evidence, links, or acceptance criteria from duplicate issues into the keeper before closing them.
   - Comment on each duplicate with the keeper issue link and close it so it is removed from the active queue. Do not physically delete GitHub issues unless the user explicitly asks for deletion.
4. Treat issues as overlapping when they share one or more requirements but also contain distinct, independently useful work.
5. For overlapping issues:
   - Choose exactly one owner issue for each shared requirement. Prefer the issue where that requirement is central to the title and acceptance criteria.
   - Edit the other issue body or title to remove the shared requirement and leave only its unique scope.
   - Add a short cross-reference comment explaining where the removed common scope now lives.
6. After closing duplicates or editing overlap, re-fetch the affected issues and verify the remaining open issues are distinct before selecting the oldest issue.

## Oldest Issue to PR

1. Find the oldest remaining open issue after issue queue hygiene:

   ```powershell
   gh issue list --state open --limit 1000 --json number,title,createdAt,labels,url --jq "sort_by(.createdAt)[0]"
   ```

2. Read the issue, linked discussions, nearby issues, and relevant code before branching. Re-check that the selected issue is not a duplicate and does not still overlap with another open issue.
3. Create a focused branch from the default branch. Prefer `fix/issue-{number}-{short-slug}` for bugs and `feature/issue-{number}-{short-slug}` for features.
4. Implement the smallest defensible change that satisfies the issue.
5. Run the repo's relevant diagnostics, tests, lint, typecheck, and build. If a check is unavailable or pre-existing failures block verification, capture exact evidence.
6. Commit only the intended changes and push the branch.
7. Create the PR with a body that links and closes the issue, summarizes verification, and calls out any residual risk:

   ```powershell
   gh pr create --fill --body "Closes #{issue-number}`n`n## Verification`n- ..."
   ```

## Review Loop

1. Request automated review after the PR exists, using the [Automated Reviewer Policy](#automated-reviewer-policy).

   For private `HemSoft/*` repos only:

   ```powershell
   gh pr comment {pr-number} --body "@coderabbitai review"
   gh pr comment {pr-number} --body "@Macroscope-App review"
   ```

   For Relias repos, request GitHub Copilot PR Reviewer only. Use the GitHub PR Reviewers menu or verified repo automation for Copilot code review; do not post CodeRabbitAI or Macroscope comments.

2. Pause three minutes after posting or requesting automated review:

   ```powershell
   Start-Sleep -Seconds 180
   ```

3. Fetch reviews, comments, checks, and merge state:

   ```powershell
   gh pr view {pr-number} --json reviews,comments,reviewDecision,statusCheckRollup,mergeStateStatus,latestReviews
   gh api repos/{owner}/{repo}/pulls/{pr-number}/comments
   ```

4. Address each substantive automated-review comment by changing code, adding tests, or replying with a specific reason no change is needed.
5. Follow the `pr-reviewer` skill rule: never mass-resolve review threads programmatically. Let code changes make comments outdated, or reply substantively in the thread.
6. After fixes, rerun relevant verification, commit, push, and request review again when there is new signal to review.
7. Use judgment with rate limits and duplicate-review refusals. Do not spam the selected review product if it explicitly declines, hits rate limits, or already reviewed the latest commit.

## Oldest PR Merge Readiness

Once the issue work has a PR, or when asked to continue PR readiness, take the oldest open PR:

```powershell
gh pr list --state open --limit 1000 --json number,title,createdAt,url,headRefName,reviewDecision --jq "sort_by(.createdAt)[0]"
```

Check the repo-appropriate review signal before declaring readiness.

For private `HemSoft/*` repos, verify approval or satisfactory latest feedback from both CodeRabbitAI and Macroscope. Treat bot identity by current GitHub review/comment author names; commonly this means an author login containing `coderabbitai` and one containing `macroscope`.

For Relias repos, verify GitHub Copilot PR Reviewer has reviewed the PR or automatic Copilot review has run when available. Do not require CodeRabbitAI or Macroscope approval for Relias work. Do not treat Copilot's `Comment` review as a branch-protection approval; use it as feedback that must be addressed alongside normal repository checks and any human review requirements.

If the required repo-specific review signal is missing:

1. Request the missing review with the repo-specific request method.
2. Wait three minutes.
3. Re-fetch reviews and comments.
4. Address new feedback and repeat only when useful.

The PR is ready when checks are acceptable, merge state is not blocked by unresolved known issues, substantive automated-review feedback has been addressed, and the repo-specific review policy is satisfied or cannot reasonably re-review because of documented availability, rate-limit, or duplicate-review limits.

## Closeout

1. Leave the PR branch pushed and the PR open.
2. Do not delete the active PR branch.
3. Remove only temporary worktrees, stashes, or branches created by this run that are safe to remove. Ask before ambiguous deletion.
4. Return the main worktree to the default branch when clean and practical.
5. Save the PR URL, branch name, issue number, duplicate/overlap cleanup performed, verification commands, review state, and any blocked reviewer/rate-limit evidence.
6. Mark the Codex goal complete only when the PR is ready to merge by the criteria above. Mark blocked only after repeated inability to progress without external input.

## Avoid

- Starting from a dirty or dangling branch.
- Reusing an unrelated branch for the oldest issue.
- Implementing an issue before duplicate and overlap cleanup is complete.
- Leaving duplicate issues open after selecting a keeper.
- Letting two open issues retain the same acceptance criteria or shared scope.
- Force-pushing shared branches without explicit reason.
- Treating "PR created" as done before review feedback is checked.
- Posting CodeRabbitAI or Macroscope review triggers on Relias-owned repositories.
- Treating Copilot PR Reviewer comments as branch-protection approval.
- Programmatically resolving review threads instead of addressing them.
- Merging the PR without explicit user instruction.
