---
name: skill-improver
description: V1.4 - Applies standardized improvements to skills. Use when modifying any skill.
---

# Skill Improver

Meta-skill for applying consistent improvements across all skills.

## Agent Skills Specification - Frontmatter Reference

Per the official spec at <https://agentskills.io/specification>, SKILL.md frontmatter supports:

| Field         | Required | Constraints                                           |
| `name`             | ✅ | Max 64 chars. Lowercase alphanumeric + hyphens.    |
| `description`      | ✅ | Max 1024 chars. Include what + when to use.        |
| `license`          | ❌ | License name or reference (e.g., `Apache-2.0`)    |
| `dependencies`     | ❌ | Software packages required (e.g., `python>=3.8`)  |
| `compatibility`    | ❌ | Max 500 chars. Environment requirements             |
| `metadata`         | ❌ | Key-value map for custom properties                 |
| `allowed-tools`    | ❌ | Space-delimited pre-approved tools                 |

**Example with optional fields:**

```yaml
---
name: my-skill
description: Does X when Y. Use for Z scenarios.
license: Apache-2.0
compatibility: Requires git, docker, network access
metadata:
  author: example-org
  version: "1.0"
allowed-tools: Bash(git:*) Read
---
```

## When Modifying a Skill

Apply all relevant improvements from the registry below.

## Improvements Registry

| ID  | Name                          | Status |
| 1   | Version Implementation     | Active |
| 2   | History Tracking           | Opt-in |
| 3   | File Size Management       | Active |
| 4   | Frontmatter Validation     | Active |

---

### 1. Version Implementation

**Rule**: Every skill's `description` field must include a version prefix.

**Format**: `V{major}.{minor} - {description}`

**Logic**:

- **No version exists**: Prepend `V1.0 -` to the description
- **Version exists**: Bump minor by 1 (e.g., `V1.3` → `V1.4`)

**Examples**:

| Before       | After        |
|--------------|--------------|
| Creates v1   | V1.0 - v1    |
| V1.3 - v1    | V1.4 - v1    |
| V2.9 - v1    | V2.10 - v1   |

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

| Pattern                   | Solution                                         |
| **Multiple distinct commands/APIs** | Split into separate skills (see examples) |
| **Large reference sections**         | Move to separate reference files                |
| **Extensive examples**               | Extract to `examples/` directory                |
| **Multiple workflows**               | Move complex workflows to `workflows/` files    |
| **Historical notes**                 | Already handled by `History/` directory         |

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

```markdown

---

### 4. Frontmatter Validation

**Rule**: Validate frontmatter against official Agent Skills Specification.

**Checks**:

| Field      | Validation                                                |
| `name`           | Max 64 chars, lowercase alphanumeric + hyphens                 |
| `description`    | Max 1024 chars, non-empty, includes what + when to use       |
| `license`        | Optional - license name or file reference                     |
| `compatibility`  | Optional - max 500 chars, environment requirements            |
| `metadata`       | Optional - key-value map only                                 |
| `allowed-tools`  | Optional - space-delimited tool list                          |

**When to Suggest Optional Fields**:

| Field                | Suggest When...                                    |
| `license`          | Skill has LICENSE.txt file or uses open-source       |
| `compatibility`    | Skill requires specific tools or network access     |
| `metadata.author`  | Skill is for distribution or team use              |

**Example Validation Feedback**:

```markdown
⚠️ Frontmatter Issues Found:

- description exceeds 1024 character limit (1203 chars)
- name contains uppercase: "My-Skill" → should be "my-skill"

💡 Optional Fields to Consider:

- Add `compatibility: Requires git, docker` since skill uses these tools
```
