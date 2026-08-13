# Yahtzee-Bench — Scores (owner-only)

Voting matrix for all entries in `D:\github\HemSoft\yahtzee-bench`. Every participating model judges all **other** entries; the owner's votes count as one more judge. Full protocol: see `SCORING.md`.

**Rules**

- Scale: integers 1–10 per category (anchors in `SCORING.md`).
- A judge never scores its own entry — that cell stays blank and is excluded from averages.
- Judges score independently before reading other judges' tables.
- This file never leaves the skill folder.

## Categories

| # | Category | What to look for | Lineage |
|---|----------|------------------|---------|
| 1 | Build & Launch | Windows exe exists, installs/launches cleanly, zero friction; documented build works if exe missing | WebDev Arena failure taxonomy, ISO 25010 installability |
| 2 | Gameplay Correctness | Turn structure (3 rolls, hold/unhold), scoring math, category eligibility enforced, end-of-game/winner, edge cases | ISO 25010 functional suitability |
| 3 | Scoresheet Depth & Creativity | Breadth and variety of 6-dice combinations, balanced values, bonuses, coherent overall ruleset | Task-specific (open-ended design) |
| 4 | AI Opponents | Opponent selection UX, sensible hold/score decisions, pacing, multiple AIs in one game | Task-specific |
| 5 | Visual Design | Theme coherence, typography, color, dice presentation, layout quality | Awwwards (Design), ISO 25010 UI aesthetics |
| 6 | Game Feel & Delight | Dice animation/physics, sound, micro-interactions, celebration moments, personality | PLAY game-usability heuristics, Awwwards (Creativity) |
| 7 | Usability & Flow | Status visibility (whose turn, rolls left), what-to-do-next clarity, error prevention, recognition over recall | Nielsen's 10 heuristics |
| 8 | Performance & Stability | Smooth animations, no jank, crashes, or hangs across a full game | ISO 25010 reliability & performance efficiency |
| 9 | Code & Architecture | Project structure, readability, separation of concerns, maintainability | ISO 25010 maintainability |
| 10 | Cross-Platform & Packaging | macOS/Linux build targets configured, no OS-locked code or paths, packaging quality | ISO 25010 portability |

## Judge: Owner (User) — {date}

| Entry | 1 Build | 2 Correct | 3 Sheet | 4 AI | 5 Visual | 6 Feel | 7 UX | 8 Perf | 9 Code | 10 XPlat | Avg | Notes |
|-------|---------|-----------|---------|------|----------|--------|------|--------|--------|----------|-----|-------|
| _{entry}_ | | | | | | | | | | | | |

## Judge: {model-id} — {date}

| Entry | 1 Build | 2 Correct | 3 Sheet | 4 AI | 5 Visual | 6 Feel | 7 UX | 8 Perf | 9 Code | 10 XPlat | Avg | Notes |
|-------|---------|-----------|---------|------|----------|--------|------|--------|--------|----------|-----|-------|
| _{entry}_ | | | | | | | | | | | | |

## Summary Matrix (averages across all judges)

| Entry | 1 Build | 2 Correct | 3 Sheet | 4 AI | 5 Visual | 6 Feel | 7 UX | 8 Perf | 9 Code | 10 XPlat | Overall | Rank |
|-------|---------|-----------|---------|------|----------|--------|------|--------|--------|----------|---------|------|
| _{entry}_ | | | | | | | | | | | | |
