# Agent Guidelines for Skills Repository

This document provides critical guidance for AI agents working in the Claude Skills repository.

## Table of Contents

- [Skill Simplicity Principle](#skill-simplicity-principle)
- [Prompt History Logging](#prompt-history-logging)
- [Quick Reference](#quick-reference)
- [Web Search Guidelines](#web-search-guidelines)
- [Pre-Commit Quality Checks](#pre-commit-quality-checks)
- [Commit and Push Workflow](#commit-and-push-workflow)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Repository Structure](#repository-structure)
- [Skill Development](#skill-development)
- [Troubleshooting](#troubleshooting)

## Skill Simplicity Principle

### ⚠️ DESIGN FOR LESSER MODELS

Skills must be written so that **any model** can execute them without confusion. Follow these rules:

**1. Number Scripts in Execution Order**

If scripts must run in sequence, name them with numeric prefixes:

- `1-Extract-Data.ps1` → `2-Process-Data.ps1` → `3-Save-Results.ps1`

**2. Use Tables Over Prose**

Replace paragraphs with:

- Decision tables (When to use which script)
- Parameter tables (Required/Optional/Default)
- Output tables (What gets created where)

**3. One Workflow = One Numbered List**

Complex workflows must be broken into numbered steps:

```markdown
### Step 1: Find the file
### Step 2: Run script 1
### Step 3: Verify output
```

**4. Remove Ambiguity**

- ❌ "You can use either script depending on..."
- ✅ "Always start with script 1. Script 2 is called automatically."

**5. No Duplicate Instructions**

If a script does something, don't repeat the logic as inline code in SKILL.md. Reference the script.

**6. Default Behavior Must Be Explicit**

First section should state: "When user activates this skill without specifying an action, do X."

## Prompt History Logging

### ⚠️ TOP PRIORITY - Every Meaningful Prompt

**For every meaningful prompt invocation**, append to `PROMPT-HISTORY.md` in the root directory:

```markdown
YYYY-MM-DD - HH:MM - <Brief 1-2 sentence summary of the prompt>
Result: <Brief 1-2 sentence summary of what was accomplished>
```

**What qualifies as meaningful**:

- ✅ Feature requests or enhancements
- ✅ Important bug fixes
- ✅ Architecture or design decisions
- ✅ Significant refactoring
- ✅ New skill creation or major skill updates
- ✅ Complex troubleshooting or investigations
- ❌ Simple queries ("what time is it?", "ping")
- ❌ Routine operations (reading files, checking status)
- ❌ Trivial edits or formatting changes

**Example entry**:

```markdown
2026-01-18 - 14:32 - Add Todoist integration to diary skill with task filtering
Result: Successfully integrated Todoist API, added filtering for @Regular Chores tag, updated diary workflow to include completed tasks in daily entries.

2026-01-18 - 09:15 - Fix Slack message pagination bug causing missed messages
Result: Implemented cursor-based pagination, added retry logic for rate limits, verified with 500+ message channel.
```

**File location**: `c:\Users\User\.claude\skills\PROMPT-HISTORY.md`

**When to log**: At the completion of meaningful work, before final commit/push.

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

1. **ALWAYS log meaningful prompts to [PROMPT-HISTORY.md](#prompt-history-logging)**
2. **ALWAYS run linting before commit**
3. **ALWAYS verify [clean state](#verifying-clean-state) after commit and push**
4. **ALWAYS use conventional commit format**
5. **ALWAYS provide clickable links when performing web searches** - See [Web Search Guidelines](#web-search-guidelines)
6. **ALWAYS follow [Skill Simplicity Principle](#skill-simplicity-principle)** when creating/editing skills
7. **NEVER commit/push without confirming clean state**

## Web Search Guidelines

### ⚠️ CRITICAL REQUIREMENT - Always Provide Links

**When performing web searches, you MUST include clickable links to all sources referenced.**

### Requirements

1. **Always include clickable URLs** - Every source mentioned must have a clickable link
2. **Format links properly** - Use markdown link format: `[Link Text](URL)`
3. **Include all relevant sources** - Don't summarize without providing access to original sources
4. **Verify links are accessible** - Ensure URLs are complete and functional

### Examples

**✅ Good**:

```markdown
Found several highly-rated recipes:
- [Angela's Awesome Chicken Enchiladas](https://www.allrecipes.com/recipe/83549/angelas-awesome-enchiladas/) - 4.8 stars, 3,216 reviews
- [Gimme Some Oven Chicken Enchiladas](https://gimmesomeoven.com/best-chicken-enchiladas-ever) - Popular since 2009
```

**❌ Bad**:

```markdown
Found several highly-rated recipes:
- Angela's Awesome Chicken Enchiladas - 4.8 stars, 3,216 reviews
- Gimme Some Oven Chicken Enchiladas - Popular since 2009
```

### When This Applies

- ✅ Web searches for recipes, articles, documentation
- ✅ Researching tools, libraries, or services
- ✅ Finding tutorials, guides, or reference materials
- ✅ Looking up product information or reviews
- ✅ Any web search where sources are referenced

### Rationale

Users need direct access to sources for:

- Verification of information
- Further reading
- Original context
- Credibility assessment
- Bookmarking for later reference

**This is a non-negotiable requirement** - web search results without clickable links are incomplete and violate
repository standards.

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

When asked to "commit and push changes", follow the [Quick Reference](#quick-reference) steps, then:

```powershell
# After linting and staging (see Quick Reference)
git commit -m "feat(skill-name): add feature description"
git push
```

**Critical**: Always [verify clean state](#verifying-clean-state) after commit and push.

### Critical Checkpoints

**✅ You are NOT done until**:

1. [Clean state verified](#verifying-clean-state) after commit
2. `git push` completes successfully
3. [Clean state verified](#verifying-clean-state) after push

**❌ NEVER stop after**:

- `git add` - Changes are only staged, not committed
- `git commit` - Changes are local, not pushed
- Before final verification - Cannot confirm clean state

### Handling Linting Failures

If pre-commit hook blocks your commit:

1. Read the error output (hook shows exact file and rule)
2. Fix PowerShell issues: `Invoke-ScriptAnalyzer -Path ./path/to/file.ps1`
3. Fix Markdown issues: `markdownlint-cli2 --fix ./path/to/file.md`
4. Stage fixes: `git add ./path/to/fixed/file.md`
5. Retry commit: `git commit -m "fix(skill): resolve linting issues"`
6. [Verify clean state](#verifying-clean-state)

### Verifying Clean State

**✅ Clean state** (you're done):

```text
On branch main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

**❌ NOT clean** (continue workflow):

```text
Changes to be committed: ...
Changes not staged for commit: ...
Untracked files: ...
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
| --- | --- | --- |
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

**✅ Good**:

```text
feat(diary): add Todoist integration
fix(slack): resolve pagination issue
docs(agents): add commit guidelines
```

**❌ Bad**:

```text
Update files           # Too vague, no type/scope
Fixed bug              # What bug? Where?
WIP                    # Never commit WIP
```

### Multi-Line Messages

For complex changes:

```text
feat(github): add PR review automation

Implements automated PR reviews with configurable modes.
Includes retry logic for API rate limiting.

Closes #123
```

### Breaking Changes

Use `!` after type/scope or `BREAKING CHANGE:` footer:

```text
feat(api)!: change authentication method

BREAKING CHANGE: API now requires OAuth tokens instead of API keys.
```

## Repository Structure

### Top-Level Files

| File | Purpose |
| --- | --- |
| `.markdownlint.jsonc` | Markdown linting configuration |
| `.PSScriptAnalyzerSettings.psd1` | PowerShell linting configuration |
| `Install-GitHooks.ps1` | Pre-commit hook installer |
| `AGENTS.md` | This file - Agent guidelines |
| `PROMPT-HISTORY.md` | Log of meaningful prompt interactions |

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

**Solution**: See [Handling Linting Failures](#handling-linting-failures) section.

### "Changes not staged for commit"

**Cause**: Files modified but not staged

**Solution**: `git add .` (or specific files), then [verify clean state](#verifying-clean-state).

### "Your branch is ahead of origin"

**Cause**: Local commits not pushed

**Solution**: `git push`, then [verify clean state](#verifying-clean-state).

### "Detached HEAD state"

**Cause**: Checked out a commit instead of branch

**Solution**: `git checkout main`, then [verify clean state](#verifying-clean-state).

### "Merge conflicts"

**Cause**: Remote conflicts with local changes

**Solution**:

1. `git pull`
2. Resolve conflicts (look for `<<<<<<< HEAD` markers)
3. `git add .`
4. `git commit -m "merge: resolve conflicts"`
5. [Verify clean state](#verifying-clean-state)

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

- [ ] [Prompt logged to PROMPT-HISTORY.md](#prompt-history-logging) (if meaningful)
- [ ] Linters run successfully (PowerShell and Markdown)
- [ ] All changes staged with `git add`
- [ ] Commit message follows conventional format
- [ ] [Clean state verified](#verifying-clean-state) after commit
- [ ] `git push` completed successfully
- [ ] [Clean state verified](#verifying-clean-state) after push
- [ ] History log updated if modifying a skill
- [ ] Version number incremented if appropriate

**Remember**: You are not done until [clean state is verified](#verifying-clean-state) after pushing.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:

- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
