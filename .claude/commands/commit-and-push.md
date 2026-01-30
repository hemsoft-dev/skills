# Commit and Push

## Goal

A perfectly clear and concise commit message for the git changes to the repo and a clean git status after the work is done.

## Variables

- `Current repo` - Automatically determined from the current git repository (no user input required)

## Parameters

This command takes no parameters. It automatically analyzes all staged and unstaged changes in the current git repository.

## Instructions

Follow this workflow to commit and push changes:

1. **Run linters and auto-fix:**
   - Run `markdownlint-cli2 --fix "**/*.md"` to fix markdown issues
   - Run `Invoke-ScriptAnalyzer` to check PowerShell files

2. **Check git status** - Shows current state before staging

3. **Stage all changes** - Run `git add .` to stage all modified files

4. **Verify staged changes** - Show what will be committed with `git status`

5. **Auto-generate commit message:**
   - Analyze all staged changes using `git diff --staged`
   - Create a commit message following conventional commits format: `<type>(<scope>): <subject>`
   - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`
   - Focus on the most significant change as the primary subject
   - Add multi-line description if changes are complex or involve multiple features
   - **DO NOT prompt the user for a commit message** - generate it automatically

6. **Commit with generated message** - Run `git commit -m "message"`

7. **Verify clean status** - Confirm working tree is clean

8. **Push to remote** - Run `git push`

9. **Final verification** - Confirm everything is pushed and clean

## Commit Message Guidelines

- Use conventional commits format: `<type>(<scope>): <subject>`
- Keep subject line under 72 characters
- Focus on the "what" and "why", not the "how"
- Identify the most significant change and use that as the primary scope
- Examples:
  - `feat(meeting-prep): create skill with Microsoft skill levels`
  - `fix(slack): resolve API token refresh issue`
  - `docs(readme): update installation instructions`
  - `chore(skills): update multiple history entries`

## Report

Report back a summary of the commit message used and confirm that the git status is now clean and pushed to remote.
