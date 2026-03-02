# Test Hook Skill

This is a test skill that demonstrates **hook-based history logging** instead of manual "ALWAYS: Log This Interaction" instructions.

## What This Tests

- **Automated history logging** via hooks
- **PostToolUse hook** - Verifies history logging after Read/Write/Edit operations
- **Stop hook** - Blocks completion if history entry is missing

## Structure

```
test-hook-skill/
├── SKILL.md              # Skill definition with hooks in frontmatter (NO manual history logging instructions)
├── History/              # History entries (auto-populated by hooks)
└── README.md             # This file
```

## How It Works

1. **Skill executes** - Performs its operation
2. **PostToolUse hook triggers** - After Read/Write/Edit operations, verifies history logging
3. **Stop hook triggers** - Before completion, ensures history entry exists
4. **Completion blocked** - If history entry is missing, hook blocks until it's added

## Configuration

Hooks are defined directly in the `SKILL.md` YAML frontmatter. This keeps the skill self-contained with hooks defined alongside the skill definition.

## Testing

1. **Reference the skill** directly in a conversation
2. **Perform an operation** that uses the skill
3. **Observe hooks** - They should verify history logging
4. **Check History/** - Entry should be created automatically (or hooks will prompt for it)

## Expected Behavior

- ✅ Skill executes without manual history logging instructions
- ✅ Hooks automatically verify history entry exists
- ✅ If missing, hooks provide feedback to add it
- ✅ Completion blocked until history entry exists

## Differences from Standard Skills

**Standard skill:**

- Includes "ALWAYS: Log This Interaction" section
- Agent must remember to log manually
- No automatic verification

**This test skill:**

- ❌ NO manual history logging instructions
- ✅ Hooks automatically verify logging occurred
- ✅ Completion blocked if history missing
- ✅ Automated quality assurance

## Notes

- Hooks load at **session start** - restart Cursor after adding/modifying hooks
- Test with `claude --debug` to see hook execution logs
- Hook format follows plugin hook specification
- Prompt hooks use LLM reasoning (perfect for context-aware validation)
