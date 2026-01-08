---
name: skill-improver
description: V1.3 - Applies standardized improvements to skills. Use when modifying any skill.
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
| 3 | File Size Management | Active |

---

### 1. Version Implementation

**Rule**: Every skill's `description` field must include a version prefix.

**Format**: `V{major}.{minor} - {description}`

**Logic**:

- **No version exists**: Prepend `V1.0 -` to the description
- **Version exists**: Bump minor by 1 (e.g., `V1.3` → `V1.4`)

**Examples**:

| Before | After |
|--------|-------|
| `Creates new skills...` | `V1.0 - Creates new skills...` |
| `V1.3 - Creates new skills...` | `V1.4 - Creates new skills...` |
| `V2.9 - Expert in...` | `V2.10 - Expert in...` |

**Regex Pattern**: `^V(\d+)\.(\d+) -`

---

### 3. File Size Management

**Rule**: Skills should remain focused and maintainable. When SKILL.md exceeds ~500 lines, recommend refactoring.

**Rationale**:

- Google's documentation best practices: "A small set of fresh and accurate docs is better than a large assembly"
- "Write short and useful documents. Cut out everything unnecessary"
- Focused documents are easier to maintain, search, and understand
- Large files often indicate multiple responsibilities that could be separated

**Recommendation Process**:

1. Count lines in SKILL.md
2. If > 500 lines, assess structure and suggest splits
3. Propose modular breakdown based on natural boundaries

**Refactoring Strategies**:

| Pattern | Solution |
|---------|----------|
| **Multiple distinct commands/APIs** | Split into separate skills (e.g., `slack-messages`, `slack-files`, `slack-admin`) |
| **Large reference sections** | Move to separate reference files (e.g., `reference.md`, `api-reference.md`) |
| **Extensive examples** | Extract to `examples/` directory with individual files |
| **Multiple workflows** | Keep core skill, move complex workflows to separate `workflows/` files |
| **Historical notes** | Already handled by `History/` directory - ensure not in SKILL.md |

**When NOT to Split**:

- Natural cohesion exists (all commands work together on same domain object)
- Splitting would duplicate significant shared context
- The skill is a comprehensive reference guide that benefits from completeness

**Implementation**:
When a skill exceeds threshold:

1. Analyze structure (count sections, identify duplicates, check for distinct domains)
2. Propose specific split strategy with rationale
3. Only suggest split if clear boundaries exist and it improves maintainability

**Example Recommendations**:

- `slack` (1069 lines): Could split into `slack-messages`, `slack-channels`, `slack-files`, `slack-admin`
- `powershell` (830 lines): Consider moving extensive examples to `examples/` directory
- `cortex` (513 lines): Already well-structured but near threshold - monitor growth

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
