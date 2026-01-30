---
name: markdown
description: V1.1 - Expert in markdown linting with markdownlint-cli2, quality enforcement, and best practices for consistent documentation.
---

# Markdown Expert

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert guidance for markdown linting, quality enforcement, and documentation best practices.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Markdownlint - Markdown Linter

### What is markdownlint?

**markdownlint** is a static analysis tool that checks markdown files for:

- Style consistency
- Formatting issues
- Common mistakes
- Best practices violations
- Accessibility concerns

**Integrated with:**

- VS Code extension (real-time feedback)
- Command line (markdownlint-cli2)
- Git pre-commit hooks
- CI/CD pipelines

### Installation

**markdownlint-cli2** (Node.js-based, recommended):

```powershell
npm install -g markdownlint-cli2
```

**Verify installation:**

```powershell
markdownlint-cli2 --version
```

### Basic Usage

**Lint a single file:**

```powershell
markdownlint-cli2 README.md
```

**Lint all markdown files recursively:**

```powershell
markdownlint-cli2 "**/*.md"
```

**Fix auto-fixable issues:**

```powershell
markdownlint-cli2 --fix "**/*.md"
```

**Custom configuration:**

```powershell
markdownlint-cli2 --config .markdownlint.jsonc "**/*.md"
```

### Common Rules

| Rule | Description | Fixable |
|------|-------------|---------|
| MD001 | Heading levels increment by one | No |
| MD003 | Heading style (ATX/setext) | Yes |
| MD004 | Unordered list style | Yes |
| MD009 | Trailing spaces | Yes |
| MD010 | Hard tabs | Yes |
| MD012 | Multiple consecutive blank lines | Yes |
| MD013 | Line length | No |
| MD022 | Headings surrounded by blank lines | Yes |
| MD025 | Single top-level heading | No |
| MD031 | Fenced code blocks surrounded by blank lines | Yes |
| MD032 | Lists surrounded by blank lines | Yes |
| MD040 | Fenced code language | No |
| MD046 | Code block style | Yes |
| MD047 | File should end with newline | Yes |

**Full rule list:**

```powershell
markdownlint-cli2 --help
```

Or visit: <https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md>

### Configuration

Create `.markdownlint.jsonc` in repository root:

```jsonc
{
  // Default state for all rules
  "default": true,
  
  // MD013/line-length - Line length (disabled for long URLs, tables, code)
  "MD013": {
    "line_length": 120,
    "heading_line_length": 120,
    "code_block_line_length": 120,
    "code_blocks": false,
    "tables": false,
    "headings": true
  },
  
  // MD024/no-duplicate-heading - Multiple headings with same content
  "MD024": {
    "siblings_only": true  // Allow same heading in different sections
  },
  
  // MD033/no-inline-html - Inline HTML (allow for specific tags)
  "MD033": {
    "allowed_elements": ["br", "details", "summary", "sup", "sub"]
  },
  
  // MD040/fenced-code-language - Fenced code blocks should have language
  "MD040": true,
  
  // MD046/code-block-style - Code block style (fenced preferred)
  "MD046": {
    "style": "fenced"
  }
}
```

### Pre-Commit Hook Integration

Markdown linting is integrated into the same pre-commit hook as PowerShell:

- Checks all staged `.md` files
- Blocks commits if issues found
- Shows exactly what needs fixing
- Auto-fix available for many rules

### CI/CD Integration

**GitHub Actions workflow** checks all markdown files:

- Runs on push and pull requests
- Scans entire repository
- Fails build if issues found
- Provides detailed reports

### VS Code Integration

**markdownlint extension** provides real-time feedback.

**Extension ID**: `DavidAnson.vscode-markdownlint`

**Install:**

```powershell
code --install-extension DavidAnson.vscode-markdownlint
```

**Settings (settings.json):**

```json
{
  "markdownlint.config": {
    "default": true,
    "MD013": false
  }
}
```

### Best Practices

1. **Use fenced code blocks** with language specifiers

   ```markdown
   ​```powershell
   Get-Process
   ​```
   ```

2. **Consistent heading hierarchy** - Don't skip levels

   ```markdown
   # H1
   ## H2
   ### H3
   ```

3. **Surround headings with blank lines**

   ```markdown
   Previous paragraph.

   ## Heading

   Next paragraph.
   ```

4. **End files with newline** - Most rules expect this

5. **Use consistent list markers**
   - Use `-` for unordered lists
   - Use `1.` for ordered lists

6. **Add language to code blocks**

   ````markdown
   ```javascript
   console.log('Hello');
   ```
   ````

### Common Issues and Fixes

**Issue: MD009 - Trailing spaces**

```powershell
# Fix automatically
markdownlint-cli2 --fix "**/*.md"
```

**Issue: MD012 - Multiple consecutive blank lines**

```markdown
# ❌ Bad
Paragraph 1.


Paragraph 2.

# ✅ Good
Paragraph 1.

Paragraph 2.
```

**Issue: MD040 - Fenced code language**

````markdown
# ❌ Bad
```
code here
```

# ✅ Good
```javascript
code here
```
````

**Issue: MD047 - Files should end with newline**

- Most editors do this automatically
- Configure your editor to add final newline

### Ignoring Rules

**In configuration (.markdownlint.jsonc):**

```jsonc
{
  "MD013": false,  // Disable line length globally
}
```

**In-file comments (use sparingly):**

```markdown
<!-- markdownlint-disable MD013 -->
This line can be really really long without triggering the line length rule.
<!-- markdownlint-enable MD013 -->
```

**⚠️ WARNING**: Only disable rules with good reason. Fix the markdown instead.

### Quick Fix Script

Run this to auto-fix common issues:

```powershell
# Fix all markdown files in repository
markdownlint-cli2 --fix "**/*.md"

# Fix specific directory
markdownlint-cli2 --fix "docs/**/*.md"
```

## File Structure

```
markdown/
├── SKILL.md
└── History/
    └── {YYYY-MM-DD}.md
```

## Integration with Quality System

Markdown linting is part of the repository's quality enforcement system, mirroring the PowerShell quality gates.

### What's Enforced (January 2026)

**Local Protection (Pre-Commit Hook)**:

- Automatically runs on ALL staged `.md` files before commit
- Blocks commits if any markdown issues are found
- Shows exactly what needs fixing with line numbers and rule names
- Located at `.git/hooks/pre-commit-markdown.ps1`
- Integrated into `.git/hooks/pre-commit` alongside PowerShell checks

**Remote Protection (CI/CD)**:

- GitHub Actions workflow runs on every push and pull request
- Separate job for markdown validation (runs in parallel with PowerShell)
- Scans entire repository for markdown files
- Fails build if issues are found
- Provides detailed reports in Actions output

### Configuration Files

- **`.markdownlint.jsonc`** - Linting rules and preferences
  - Line length: 120 characters
  - Allows HTML elements: `<br>`, `<details>`, `<summary>`, `<kbd>`
  - Fenced code blocks required with language specifiers
  - Consistent heading hierarchy enforced
- **`.git/hooks/pre-commit`** - Calls both PowerShell and Markdown checks
- **`.github/workflows/quality-check.yml`** - CI/CD for both file types

### Workflow

**When you commit:**

1. Pre-commit hook runs for staged `.md` files
2. markdownlint-cli2 analyzes each file
3. If issues found: commit is BLOCKED with detailed errors
4. If clean: commit proceeds

**Auto-fix available:**

```powershell
markdownlint-cli2 --fix "**/*.md"
```

This fixes most issues automatically (blank lines, trailing spaces, code block formatting).

### Quality Standards

All markdown files must adhere to:

- ✅ Consistent heading hierarchy (no skipped levels)
- ✅ Fenced code blocks with language specifiers
- ✅ Proper blank lines around headings, lists, and code blocks
- ✅ No trailing spaces
- ✅ Files end with newline
- ✅ Line length limits (120 chars for content)
- ✅ Consistent list markers

**No exceptions** - fix the markdown, don't disable rules.

### Benefits

- **Consistency** - All documentation follows same style
- **Quality** - Catches common mistakes automatically
- **Readability** - Enforces best practices for accessibility
- **Prevention** - Stops low-quality markdown from entering the repository
- **Speed** - Auto-fix handles most issues instantly
