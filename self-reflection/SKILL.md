---
name: self-reflection
description: V1.2 - Helps the agent troubleshoot difficult tasks and record lessons learned into persistent memory to prevent future hiccups.
---

# Self-Reflection

Use this skill when a task was particularly difficult, required multiple retries, or resulted in unexpected behavior/errors. The goal is to analyze what went wrong and store actionable insights in persistent memory to avoid future mistakes and to self-improve.

## Reference: Core Behavior Guidelines

When reflecting on mistakes, always review `~/.claude/CLAUDE.md` which contains core principles:

- **Never Fabricate** - Don't invent numbers, counts, paths, or URLs without verifying
- **Verify Before Asserting** - Read files, check paths, run commands to get real data
- **Admit Uncertainty** - Say "I don't know" rather than guessing with false confidence
- **Be Consistent** - Follow established output formats, count before stating counts
- **Self-Correct Promptly** - Acknowledge errors immediately, don't defend mistakes

If the mistake violated one of these principles, note which one in the reflection.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Workflow

1. **Verify Output**: Before concluding a task, always verify the final output against the user's original request and any relevant project specifications. Ensure all expected files, data points, and behaviors are present.
2. **Analyze the Hiccup**: If the verification fails or if the task was particularly difficult, review the conversation history and tool outputs to identify exactly where the execution deviated from the plan or encountered friction.
3. **Draft a Reflection**: Summarize the issue, the root cause, and the specific strategy or "golden rule" that would have prevented it.
4. **Human-in-the-Loop**: Present the drafted reflection to the user.
   - Explain what you intend to save to memory.
   - Ask for their agreement.
   - Ask if they have any additional input or corrections to the reflection.
5. **Record to Memory**: Once approved, use the `memory` tool to save the insight.
   - Prefer creating or updating a file like `/memories/lessons-learned.md` or a task-specific file under `/memories/troubleshooting/`.
   - If the `memory` tool is unavailable, consult the user for an alternative storage location.

## Memory Tool Usage

- **Command**: `create` or `insert`
- **Path**: `/memories/lessons-learned.md` (or similar)
- **Content**: A concise, actionable entry including the date, the context, and the lesson learned.

## Example Entry Format

### {Date} - {Task/Tool Name}

- **Issue**: {Brief description of the hiccup}
- **Root Cause**: {Why it happened}
- **Lesson**: {Actionable instruction for future self}
