---
name: anti-slop
description: V1.0 - Detects AI-generated slop patterns in text, code, PRs, and commit messages. Provides a slop score and actionable rewrite suggestions. Use when reviewing content for AI-generated low-quality patterns, improving authenticity of writing, or auditing code for excessive AI-style comments.
---

# Anti-Slop

Detect and fix AI-generated slop in any content. Inspired by [peakoss/anti-slop](https://github.com/peakoss/anti-slop) — battle-tested rules derived from 130+ manually reviewed AI slop PRs.

**Default action**: When given text, code, or a file to review, run all applicable checks and produce a Slop Report.

## Check Categories

Run checks relevant to the content type. Skip checks that don't apply.

### 1. Slop Words & Phrases

Scan for overused AI-generated words and phrases. Flag each occurrence with line number.

| Category | Flagged Terms |
|---|---|
| **Power words** | delve, tapestry, vibrant, landscape, crucial, leverage, streamline, robust, comprehensive, seamlessly, harness, foster, bolster, spearhead, pivotal, multifaceted, synergy, paradigm, nuanced, intricate, holistic |
| **Filler openers** | "In today's fast-paced world", "It's worth noting", "It's important to note", "Let's dive in", "Without further ado", "In the ever-evolving", "In an era of" |
| **Hype phrases** | game-changer, cutting-edge, state-of-the-art, best-in-class, next-generation, unlock the full potential, take it to the next level, revolutionize |
| **AI assistantisms** | "Absolutely!", "Great question!", "I hope this helps!", "Feel free to", "Happy to help", "Let me know if you need" |
| **Hedge padding** | "It could potentially", "It might be worth considering", "One could argue that", "It goes without saying" |
| **Transition crutches** | "However," (sentence start overuse), "Moreover,", "Furthermore,", "Additionally," (when 3+ in one text) |
| **Closing slop** | "In conclusion", "To summarize", "In summary", "All in all", "At the end of the day", "Moving forward" |

**Scoring**: 1 point per unique flagged term. 0.5 points for each additional occurrence of the same term.

### 2. Structural Slop

Detect formulaic AI writing patterns.

| Pattern | What to Flag |
|---|---|
| **Restatement opening** | Response begins by restating the user's question or request |
| **Numbered everything** | "First... Second... Third..." structure when bullets or prose would be clearer |
| **Identical paragraph starts** | 3+ consecutive paragraphs starting with the same word/pattern |
| **Padded bullet lists** | Bullets that rephrase the same idea in slightly different words |
| **Unnecessary summaries** | Final paragraph that merely restates what was already said |
| **Emoji overuse** | More than 2 emojis in non-casual content |
| **Excessive bold/emphasis** | More than 20% of text is bold or italic |
| **Header inflation** | Using H2/H3 for what should be a simple paragraph |
| **Em-dash overload** | More than 3 em-dashes (—) in a single response |

**Scoring**: 2 points per structural pattern detected.

### 3. Code Slop

Detect AI-generated code quality issues.

| Pattern | What to Flag |
|---|---|
| **Obvious comments** | Comments that restate what the code literally does: `i++ // increment i` |
| **Comment density** | More than 1 comment per 3 lines of code |
| **Over-documentation** | Docstrings/JSDoc on trivial one-liner functions |
| **Defensive overkill** | Try-catch/error handling for scenarios that can't happen |
| **Unnecessary type annotations** | Redundant types in languages with inference: `const x: string = "hello"` |
| **Pattern overload** | Using design patterns where a simple function would suffice |
| **Name verbosity** | Excessively long variable names: `userAuthenticationTokenExpirationDate` |
| **Apologetic comments** | `// TODO: This could be improved`, `// Note: This is a simple implementation` |

**Scoring**: 1 point per code slop instance.

### 4. PR & Commit Slop

For PR descriptions and commit messages specifically.

| Pattern | What to Flag | Threshold |
|---|---|---|
| **Description too long** | Excessively verbose PR description | > 2500 chars |
| **Emoji in PR** | Emojis in PR title or description | > 2 |
| **Excessive code refs** | Inline code references in PR description to appear thorough | > 5 |
| **Commit message length** | Overly verbose commit messages | > 500 chars |
| **Non-conventional format** | Missing conventional commit prefix (`feat:`, `fix:`, etc.) | Any |
| **Template violation** | PR description doesn't follow repo template | Any |

**Scoring**: 1 point per PR/commit slop instance.

## Slop Score

Calculate and display a rating:

| Score | Rating | Verdict |
|---|---|---|
| 0 | **Clean** | No slop detected |
| 1–3 | **Mild** | Minor AI artifacts, easy fixes |
| 4–7 | **Moderate** | Noticeable AI patterns, needs revision |
| 8–12 | **Heavy** | Clearly AI-generated, significant rewrite needed |
| 13+ | **Pure Slop** | Rewrite from scratch recommended |

## Output Format

Always produce a **Slop Report** with this structure:

```markdown
## Slop Report

**Score**: {score} / {rating}
**Content type**: {text | code | PR | commit | mixed}

### Findings

| # | Check | Location | Issue | Suggestion |
|---|---|---|---|---|
| 1 | {check-name} | {line/section} | {what was found} | {specific fix} |
| 2 | ... | ... | ... | ... |

### Rewrite Suggestions

{For each major finding, provide a before/after showing the specific improvement.
Keep fixes minimal and targeted — don't rewrite content that's fine.}
```

## Rules

1. **Anti-slop, not anti-AI**: Good AI-assisted content that reads naturally is fine. Only flag content that exhibits lazy/generic AI patterns.
2. **Context matters**: Technical documentation may legitimately use words like "comprehensive" or "robust". Flag density, not individual legitimate uses.
3. **Be specific**: Every finding must include the exact text flagged and a concrete replacement or removal suggestion.
4. **Density over presence**: A single "However," is fine. Five "However," openers in one text is slop.
5. **Keep suggestions human**: Rewrites should sound natural, not just swap one AI word for another.
6. **Match the register**: If the original is casual, keep suggestions casual. If formal, keep formal.
