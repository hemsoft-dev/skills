---
name: llm-recommender
description: V1.2 - Helps compare and recommend LLMs based on context limits, pricing, speed, and benchmark performance.
---

# LLM Recommender

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Reference `LLMs.md` in this directory for model specifications. Help users select the best LLM for their use case.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Recommendation Criteria

When recommending models, consider:

- **Task Type**: Coding, reasoning, chat, multimodal, agentic workflows
- **Context Needs**: How much input/output the task requires
- **Budget**: Cost per million tokens (input/output)
- **Speed**: Latency and throughput requirements
- **Host Preference**: OpenRouter, GitHub Copilot, direct API

## Quick Filters

| Use Case | Recommended Models |
|----------|-------------------|
| Cheapest for coding | Grok Code Fast 1, Gemini 3 Flash, Kimi K2 |
| Best for long context | Gemini 3 Pro (1M), GPT-4.1 (1M), Claude Sonnet 4.5 (1M) |
| Fastest response | Claude Haiku 4.5, Gemini 3 Flash, GPT-5.2 Chat |
| Best reasoning | Claude Opus 4.5, Gemini 3 Pro, GPT-5.2 Pro |
| Best value agentic | Kimi K2 Thinking, Gemini 3 Flash |

## Cost Calculation

For GitHub Copilot models, use multiplier × base rate.
For OpenRouter/direct API, calculate: `(input_tokens / 1M × input_price) + (output_tokens / 1M × output_price)`

## Updating the Registry

When adding new models to `LLMs.md`, include all required fields:

- Model Full Name, Reference Name, Created Date
- Host, Cost (input/output or multiplier)
- Context (input/output limits), Modalities
- Description with benchmarks and use cases
