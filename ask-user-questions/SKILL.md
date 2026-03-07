name: ask-user-questions
description: V1.0 - Expert in spec-based development using AskUserQuestionTool for thorough requirements gathering before implementation. Use when building large features or when user wants to be interviewed to create detailed specifications.
---

# Ask User Questions

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

## Purpose

Implements a spec-based development workflow for building large features. Start with a minimal spec or prompt, then use the AskUserQuestionTool to conduct an in-depth interview with the user before implementation.

## Workflow

### Phase 1: Requirements Gathering (Interview Session)

When the user wants to build a feature:

1. **Read the existing spec** (if provided) or start with the user's initial prompt
2. **Begin in-depth interviewing** using the AskUserQuestionTool
3. **Ask non-obvious questions** about:
   - Technical implementation details
   - UI & UX considerations
   - Edge cases and error handling
   - Performance and scalability concerns
   - Tradeoffs and architectural decisions
   - Integration points and dependencies
   - Security and access control
   - Testing strategies
   - Deployment and rollback plans
   - User workflows and user experience

4. **Continue questioning** until you have complete clarity on:
   - All functional requirements
   - All non-functional requirements
   - Technical approach and architecture
   - UI/UX design details
   - Success criteria and acceptance tests

5. **Write the comprehensive spec** to a file (default: `SPEC.md`)

### Phase 2: Implementation (Separate Session)

**Important**: Use a NEW session for implementation to ensure clean context.

In the new session:

1. Read the completed spec
2. Execute the implementation according to the spec
3. Reference back to the spec for decisions and details

## Question Guidelines

### Be In-Depth

- Dig deeper than surface-level requirements
- Explore implications and consequences
- Ask about edge cases and failure modes
- Challenge assumptions

### Avoid Obvious Questions

- ❌ "What should this feature do?"
- ✅ "How should the system behave when multiple users edit simultaneously?"

### Cover All Aspects

- **Technical**: Architecture, data models, APIs, performance
- **UX**: User flows, error states, accessibility, responsive design
- **Operations**: Monitoring, logging, deployment, rollback
- **Quality**: Testing strategy, coverage, regression prevention

### Example Question Patterns

**Technical Implementation**:

- "What's the expected scale? How many concurrent users/requests?"
- "Should this be synchronous or asynchronous? What are the latency requirements?"
- "How should we handle partial failures in this workflow?"

**UI & UX**:

- "What should the loading state look like while data is being fetched?"
- "How should validation errors be displayed to users?"
- "Should this work on mobile devices? What's the responsive breakpoint strategy?"

**Concerns & Tradeoffs**:

- "Are we optimizing for read or write performance here?"
- "Should we prioritize consistency or availability in this scenario?"
- "What's more important: feature completeness or time to market?"

## Spec File Format

The generated spec should include:

```markdown
# [Feature Name] - Specification

**Last Updated**: {date}
**Status**: Ready for Implementation

## Overview
{Brief description of feature and purpose}

## User Stories
{User-facing functionality}

## Technical Requirements
{Architecture, data models, APIs}

## UI/UX Specifications
{Wireframes, user flows, component specs}

## Edge Cases & Error Handling
{Failure modes and recovery}

## Performance & Scale
{Expected load, optimization requirements}

## Testing Strategy
{Unit, integration, e2e test plans}

## Security & Access Control
{Authentication, authorization, data protection}

## Deployment & Operations
{Rollout plan, monitoring, rollback}

## Open Questions
{Any remaining unknowns to address during implementation}
```

## When to Use This Skill

- User says "interview me about this feature"
- User wants to "build a large feature" or "complex functionality"
- User provides a minimal spec and asks for elaboration
- User mentions "spec-based development" or "requirements gathering"
- User asks to "create a detailed specification"

## Best Practices

1. **Separate sessions** - Interview in one session, implement in another
2. **Write everything down** - Capture all decisions in the spec
3. **Be thorough** - It's better to over-specify than under-specify
4. **Validate understanding** - Summarize and confirm before moving to next area
5. **Stay focused** - Complete one area before moving to the next
