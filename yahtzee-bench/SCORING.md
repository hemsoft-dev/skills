# Yahtzee-Bench — Scoring Protocol (owner-only)

You are judging Electron Yahtzee games. Each subfolder of `D:\github\HemSoft\yahtzee-bench` is one entry; the folder name identifies the model that built it.

This file and `BENCHMARK-SCORES.md` live in the skill folder only. Never copy them into the entries repo, reference them in commit messages, or mention scoring inside any entry.

Judge unaided: do not invoke, load, or reference any other skills while scoring — no skill-provided checklists, heuristics, or scripts. This protocol plus the category table in `BENCHMARK-SCORES.md` is the entire rubric.

## Step 0 — Identify yourself

Determine your own model identity and the entry folder that belongs to it. If you cannot tell, ask the owner which folder is yours. **You must not score your own entry** — leave that row out of your table.

## Step 1 — Evaluate each entry

Evaluate from the main checkout at `D:\github\HemSoft\yahtzee-bench` (make sure it is on `main` and up to date). If an expected entry is missing, it may be sitting unmerged on an `entry/*` branch — check `git branch -a` and `git worktree list`, then tell the owner instead of merging anything yourself. Never judge from inside a worktree.

For every entry except your own:

1. **Build & launch**: Look for the Windows executable (`dist\`, `release\`, or wherever the README says). If it is missing, attempt the documented build. Record friction honestly — it feeds category 1.
2. **Play**: Launch the game and play at least one full game against AI opponents. Also try a 3–4 player setup. Deliberately probe: hold/unhold dice across rolls, score in as many different category types as possible, finish the game, check the end-of-game and winner flow.
3. **Inspect**: Read the scoresheet for breadth of combinations, skim the source for structure, and check the Electron packaging config for macOS/Linux targets.

## Step 2 — Score

Rate each entry **1–10 (integers) per category** — the categories and what to look for are defined in `BENCHMARK-SCORES.md`.

Anchors:

| Score | Meaning |
|-------|---------|
| 1–2   | Broken or absent |
| 3–4   | Bare minimum, significant problems |
| 5–6   | Functional but rough |
| 7–8   | Good, polished |
| 9–10  | Exceptional, best-in-class |

Use the full range. Do not cluster everything at 7. Score independently: complete your table **before** reading other judges' tables.

## Step 3 — Record

1. Add or update your judge table in `BENCHMARK-SCORES.md` under `## Judge: {your-model-id} — {YYYY-MM-DD}`, one row per entry scored, each with a short evidence-based note.
2. Recompute the **Summary matrix**: per-category averages across all judge tables (owner included), overall average, and rank. Leave blank cells (e.g. a judge's own entry) out of the averages.
3. Never alter another judge's table.
