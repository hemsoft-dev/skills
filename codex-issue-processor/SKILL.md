---
name: codex-issue-processor
description: V1.1 - Turns the oldest GitHub Issue into a clean Codex-authored branch and PR, then iterates with CodeRabbitAI and Macroscope review until the PR is merge-ready.
disable-model-invocation: true
compatibility: Requires git, GitHub CLI authentication, network access, and a GitHub repository with Issues and Pull Requests enabled.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the codex-issue-processor directory (path contains 'codex-issue-processor'), verify that history logging occurred.

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
            Before stopping, if codex-issue-processor was used (check if any files in codex-issue-processor directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in codex-issue-processor directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Codex Issue Processor

Use this skill when asked to turn the oldest GitHub Issue into a pull request, or to continue the oldest open pull request until it is ready to merge, using Codex as the implementation agent and CodeRabbitAI plus Macroscope as automated PR reviewers.

## Goal Start

Start by creating a goal using whichever goal mechanism the current agent runtime exposes. If a `goal` skill/tool is available, invoke it with the objective below. If a slash command is available, run or ask the user to run the slash command exactly. Do not depend on a specific agent product name.

```text
/goal Take the oldest GitHub Issue and create a branch for it, work the issue to the best of your ability and create a PR. Request CodeRabbitAI and Macroscope PR review, wait for feedback, address comments, and keep requesting review until you are confident all issues have been addressed and both review products have clean current-head signal. Make sure you have good worktree/branch hygiene. Don't start on dangling branches and clean up before and after yourself.
```

Before branching, deduplicate the open issue queue and separate overlapping scope so the PR implements one clear, non-overlapping issue. The goal is achieved when the PR is ready to merge with clean CodeRabbitAI and Macroscope review signal and no unresolved substantive feedback. Do not merge unless the user explicitly asks for merge.

## Preflight

1. Verify repository context:

   ```powershell
   git rev-parse --show-toplevel
   git remote -v
   gh repo view --json owner,name,visibility,url,defaultBranchRef
   ```

2. Check worktree hygiene before editing:

   ```powershell
   git status --short --branch
   git branch --show-current
   git worktree list
   git fetch --prune
   ```

3. Do not start from a dangling, stale, detached, or unrelated feature branch. Switch to the default branch and pull latest before creating a new branch.
4. If the worktree has user changes, stop and ask unless they are clearly part of the same requested issue.
5. Use isolated worktrees when the repository convention expects them or when the main checkout is dirty.
6. Use the `commit-and-cleanup` skill's discipline for stale worktrees: prune registered missing worktrees, never delete ambiguous worktrees without confirmation, and leave active unmerged work alone.

## Automated Reviewer Policy

This skill is intended for repositories where CodeRabbitAI and Macroscope are approved reviewers. Before posting review triggers, verify that the target repository permits those reviewers.

1. Classify the repository:

   ```powershell
   gh repo view --json owner,name,visibility,url
   ```

2. Use this policy table:

   | Repository | Automated review products | Request method | Readiness signal |
   | --- | --- | --- | --- |
   | Private `HemSoft/*` repos | CodeRabbitAI and Macroscope | Post `@coderabbitai review` and `@Macroscope-App review` PR comments | Both products reviewed the latest meaningful commit, status checks are acceptable, and no substantive feedback remains |
   | Repos that explicitly approve CodeRabbitAI and Macroscope | CodeRabbitAI and Macroscope | Post `@coderabbitai review` and `@Macroscope-App review` PR comments | Same as above, plus normal repo checks and human review requirements |
   | Relias-owned repos, including `Relias/*` and `Relias-Engineering/*` | Ask before using third-party reviewers | Do not assume CodeRabbitAI or Macroscope are allowed | Use the user-approved reviewer path |
   | Any other repo | Ask before using third-party reviewers | Do not post review triggers until approved | Use the user-approved reviewer path |

3. Do not post CodeRabbitAI or Macroscope triggers on restricted repos unless the user explicitly approves that repo.
4. Treat CodeRabbitAI and Macroscope as automated review feedback sources. Do not call a PR approved unless GitHub reports an approval, successful check, or other concrete repo-specific readiness signal.
5. If either reviewer cannot run because of permissions, rate limits, duplicate-review refusal, or unavailable checks, record that evidence and continue only when the remaining checks and human/repo policy make the PR safe to hand off.

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

1. Request automated review after the PR exists:

   ```powershell
   gh pr comment {pr-number} --body "@coderabbitai review"
   gh pr comment {pr-number} --body "@Macroscope-App review"
   ```

2. Pause three minutes after posting review requests:

   ```powershell
   Start-Sleep -Seconds 180
   ```

3. Fetch reviews, comments, checks, and merge state:

   ```powershell
   gh pr view {pr-number} --json reviews,comments,reviewDecision,statusCheckRollup,mergeStateStatus,latestReviews,headRefOid
   gh api repos/{owner}/{repo}/pulls/{pr-number}/comments
   ```

4. Inspect review threads when available through GraphQL. Require addressed threads to become resolved before declaring readiness.
5. Address each substantive automated-review comment by changing code, adding tests, or replying with a specific reason no change is needed.
6. Follow the `pr-reviewer` skill rule: never mass-resolve review threads programmatically. Let code changes make comments outdated, or reply substantively in the thread.
7. After fixes, rerun relevant verification, commit, push, and request review again when there is new signal to review.
8. Use judgment with rate limits and duplicate-review refusals. Do not spam either reviewer if it explicitly declines, hits rate limits, or already reviewed the latest commit.

## Oldest PR Merge Readiness

Once the issue work has a PR, or when asked to continue PR readiness, take the oldest open PR:

```powershell
gh pr list --state open --limit 1000 --json number,title,createdAt,url,headRefName,reviewDecision --jq "sort_by(.createdAt)[0]"
```

Verify CodeRabbitAI and Macroscope current-head signal before declaring readiness. Treat bot identity by current GitHub review/comment/check author names; commonly this means an author or check containing `coderabbitai`, `CodeRabbit`, `macroscope`, or `Macroscope`.

If the required review signal is missing:

1. Request the missing review.
2. Wait three minutes.
3. Re-fetch reviews, comments, threads, checks, and merge state.
4. Address new feedback and repeat only when useful.

The PR is ready when checks are acceptable, merge state is not blocked by unresolved known issues, substantive automated-review feedback has been addressed, all addressed reviewer threads are resolved, and both CodeRabbitAI and Macroscope have either reviewed the current head or cannot reasonably re-review because of documented availability, rate-limit, or duplicate-review limits.

## Closeout

1. Leave the PR branch pushed and the PR open.
2. Do not delete the active PR branch.
3. Remove only temporary worktrees, stashes, or branches created by this run that are safe to remove. Ask before ambiguous deletion.
4. Return the main worktree to the default branch when clean and practical.
5. Save the PR URL, branch name, issue number, duplicate/overlap cleanup performed, verification commands, review state, and any blocked reviewer/rate-limit evidence.
6. Mark the goal complete only when the PR is ready to merge by the criteria above. Mark blocked only after repeated inability to progress without external input.

## Avoid

- Starting from a dirty or dangling branch.
- Reusing an unrelated branch for the oldest issue.
- Implementing an issue before duplicate and overlap cleanup is complete.
- Leaving duplicate issues open after selecting a keeper.
- Letting two open issues retain the same acceptance criteria or shared scope.
- Force-pushing shared branches without explicit reason.
- Treating "PR created" as done before review feedback is checked.
- Posting CodeRabbitAI or Macroscope review triggers on repositories where they are not approved.
- Programmatically resolving review threads instead of addressing them.
- Declaring readiness before checking PR head SHA, checks, merge state, and latest reviewer feedback.
- Merging the PR without explicit user instruction.
