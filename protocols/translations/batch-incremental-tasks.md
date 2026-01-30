# Protocol: Batch and Incremental Task Execution

## When to Use

When instructions contain keywords or phrases indicating batch, incremental, or context-aware execution, including but not limited to:

- "in batches"
- "incremental"
- "context-aware"
- "do X at a time"
- "process in groups"
- "work in chunks"
- "step by step"
- "one at a time"
- "gradually"
- "progressively"
- Any instruction that implies breaking a large task into smaller pieces

**Rationale**: The agent is not self-aware enough to reliably detect when it's exhausting the context window. This protocol prevents context exhaustion by enforcing explicit batch boundaries and user confirmation.

## Detailed Instructions

### 1. Recognize Batch Task Requirements

If the user's instructions contain any of the recognition keywords above, or if the task appears large/complex enough to risk context exhaustion, activate this protocol.

### 2. Determine Batch Size

Use your best judgment based on task complexity:

- **Simple tasks** (e.g., adding a line to multiple files, simple find/replace): 10-20 items per batch
- **Moderate tasks** (e.g., reading and updating files with version bumps): 5-15 items per batch
- **Complex tasks** (e.g., analyzing code, making architectural decisions): 1-5 items per batch
- **Very complex tasks** (e.g., multi-step refactoring, debugging): 1 item at a time

**Key principle**: Err on the side of smaller batches if uncertain. It's better to ask more frequently than to exhaust context.

### 3. Create Progress Tracking File

**MANDATORY**: Create a temporary markdown file to track progress. This file should:

- Be named descriptively (e.g., `temp-{task-name}-tasks.md`)
- Include:
  - Task objective
  - Total items to process (if known)
  - Checklist of items with `[ ]` for incomplete, `[x]` for complete
  - Progress tracking section with counts
  - Instructions for continuation (so another agent can pick up where you left off)

**Example structure**:
```markdown
# Task: [Task Name]

## Objective
[Clear description of what needs to be done]

## Progress Tracking
- **Total Items**: [number or "unknown"]
- **Completed**: [count]
- **Remaining**: [count]
- **Status**: In Progress / Complete
- **Last Updated**: [date]

## Items to Process
- [ ] Item 1
- [ ] Item 2
- [x] Item 3 (completed)
...

## Continuation Instructions
[How to resume this task]
```

### 4. Execute Batch

1. Process items according to your determined batch size
2. Update the progress tracking file after each batch:
   - Mark completed items with `[x]`
   - Update completion counts
   - Update "Last Updated" timestamp
3. **STOP** after completing the batch

### 5. Request Confirmation

After completing a batch, present a brief confirmation message with:

- **Numbers only**: "Completed X/Y items. Continue with next batch?"
- Optionally include: Brief summary of what was done in this batch

**Do NOT proceed** until the user explicitly confirms (e.g., "yes", "continue", "go ahead", "proceed").

### 6. Handle Confirmation

- **If user confirms**: Continue with the next batch
- **If user says "stop" or "pause"**: Stop immediately and note the current state in the tracking file
- **If user modifies instructions**: Update the tracking file and follow new instructions

### 7. Completion and Cleanup

When all items are complete:

1. Update the tracking file to show "Status: Complete"
2. **MANDATORY**: Offer to delete the temporary tracking file:
   ```
   Task complete! All [X] items processed. Would you like me to delete the temporary tracking file (temp-{task-name}-tasks.md)?
   ```
3. Only delete if the user explicitly confirms

## Exceptions

**Only proceed without confirmation if the user is VERY explicit**, such as:

- "Do all of them without asking"
- "Don't ask, just do it"
- "Process everything in one go"
- "No need to confirm, just continue"

**Default behavior**: Always ask for confirmation unless explicitly told otherwise.

## Example Workflow

### Initial Task Recognition

**User**: "Update all 50 skills to add a protocol check"

**Agent**: Recognizes "all 50" implies batch processing. Creates `temp-skill-update-tasks.md` and processes first batch of 10 items.

### After First Batch

**Agent**: "Completed 10/50 items. Continue with next batch?"

**User**: "Yes"

**Agent**: Processes next batch of 10 items, updates tracking file.

### After Multiple Batches

**Agent**: "Completed 30/50 items. Continue with next batch?"

**User**: "Continue"

**Agent**: Processes next batch.

### Completion

**Agent**: "Task complete! All 50 items processed. Would you like me to delete the temporary tracking file (temp-skill-update-tasks.md)?"

**User**: "Yes, delete it"

**Agent**: Deletes the file and confirms deletion.

## Key Principles

1. **Context preservation**: The tracking file ensures another agent can resume if context is lost
2. **User control**: User always has the opportunity to stop, modify, or review progress
3. **Transparency**: Progress is always visible and trackable
4. **Safety**: Default to asking; only skip with explicit user instruction
5. **Cleanup**: Always offer to remove temporary files when done

## Integration with Other Protocols

- If a skill references this protocol, follow these instructions exactly
- This protocol can be combined with other protocols (e.g., "ask clarifying questions" before starting batches)
- The tracking file can reference other protocols if needed for continuation instructions
