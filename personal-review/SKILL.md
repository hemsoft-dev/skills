---
name: personal-review
description: V1.7 - Expert in drafting, analyzing, and improving quarterly and annual work performance reviews based on historical review patterns and achievements.
disable-model-invocation: true
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the personal-review directory (path contains 'personal-review'), verify that history logging occurred.

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
            Before stopping, if personal-review was used (check if any files in personal-review directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in personal-review directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}"
            3. Ensure the entry includes a one-line summary of what was done
            4. Verify retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Personal Review Assistant

Expert assistant for creating and refining work performance reviews (quarterly and annual).

## Overview

This skill helps you draft compelling performance reviews by:

- Analyzing patterns from your previous reviews stored in `reviews/`
- Identifying key achievements and growth areas
- Structuring content for quarterly check-ins or annual evaluations
- Maintaining consistency with your personal writing style and tone

## Review Storage

Store your previous review documents in the `reviews/` subfolder:

- Format: `reviews/{YYYY}-{Q#|Annual}-Review.md` or any format you prefer
- Examples: `reviews/2025-Q4-Review.md`, `reviews/2025-Annual-Review.md`

## Active Strategic Initiatives

When drafting goals, future-focus sections, or initiative summaries, use the
items below. Treat them as in-progress unless the user provides completed
results.

1. `ai-workflow`
   - Purpose: New `ai-workflow` repository that will contain a library of
     GitHub Agentic Workflows the engineering organization can use.
   - Review angles: Repo launch, reusable workflow catalog, documentation and
     examples, adoption by teams, and measurable reuse impact.

2. `sfl-pr-reviewer` — Q3/26
   - Purpose: SFL PR Reviewer full-spectrum reviewer (`sfl-pr-review.lock.yml`) — three evidence-based passes (Security, Correctness/Reliability, Quality/Maintainability) with Critical/High/Medium/Low severity, inline threads, review sheet verdict, and `SFL Reviewer Approval` check gate. Works alongside GitHub Copilot PR Reviewer in the `process-pr` dual-review zero-findings loop.
   - Review angles: Reviewer workflow dispatch (`workflow_dispatch` with `item_number`/`aw_context`), severity taxonomy and clean-sheet target (zero findings across all severities), `APPROVE` verdict vs. approval-gate distinction, thread resolution via `resolveReviewThread`, head-SHA matching, dual-reviewer readiness criteria, legacy `sfl-review` label fallback, and adoption across SFL-managed repos.

3. `sfl-canvas` (GitHub Copilot App) — Q3/26
   - Purpose: SFL Canvas GitHub Copilot App — Copilot extensibility surface (Copilot App / extension) for SFL orchestration, providing canvas-style UI and app-based interaction with the Set It Free Loop pipeline.
   - Review angles: Copilot App registration and installation model, canvas UI for issue/PR orchestration, SFL pipeline visibility (`sfl-issue` → `sfl-pr` → `sfl-done`), app permissions and auth, integration with existing `gh sfl` CLI and `workflows/` deployment model, and measurable impact on SFL adoption/throughput.

## Core Principles (Research-Backed)

### 1. Be Specific and Focused

- **Use concrete examples** over vague statements
- Focus on **observable behaviors and outcomes**, not personality traits
- Individualize content to your unique contributions, not generic measures
- Make feedback relevant to your role and within your control

### 2. Quantify Impact

- Include **metrics and measurable results** (%, $, time saved, users impacted)
- Connect individual achievements to **business outcomes**
- Show how daily work influences the big picture
- Use before/after comparisons to demonstrate improvement

### 3. Use the STAR Method

Structure accomplishments using:

- **Situation**: Context and challenge faced
- **Task**: Your specific responsibility
- **Action**: Steps you took (emphasize "I" not "we")
- **Result**: Measurable outcome and business impact

Example: "When the API latency increased to 500ms (Situation), I was tasked with improving performance (Task). I implemented Redis caching and optimized database queries (Action), reducing latency by 60% to 200ms and improving user satisfaction scores by 25% (Result)."

### 4. Balance Past, Present, and Future

- **Acknowledge the past**: Reflect on what you learned from challenges
- **Focus on the present**: Current strengths and contributions
- **Emphasize the future**: What you'll do next, how you'll grow further
- Avoid dwelling on mistakes; reframe as learning opportunities

### 5. Make It a Conversation

- Include your **perspective and self-reflection**
- Ask questions: "What could I do differently?" "How can I prepare for the future?"
- Show ownership of development areas
- Demonstrate active listening to feedback received

### 6. Be Authentic and Professional

- Use your natural voice while maintaining professionalism
- Balance confidence with humility
- Show genuine enthusiasm for growth and development
- Align personal goals with company/team objectives

## Usage Patterns

### Drafting a New Review

1. Specify review type (Quarterly/Annual) and time period
2. Provide key accomplishments, projects, initiatives, or focus areas
3. Assistant will draft review using patterns from previous reviews and best practices

### Analyzing Previous Reviews

1. Request analysis of stored reviews
2. Assistant identifies recurring themes, strengths, and areas for development
3. Provides insights on career progression and skill growth

### Improving Draft Reviews

1. Share your draft review content
2. Assistant enhances with STAR method, metrics, and specific examples
3. Improves clarity, impact, and alignment with company values
4. Strengthens language while maintaining your authentic voice

## Output Format

Reviews should be structured with clear sections:

### Accomplishments/Achievements

Use STAR method for each major accomplishment:

- Lead with impact-driven headlines
- Include specific metrics and measurable outcomes
- Show connection to business goals
- Highlight collaboration and leadership

### Core Strengths

- Identify 3-5 key strengths demonstrated this period
- Support each with specific behavioral examples
- Show consistency or growth in these areas

### Development Areas

- Frame as **future-oriented growth opportunities**, not failures
- Focus on specific, actionable behaviors to improve
- Show self-awareness and ownership
- Connect to career aspirations

### Goals and Objectives

- Set SMART goals (Specific, Measurable, Achievable, Relevant, Time-bound)
- Align with organizational priorities
- Include active strategic initiatives when they materially affect team or org outcomes
- Include both skill development and deliverable targets
- Show how achieving these advances your career

## Best Practices Checklist

**Content Quality:**

- ✅ Every major accomplishment uses STAR method
- ✅ Specific metrics included (avoid "increased," use "increased by 40%")
- ✅ Behavioral examples over personality descriptors
- ✅ "I" statements showing individual contribution
- ✅ Business impact clearly articulated

**Tone and Style:**

- ✅ Professional yet authentic voice
- ✅ Confident without arrogance
- ✅ Future-oriented, not dwelling on past mistakes
- ✅ Balanced (technical + soft skills + collaboration)
- ✅ Consistent with your historical review patterns

**Structure:**

- ✅ Clear section headers and organization
- ✅ Most impactful achievements listed first
- ✅ Logical flow from past → present → future
- ✅ Appropriate length (not too brief, not exhaustive)
- ✅ Proofread for clarity and typos

## Resources

| Resource | Link |
|----------|------|
| TalentGuard (Relias) | [relias.talentguard.com](https://relias.talentguard.com/Pages/HomePageAPI.aspx?menu=Home&ApplyStartTab=true) |
