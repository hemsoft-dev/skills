---
name: version
description: V1.0 - Release version management with auto-detection, Semantic Versioning, Keep a Changelog format, and git tag integration. Use when bumping versions or preparing releases.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the version skill directory (path contains '.claude/skills/version'), verify that history logging occurred.
            
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
            Before stopping, if version skill was used (check if any files in version skill directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in version skill directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md"}
            
            If history entry exists:
            - Return {"decision": "approve"}
---

# Version Management 🏷️

Universal release version management using **Semantic Versioning** (SemVer) with auto-detection, Keep a Changelog format, and git integration.

## Versioning Schemes

### Semantic Versioning (Default)

Format: `MAJOR.MINOR.PATCH` (e.g., `1.2.3`)

| Component | When to Increment |
|-----------|-------------------|
| **MAJOR** | Breaking changes, incompatible API changes |
| **MINOR** | New features, backward-compatible additions |
| **PATCH** | Bug fixes, backward-compatible patches |

Pre-release: `1.0.0-alpha.1`, `1.0.0-beta.2`, `1.0.0-rc.1`

### Calendar Versioning (CalVer)

Format: `YYYY.MM.DD` or `YYYY.MM.PATCH` (e.g., `2026.01.30`)

Use when: Release cadence matters more than compatibility tracking.

## Workflow

### 1. Auto-Detect Version Locations

Scan repository for version declarations:

| Language/Framework | Files to Check | Pattern |
|-------------------|----------------|---------|
| **JavaScript/TypeScript** | `package.json`, `*/package.json` | `"version": "x.y.z"` |
| **Python** | `pyproject.toml`, `setup.py`, `*/__version__.py`, `setup.cfg` | `version = "x.y.z"` or `__version__ = "x.y.z"` |
| **Rust** | `Cargo.toml` | `version = "x.y.z"` |
| **.NET** | `*.csproj`, `Directory.Build.props` | `<Version>x.y.z</Version>` |
| **Go** | `version.go`, `cmd/*/main.go` | `const Version = "x.y.z"` |
| **Ruby** | `*.gemspec`, `lib/*/version.rb` | `VERSION = "x.y.z"` |
| **Java** | `pom.xml`, `build.gradle` | `<version>x.y.z</version>` or `version = 'x.y.z'` |
| **PHP** | `composer.json` | `"version": "x.y.z"` |
| **Generic** | `VERSION`, `VERSION.txt` | Plain version string |

Also check:
- UI version displays (search for version in `.tsx`, `.vue`, `.svelte` files)
- Docker files (`Dockerfile`, `docker-compose.yml`)
- CI/CD configs (`.github/workflows/*.yml`, `azure-pipelines.yml`)

### 2. Present Detected Locations

```
## Version Locations Detected

| # | File | Current Version | Line | Action |
|---|------|-----------------|------|--------|
| 1 | package.json | 1.2.3 | 3 | Y/n |
| 2 | admin/package.json | 1.2.3 | 3 | Y/n |
| 3 | src/version.ts | 1.2.3 | 5 | Y/n |
| 4 | CHANGELOG.md | 1.2.3 | 7 | Y/n |

**Add more locations?** Enter file paths or press Enter to continue:
```

### 3. Determine Version Bump

Ask user:

```
Current version: 1.2.3

What type of release?
1. PATCH (1.2.4) - Bug fixes only [recommended for most releases]
2. MINOR (1.3.0) - New features, backward compatible
3. MAJOR (2.0.0) - Breaking changes
4. Custom - Enter specific version

Enter choice (1-4) or version number:
```

### 4. Update CHANGELOG.md

**Enforce Keep a Changelog format** (https://keepachangelog.com):

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-01-30

### Added
- New feature X

### Changed
- Updated behavior Y

### Fixed
- Bug fix Z

### Removed
- Deprecated feature W

## [1.2.3] - 2026-01-15
...
```

**Changelog sections** (use only what applies):
- `Added` - New features
- `Changed` - Changes in existing functionality
- `Deprecated` - Soon-to-be removed features
- `Removed` - Removed features
- `Fixed` - Bug fixes
- `Security` - Vulnerability fixes

If CHANGELOG.md doesn't exist, create it with proper header.

### 5. Git Integration

After updating files, offer:

```
## Git Integration

| # | Action | Command | Recommended |
|---|--------|---------|-------------|
| 1 | Stage changes | git add -A | Y/n |
| 2 | Commit | git commit -m "chore: bump version to 1.3.0" | Y/n |
| 3 | Create tag | git tag -a v1.3.0 -m "Release 1.3.0" | Y/n |
| 4 | Push with tags | git push && git push --tags | y/N |

Enter numbers to SKIP or press Enter to apply recommended:
```

### 6. Generate Release Notes (Optional)

If git history available, offer to generate release notes from commits:

```powershell
# Get commits since last tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline
```

Format for GitHub/GitLab releases:

```markdown
## What's Changed

### Features
- feat: Add new dashboard widget (#123)
- feat: Support dark mode (#124)

### Bug Fixes
- fix: Resolve memory leak (#125)
- fix: Correct date formatting (#126)

**Full Changelog**: https://github.com/owner/repo/compare/v1.2.3...v1.3.0
```

## Pre-Release Checklist

Before bumping version:

- [ ] All tests passing
- [ ] CHANGELOG.md updated with changes
- [ ] No uncommitted changes (or commit them first)
- [ ] On correct branch (main/master)

## Version Inconsistency Detection

If different files have different versions, flag immediately:

```
⚠️ Version Inconsistency Detected!

| File | Version |
|------|---------|
| package.json | 1.2.3 |
| admin/package.json | 1.0.0 | ← MISMATCH
| src/constants.ts | 1.2.2 | ← MISMATCH

Recommendation: Align all versions to 1.2.3 before proceeding.
Continue anyway? (y/N)
```

## Output Format

```text
# 🏷️ Version Bump Summary

**Repository**: {repo-name}
**Previous**: {old-version}
**New**: {new-version}
**Type**: {MAJOR|MINOR|PATCH}

## Files Updated

| File | Old | New | Status |
|------|-----|-----|--------|
{rows}

## Git Actions

| Action | Status |
|--------|--------|
| Staged | ✅ |
| Committed | ✅ |
| Tagged | ✅ |
| Pushed | ⏭️ Skipped |

---

Next: Push when ready with `git push && git push --tags`
```

## Related Skills

After version bump, consider:

- **Repo Audit** — Verify documentation reflects new version
- **Simplisticate** — Clean up code before release

---

*"Version numbers are a communication tool, not a marketing tool."*
