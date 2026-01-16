# Agent Guidelines for Skills Repository

This document provides critical guidance for AI agents working in the Claude Skills repository.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Pre-Commit Quality Checks](#pre-commit-quality-checks)
- [Commit and Push Workflow](#commit-and-push-workflow)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Repository Structure](#repository-structure)
- [Skill Development](#skill-development)
- [Troubleshooting](#troubleshooting)

## Quick Reference

### Before Every Commit

```powershell
# 1. Lint PowerShell files
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .PSScriptAnalyzerSettings.psd1

# 2. Lint Markdown files
markdownlint-cli2 --fix "**/*.md"

# 3. Check git status
git status

# 4. Stage changes
git add .

# 5. Commit with descriptive message
git commit -m "feat(skill-name): add new feature"

# 6. Verify clean status
git status
```

### Critical Rules

1. **NEVER commit until git status is clean**
2. **ALWAYS run linting before commit**
3. **ALWAYS verify git status after commit**
4. **ALWAYS use conventional commit format**
5. **NEVER push without confirming clean state**

## Pre-Commit Quality Checks

### Overview

The repository enforces quality standards through:

- **PSScriptAnalyzer** - PowerShell linting
- **markdownlint-cli2** - Markdown linting
- **Git pre-commit hooks** - Automated enforcement

### PowerShell Linting

**Configuration**: `.PSScriptAnalyzerSettings.psd1`

**Rules enforced**:

- Compatibility with PowerShell 5.1 and 7.0
- Cross-platform command compatibility
- Type compatibility across versions
- Error and Warning severity levels

**Manual check**:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .PSScriptAnalyzerSettings.psd1
```

**Fix issues before committing** - The pre-commit hook will block commits if issues are found.

### Markdown Linting

**Configuration**: `.markdownlint.jsonc`

**Rules enforced**:

- Consistent heading hierarchy
- Fenced code blocks with language specifiers
- Line length: 120 characters
- Proper blank lines around sections
- No trailing spaces
- Files end with newline

**Manual check and auto-fix**:

```powershell
# Check all markdown files
markdownlint-cli2 "**/*.md"

# Auto-fix common issues
markdownlint-cli2 --fix "**/*.md"
```

**Common auto-fixable issues**:

- Trailing spaces (MD009)
- Multiple blank lines (MD012)
- Code block formatting (MD046)
- List formatting (MD032)
- File ending newline (MD047)

### Installing Pre-Commit Hooks

If hooks are not installed, run:

```powershell
.\Install-GitHooks.ps1
```

This sets up the pre-commit hook to automatically:

- Run PSScriptAnalyzer on staged `.ps1` files
- Run markdownlint-cli2 on staged `.md` files
- Block commits if any issues are found
- Show exactly what needs fixing

## Commit and Push Workflow

### Standard Workflow

When asked to "commit and push changes":

```powershell
# Step 1: Run linters and auto-fix
markdownlint-cli2 --fix "**/*.md"
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .PSScriptAnalyzerSettings.psd1

# Step 2: Check status BEFORE staging
git status

# Step 3: Stage all changes
git add .

# Step 4: Verify what's staged
git status

# Step 5: Commit with conventional commit message
git commit -m "feat(skill-name): add feature description"

# Step 6: CRITICAL - Verify git status is clean
git status
# Output should show: "nothing to commit, working tree clean"

# Step 7: Push to remote
git push

# Step 8: FINAL verification
git status
```

### Critical Checkpoints

**✅ You are NOT done until**:

1. `git status` shows: `nothing to commit, working tree clean`
2. `git push` completes successfully without errors
3. Final `git status` confirms clean state

**❌ NEVER stop here**:

- After `git add` - Changes are only staged, not committed
- After `git commit` - Changes are local, not pushed
- Before final `git status` - Cannot confirm clean state

### Handling Linting Failures

If pre-commit hook blocks your commit:

```powershell
# 1. Read the error output carefully
# The hook shows exactly which file and rule failed

# 2. For PowerShell issues
Invoke-ScriptAnalyzer -Path ./path/to/file.ps1

# 3. For Markdown issues  
markdownlint-cli2 --fix ./path/to/file.md

# 4. Fix the issues manually if auto-fix doesn't work

# 5. Stage the fixes
git add ./path/to/fixed/file.ps1

# 6. Try commit again
git commit -m "fix(skill): resolve linting issues"

# 7. Verify clean status
git status
```

### Verifying Clean State

**Clean git status output**:

```text
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

**NOT clean (do NOT stop here)**:

```text
Changes to be committed:
  modified:   some-file.md

Changes not staged for commit:
  modified:   other-file.ps1

Untracked files:
  new-file.md
```

## Commit Message Guidelines

### Conventional Commits Format

All commits MUST follow this format:

```text
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types

| Type | When to Use | Example |
|------|-------------|---------|
| `feat` | New feature or capability | `feat(diary): add weather integration` |
| `fix` | Bug fix | `fix(slack): resolve API token issue` |
| `docs` | Documentation only | `docs(readme): update installation steps` |
| `style` | Code style/formatting (no logic change) | `style(skill): fix markdown formatting` |
| `refactor` | Code restructuring (no feature change) | `refactor(scripts): reorganize utility functions` |
| `perf` | Performance improvement | `perf(search): optimize file scanning` |
| `test` | Adding or updating tests | `test(skill): add validation tests` |
| `chore` | Maintenance tasks | `chore(deps): update dependencies` |
| `ci` | CI/CD changes | `ci(github): add workflow for linting` |
| `build` | Build system changes | `build(npm): update build configuration` |
| `revert` | Revert previous commit | `revert: revert feat(diary): add weather` |

### Scopes

Use the skill name or component as scope:

- `diary`
- `slack`
- `github`
- `scripts`
- `docs`
- `skills` (for cross-skill changes)

### Subject Line Rules

1. **Use imperative mood** - "add" not "added" or "adds"
2. **Lowercase first letter** - `feat(skill): add feature` not `Add feature`
3. **No period at end** - `fix bug` not `fix bug.`
4. **Maximum 50 characters** for subject line
5. **Be specific** - Describe WHAT changed, not WHY (use body for WHY)

### Examples

**✅ Good commit messages**:

```text
feat(diary): add Todoist integration for daily tasks
fix(slack): resolve channel listing pagination issue
docs(agents): add commit message guidelines
refactor(scripts): consolidate duplicate API calls
chore(markdown): update linting configuration
```

**❌ Bad commit messages**:

```text
Update files           # Too vague, no type or scope
Fixed bug              # What bug? Where?
WIP                    # Never commit work-in-progress
asdf                   # Meaningless
Changes to skill.md    # No type, no scope, describes WHAT not WHY
```

### Multi-Line Messages

For complex changes, use body and footer:

```text
feat(github): add PR review automation

Implements automated PR reviews with configurable modes:
- Local report generation
- Direct PR comments via API  
- Interactive fix assistance

Includes retry logic for API rate limiting and proper
authentication handling for enterprise repositories.

Closes #123
```

### Breaking Changes

Indicate breaking changes with `BREAKING CHANGE:` in footer or `!` after type/scope:

```text
feat(api)!: change authentication method

BREAKING CHANGE: API now requires OAuth tokens instead of API keys.
Migration guide available in docs/migration.md
```

## Repository Structure

### Top-Level Files

| File | Purpose |
|------|---------|
| `.markdownlint.jsonc` | Markdown linting configuration |
| `.PSScriptAnalyzerSettings.psd1` | PowerShell linting configuration |
| `Install-GitHooks.ps1` | Pre-commit hook installer |
| `AGENTS.md` | This file - Agent guidelines |
| `TODO.md` | Repository tasks and improvements |
| `claude-skills-architecture.html` | Architecture documentation |
| `$PROFILE` | PowerShell profile configuration |

### Skill Structure

Each skill follows this pattern:

```text
skill-name/
├── SKILL.md                    # Main skill documentation
├── History/                    # Interaction logs
│   └── YYYY-MM-DD.md
├── scripts/                    # PowerShell/Python scripts
│   └── script-name.ps1
└── [additional files]          # Data, configs, etc.
```

### Critical Paths

- **Skills root**: `c:\Users\User\.claude\skills`
- **Linting configs**: Root of skills directory
- **Git hooks**: `.git/hooks/pre-commit`
- **History logs**: `<skill-name>/History/YYYY-MM-DD.md`

## Skill Development

### Creating New Skills

Use the `skill-creator` skill:

1. Activates when user requests new skill creation
2. Generates optimized `SKILL.md` with best practices
3. Creates necessary directory structure
4. Includes logging workflow and history tracking

**Key requirements**:

- Every skill MUST have `SKILL.md`
- Include "ALWAYS: Log This Interaction" section
- Add version number to description
- Use clear trigger phrases
- Include file structure section

### Modifying Existing Skills

Use the `skill-improver` skill:

1. Applies standardized improvements
2. Ensures consistency across skills
3. Updates version numbers
4. Validates structure and formatting

**Before modifying a skill**:

1. Read the entire `SKILL.md` file
2. Understand the skill's purpose and triggers
3. Check for dependencies in scripts or data
4. Update version number in frontmatter
5. Log changes in `History/YYYY-MM-DD.md`

### History Logging

**Every skill interaction** should append to `History/YYYY-MM-DD.md`:

```markdown
## HH:MM - Action Taken
One-line summary of what was done
```

**Example**:

```markdown
## 14:32 - Updated Subscription Tracking
Added Cursor AI Pro annual subscription ($192, renews Jan 16)
```

### Version Numbering

Skills use semantic versioning: `V{MAJOR}.{MINOR}`

- `V1.0` - Initial release
- `V1.1` - Minor improvements, new features
- `V1.2` - Additional enhancements
- `V2.0` - Major overhaul or breaking changes

Update version in SKILL.md frontmatter:

```yaml
---
name: skill-name
description: V1.2 - Brief description of skill
---
```

## Troubleshooting

### "Pre-commit hook failed"

**Cause**: Linting issues in staged files

**Solution**:

```powershell
# Check what failed
git status

# For PowerShell issues
Invoke-ScriptAnalyzer -Path ./path/to/file.ps1

# For Markdown issues
markdownlint-cli2 ./path/to/file.md

# Auto-fix if possible
markdownlint-cli2 --fix ./path/to/file.md

# Stage fixes and retry
git add ./path/to/file.md
git commit -m "fix(skill): resolve linting issues"
```

### "Changes not staged for commit"

**Cause**: Files modified but not added to staging area

**Solution**:

```powershell
# Stage all changes
git add .

# Or stage specific files
git add ./path/to/file.md

# Verify
git status
```

### "Your branch is ahead of origin"

**Cause**: Local commits not pushed to remote

**Solution**:

```powershell
# Push to remote
git push

# Verify clean state
git status
```

### "Detached HEAD state"

**Cause**: Checked out a specific commit instead of a branch

**Solution**:

```powershell
# Return to main branch
git checkout main

# Verify
git status
```

### "Merge conflicts"

**Cause**: Remote changes conflict with local changes

**Solution**:

```powershell
# Pull latest changes
git pull

# Resolve conflicts in editor
# Look for <<<<<<< HEAD markers

# Stage resolved files
git add .

# Complete merge
git commit -m "merge: resolve conflicts with remote"

# Verify
git status
```

## Best Practices

### Quality First

1. **Always run linters before commit** - Don't rely solely on pre-commit hooks
2. **Fix issues, don't suppress** - Only disable rules with good reason
3. **Test scripts before committing** - Ensure PowerShell scripts run without errors
4. **Validate markdown rendering** - Check that tables, code blocks, links work correctly

### Git Hygiene

1. **Commit frequently** - Small, focused commits are better than large ones
2. **One logical change per commit** - Don't mix unrelated changes
3. **Write descriptive messages** - Future you will thank you
4. **Pull before push** - Stay synced with remote
5. **Never force push** - Unless absolutely necessary and coordinated

### Documentation

1. **Update SKILL.md when changing behavior** - Keep documentation current
2. **Log every interaction** - Maintain History files
3. **Increment version numbers** - Signal changes clearly
4. **Add comments to complex scripts** - Explain WHY, not just WHAT

### Communication

1. **Report what you're doing** - Keep user informed of progress
2. **Ask when uncertain** - Don't guess at user intent
3. **Explain errors clearly** - Help user understand what went wrong
4. **Suggest fixes** - Don't just report problems, offer solutions

## Summary Checklist

Before completing any commit and push task:

- [ ] Linters run successfully (PowerShell and Markdown)
- [ ] All changes staged with `git add`
- [ ] Commit message follows conventional format
- [ ] `git status` shows clean state after commit
- [ ] `git push` completed successfully
- [ ] Final `git status` confirms clean state
- [ ] History log updated if modifying a skill
- [ ] Version number incremented if appropriate

**Remember**: You are not done until `git status` shows `nothing to commit, working tree clean` after pushing.
