---
name: commit-and-push
description: "V1.0 - Commit and push changes with pre-commit verification, linting, and TODO tracking."
---

# Commit and Push

Commit and push code changes with full pre-commit verification.

## Default Behavior

When activated without arguments, commit and push all staged/unstaged changes in the current repository.

## Workflow

1. Run all pre-commit verification (husky, linting, formatting, tests)
2. Ensure markdown files are linted and code is formatted
3. Meet minimum test coverage requirements if defined
4. Commit with a descriptive, best-practice commit message
5. Push to remote
6. Verify `git status` returns clean — nothing staged, changed, or untracked
7. If the repo has a `TODO.md`, check if the commit completes a TODO item
   - If yes, ask the user if they want to mark it complete using the **todo** skill

## Rules

- You are NOT done until `git status` comes back clean
- Do not leave anything staged, changed, or untracked
- Do not commit anything you are not sure about — ask the user if uncertain
- Follow the commit message guidelines in AGENTS.md
