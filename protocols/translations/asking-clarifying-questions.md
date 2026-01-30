# Protocol: Asking Clarifying Questions

## When to Use

When a skill instructs you to "ask clarifying questions" or "gather requirements from the user" without specifying the exact format.

## Detailed Instructions

1. **Format**: Use a clean, structured approach with numbered questions
2. **Grouping**: If you have multiple categories of questions, group them under clear headings (e.g., "## Configuration Questions", "## Scope Questions")
3. **Clarity**: Each question should be:
   - Specific and actionable
   - Easy to understand
   - Focused on one topic per question
4. **Context**: Provide brief context before questions if needed (e.g., "To help me create this skill, I need to understand...")
5. **Options**: When appropriate, offer multiple choice options or examples
6. **Number**: Ask 3-7 questions typically; avoid overwhelming with too many questions at once
7. **Follow-up**: If answers prompt more questions, ask them in a subsequent round

## Example Output

```markdown
To help me create this effectively, I have a few questions:

## Scope Questions

1. **Primary Use Case**: What's the main scenario where this will be used?
   - Option A: [Example scenario]
   - Option B: [Another scenario]
   - Other: [Your specific case]

2. **Frequency**: How often will this be invoked?
   - Daily
   - Weekly
   - On-demand only

## Technical Questions

3. **Dependencies**: Are there any specific tools or systems this needs to integrate with?

4. **Output Format**: Should the result be:
   - Displayed in terminal
   - Saved to a file
   - Both

Let me know your preferences and I'll proceed!
```

## Key Principles

- Be thorough but not exhausting
- Make it easy for the user to answer quickly
- Use formatting to improve readability
- Always end with a clear next step or call to action
