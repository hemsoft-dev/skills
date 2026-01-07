---
name: skill-improver
description: V1.2 - Applies standardized improvements to skills. Use when modifying any skill.
---

# Skill Improver

Meta-skill for applying consistent improvements across all skills.

## When Modifying a Skill

Apply all relevant improvements from the registry below.

## Improvements Registry

| ID | Name | Status |
|----|------|--------|
| 1 | Version Implementation | Active |
| 2 | History Tracking | Opt-in |

---

### 1. Version Implementation

**Rule**: Every skill's `description` field must include a version prefix.

**Format**: `V{major}.{minor} - {description}`

**Logic**:
- **No version exists**: Prepend `V1.0 - ` to the description
- **Version exists**: Bump minor by 1 (e.g., `V1.3` → `V1.4`)

**Examples**:

| Before | After |
|--------|-------|
| `Creates new skills...` | `V1.0 - Creates new skills...` |
| `V1.3 - Creates new skills...` | `V1.4 - Creates new skills...` |
| `V2.9 - Expert in...` | `V2.10 - Expert in...` |

**Regex Pattern**: `^V(\d+)\.(\d+) - `

---

### 2. History Tracking

**Rule**: Opt-in per skill. When enabled, every interaction MUST be logged.

**Location**: `~/.claude/skills/{skill-name}/History/{YYYY-MM-DD}.md`

**Placement**: Add immediately after the skill's intro paragraph (near top, not bottom).

**To Enable**: Add this section to a skill's SKILL.md:
```markdown
## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:
```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```
