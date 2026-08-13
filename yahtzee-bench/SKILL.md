---
name: yahtzee-bench
description: "V1.1 - Commands: Create, Score, Status. Create: build a cross-platform Electron 6-dice Yahtzee game (Windows executable, up to 4 players, selectable AI opponents, rich scoresheet, gold-standard UX) as a self-contained entry, and record run telemetry (date, time taken, cost) in RUNS.md. Score and Status are owner-only commands for reviewing finished entries."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the yahtzee-bench SKILL directory only (path contains '.agents\skills\yahtzee-bench' — NOT the game entries repo at D:\github\HemSoft\yahtzee-bench, which must not trigger logging), verify that history logging occurred.

            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)

            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if the yahtzee-bench skill was used (check if any files in the skill directory '.agents\skills\yahtzee-bench' were modified — the entries repo D:\github\HemSoft\yahtzee-bench does NOT count), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in the yahtzee-bench skill directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Yahtzee Bench

Commands: **Create** (default) builds a game entry. **Score** and **Status** are owner-only — only touch those sections when the owner explicitly asks for them.

## Create (default)

Build the game described below. Treat it as a straightforward product request from the user. Other agents may be building their own entries in the same repo at the same time — the workspace flow below keeps everyone out of each other's way.

Work unaided: do not invoke, load, or reference any other skills for this task — no skill-provided scripts, templates, checklists, or helpers. Use only your own tools and judgment.

### The ask

Create a desktop **6-dice Yahtzee** game as an **Electron** application.

**Requirements**

- **Cross-platform by design.** The test deliverable is a working **Windows executable** (installer or portable `.exe`). The build tooling must also be configured for macOS and Linux targets, even though only the Windows build is actually produced and verified.
- **Up to 4 players** on a single scoresheet. The player chooses the lineup: any mix of human players and **AI opponents** (solo vs AI must work; watching an all-AI game is a nice touch).
- **Design the scoresheet yourself.** 6-dice Yahtzee has no single standard ruleset — include **as many scoring combinations as possible** (upper section, pair/kind/straight/house variants, chance, six-of-a-kind, bonuses, ...) with sensible values and a coherent grand total.
- **Gold-standard UX.** Visually appealing and satisfying to play: tactile dice interactions, clear turn flow and feedback, responsive layout, polished visuals. Aim for the best digital Yahtzee experience the user has ever played.

### Workspace (do this first)

The entries repo is `D:\github\HemSoft\yahtzee-bench`. Multiple agents may be working in it concurrently, so never build in the main checkout:

1. If the repo doesn't exist yet, create it (`git init` with an initial commit on `main`).
2. Create your own branch and worktree:
   `git -C D:\github\HemSoft\yahtzee-bench worktree add D:\github\HemSoft\yahtzee-bench-worktrees\{model-name} -b entry/{model-name}`
3. Build the entire game inside that worktree, in a `{model-name}\` subfolder (i.e. `D:\github\HemSoft\yahtzee-bench-worktrees\{model-name}\{model-name}\`) — so it merges to `D:\github\HemSoft\yahtzee-bench\{model-name}\`.
4. Only ever add/commit inside your own `{model-name}\` folder. Never touch, stage, or modify another entry's folder.
5. When finished and verified: commit on your branch, merge into `main` (entries are disjoint folders, so the merge must be conflict-free — if it isn't, stop and report instead of forcing anything), remove the worktree (`git worktree remove`), and delete your branch.

`{model-name}` = a short lowercase identifier of the model building the entry (e.g. `gpt-5`, `claude-opus-4-7`, `kimi-k3`).

### Run telemetry (required)

Track this run in `RUNS.md` in this skill folder — never in the entries repo:

1. At the start of the run, add a row to the table: contender name, model-id, run date, Status `Running`.
2. When the run ends, update the same row: time taken, cost (actual spend if your platform reports it, otherwise `unknown`), and Status `Complete` or `Failed`.

### Output

- The entry folder must be fully self-contained: source code, build configuration, a README (how to run, how to build), and the **built Windows executable** (e.g. under `dist\` or `release\`).
- Work autonomously — make reasonable product decisions yourself and do not interrupt the user with questions.
- Verify before finishing: install dependencies, run the production build, confirm the Windows `.exe` exists and launches.

When done, report back: what was built, the scoresheet categories included, how the AI opponents work, how to run it, and where the Windows executable lives.

## Score (owner-only)

Only when the owner explicitly asks. Read `SCORING.md` in this skill folder and follow it exactly.

Hard rules:

- Never copy `SCORING.md`, `BENCHMARK-SCORES.md`, or any scoring content into `D:\github\HemSoft\yahtzee-bench` or any entry folder.
- Never modify entry folders while scoring.
- Always score in a fresh session — never in a session that also performs a Create.
- Do not invoke, load, or reference any other skills while scoring — no skill-provided checklists, heuristics packs, or scripts. `SCORING.md` and `BENCHMARK-SCORES.md` are the entire rubric.

## Status (owner-only)

Print a compact overview: entries merged in `D:\github\HemSoft\yahtzee-bench` (name, Windows exe present, README present, last modified), active worktrees and unmerged `entry/*` branches (work in progress), the run log from `RUNS.md` (contender, run date, time taken, cost, status), plus vote completeness per judge in `BENCHMARK-SCORES.md` (which judges have scored which entries, and whose own-entry cell is pending). Do not print actual scores unless the owner asks.
