---
name: skill-improver
description: V2.3 - Applies standardized improvements to skills and proactively suggests missing opt-in features. Converts "ALWAYS:" sections to hooks. Checks for protocol reference opportunities. Checks for commands-first description format. Enforces .agents/skills/ as the universal skill location per agentskills.io spec. Use when modifying any skill.
disable-model-invocation: true
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the skill-improver directory (path contains 'skill-improver'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Skill Name} - {Action Taken}"
            - One-line summary
            - Accurate timestamp
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if skill-improver was used (check if any files in skill-improver directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in skill-improver directory
            2. Verify it contains an entry with format "## HH:MM - {Skill Name} - {Action Taken}"
            3. Ensure the entry includes a one-line summary of what was done
            4. Verify retrospective check was performed
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Skill Improver

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

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
| `hooks`            | ❌ | Hook configuration for automated post-processing   |

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

## Converting Old-School Skills to Hooks

When encountering skills with manual "ALWAYS:" sections, convert them to hooks:

### Conversion Steps

1. **Identify manual sections**:
   - `## ALWAYS: Log This Interaction`
   - `## ALWAYS: Retrospective Check`

2. **Add hooks to frontmatter** (if not present):

   ```yaml
   hooks:
     PostToolUse:
       - matcher: "Read|Write|Edit"
         hooks:
           - type: prompt
             prompt: |
               If a file was read, written, or edited in the {skill-name} directory (path contains '{skill-name}'), verify that history logging occurred.
               
               Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
               - Format: "## HH:MM - {Action Taken}"
               - One-line summary
               - Accurate timestamp
               
               If history entry is missing or incomplete, provide specific feedback on what needs to be added.
               If history entry exists and is properly formatted, acknowledge completion.
     Stop:
       - matcher: "*"
         hooks:
           - type: prompt
             prompt: |
               Before stopping, if {skill-name} was used (check if any files in {skill-name} directory were modified), verify that the interaction was logged:
               
               1. Check if History/{YYYY-MM-DD}.md exists in {skill-name} directory
               2. Verify it contains an entry with format "## HH:MM - {Action Taken}"
               3. Ensure the entry includes a one-line summary of what was done
               4. If retrospectives are enabled, verify retrospective check was performed
               
               If history entry is missing:
               - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
               
               If history entry exists:
               - Return {"decision": "approve"}
               
               Include a systemMessage with details about the history entry status.
   ```

3. **Remove manual sections**: Delete `## ALWAYS: Log This Interaction` and `## ALWAYS: Retrospective Check` sections

4. **Replace `{skill-name}`**: Update hooks configuration with actual skill name

5. **Version bump**: Increment version (e.g., V1.3 → V1.4)

## When Modifying a Skill

Follow this workflow:

### Step 1: Check for Old-School Manual Instructions

Before applying improvements, check if the skill uses outdated manual instructions:

**History Tracking - Convert to Hooks**:

- Search for `## ALWAYS: Log This Interaction` section
- If found, this needs to be converted to hooks in frontmatter
- Add to improvements: "Convert manual history tracking to hooks"

**Retrospective - Convert to Hooks**:

- Search for `## ALWAYS: Retrospective Check` section
- If found, this needs to be converted to hooks in frontmatter
- Add to improvements: "Convert manual retrospective to hooks"

**If Hooks Missing** (for skills that should have them):

- Check if frontmatter has `hooks` field
- If missing and skill should track history, add to improvements: "Add hooks for history tracking"

### Step 2: Apply Active Improvements

Apply all active improvements from the registry below. This includes:

1. Version Implementation (always)
2. File Size Management (check if > 500 lines)
3. Frontmatter Validation (validate against spec)
4. Protocol References (check for opportunities to reference protocols skill)

### Step 3: Present Final Questions

**CRITICAL:** End every interaction with a single, concise question table. Never scatter questions throughout multiple sections.

**Format:**

```markdown
## Next Steps

| # | Question | Options | Recommended |
|---|----------|---------|-------------|
| 1 | Add history tracking? | Yes / No | ✅ Yes |
| 2 | Add retrospective? | Yes / No | ✅ Yes |
| 3 | Condense verbose sections? | Yes / No / Show analysis first | ✅ Show analysis first |
```

**Rules:**

- Combine ALL questions into ONE table at the end
- Number questions sequentially
- List all possible answers clearly
- Mark recommended answer with ✅
- Keep table concise (avoid long explanations in cells)
- Put detailed context BEFORE the table, not in it

## Improvements Registry

| ID  | Name                          | Status |
| 1   | Version Implementation     | Active |
| 2   | History Tracking           | Opt-in |
| 3   | File Size Management       | Active |
| 4   | Frontmatter Validation     | Active |
| 5   | Retrospective              | Opt-in |
| 6   | Protocol References        | Active |
| 7   | Commands-First Description | Active |
| 8   | Location Standard          | Active |

## Skill Location Standard (ID 8)

**Rule**: All skills MUST use `.agents/skills/` as their directory path — this is the universal standard from the [agentskills.io](https://agentskills.io/specification) specification (AAIF/Linux Foundation, 30+ tools).

**Check**: When improving a skill, verify its path. If found in a vendor-specific location:

| Legacy Path | Action |
|-------------|--------|
| `.claude/skills/{name}/` | Recommend move to `.agents/skills/{name}/` |
| `.github/skills/{name}/` | Recommend move to `.agents/skills/{name}/` |
| `~/.claude/skills/{name}/` | Recommend move to `~/.agents/skills/{name}/` |

**Why**: Vendor-specific paths limit which AI tools can discover the skill. The `.agents/skills/` path is scanned by Claude Code, GitHub Copilot, OpenAI Codex CLI, Cursor, Gemini CLI, JetBrains, and others — write once, use everywhere.

**Exception**: Only keep vendor-specific paths if the skill uses vendor-exclusive features (e.g., Cursor's `.mdc` format, Copilot-specific agent configuration).

## Commands-First Description Format

When a skill has multiple distinct commands, modes, or entry points, the
description should list them upfront using a `Commands:` prefix:

```
V{version} - Commands: {Cmd1}, {Cmd2}, {Cmd3}. {Rest of description}
```

This makes the skill's capabilities immediately visible when the user types
`/{skill-name}` in the chat prompt.

**When to apply:**

- The skill has 2+ distinct operations, modes, or entry points
- The commands are user-facing (things the user would ask for by name)

**When NOT to apply:**

- Single-purpose skills with one clear function
- Skills where the description already conveys the scope clearly

**Example:**

```yaml
# Before
description: V1.0 - Expert in pipeline debugging, auditing, and status reporting.

# After
description: "V1.0 - Commands: Debug, Audit, Status, Report. Expert in pipeline debugging, auditing, and status reporting."
```

When checking a skill, if it has multiple sections that function as distinct
modes/commands, suggest adding the `Commands:` prefix as an improvement.

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

### 2. History Tracking (via Hooks)

**Rule**: Opt-in per skill. When enabled, hooks automatically verify history logging.

**Location**: `~/.agents/skills/{skill-name}/History/{YYYY-MM-DD}.md`

**Implementation**: Add hooks to frontmatter (not manual "ALWAYS:" sections):

```yaml
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the {skill-name} directory (path contains '{skill-name}'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if {skill-name} was used, verify history entry exists in History/{YYYY-MM-DD}.md with format "## HH:MM - {Action Taken}" and one-line summary.
```

**Migration**: When encountering `## ALWAYS: Log This Interaction` sections:

1. Remove the manual section
2. Add hooks configuration to frontmatter
3. Replace `{skill-name}` with actual skill name
4. Create History/ directory if it doesn't exist

---

### 5. Retrospective (via Hooks)

**Rule**: Opt-in per skill. When enabled, hooks automatically verify retrospective check occurred.

**Implementation**: Retrospectives are verified in the Stop hook (same hook that checks history logging).

The Stop hook includes step 4:

```
4. If retrospectives are enabled, verify retrospective check was performed
```

**Migration**: When encountering `## ALWAYS: Retrospective Check` sections:

1. Remove the manual section
2. Retrospective verification is handled by the Stop hook
3. No separate section needed - hooks enforce retrospective checks

**Note**: Retrospective checks still happen during skill execution, but hooks verify they occurred instead of relying on manual instructions.

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

---

### 6. Protocol References

**Rule**: Check if skill contains detailed instructions that could be replaced with protocol references for better maintainability and consistency.

**When to Check**:

1. **During skill improvement** - Scan for common patterns that exist in protocols
2. **When skill is verbose** - Look for opportunities to reduce duplication

**Common Patterns to Check**:

| Pattern in Skill | Protocol Available | Suggestion |
| Detailed "ask clarifying questions" instructions | `protocols` → "Asking Clarifying Questions" | Replace with: "Consult `protocols` skill for how to ask clarifying questions" |
| (Future protocols will be added) | Check protocols skill regularly | Update as new protocols become available |

**Implementation**:

1. Read the `protocols` skill to see available protocol entries
2. Scan the skill being improved for patterns that match available protocols
3. If found, suggest replacing detailed instructions with protocol reference

**Example Suggestion**:

```markdown
💡 Protocol Reference Opportunity:

Found detailed "asking questions" instructions in Step 2.

Recommend replacing with:
"Consult the `protocols` skill for standardized question format."

This reduces duplication and ensures consistency across all skills.
```

**Benefits**:

- **Consistency**: All skills use the same standardized procedures
- **Maintainability**: Update once in protocols, applies everywhere
- **Brevity**: Skills remain focused on their core purpose
