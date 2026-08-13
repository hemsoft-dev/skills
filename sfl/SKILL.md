---
name: sfl
description: >
  V2.2 - Commands: create-issue, status, explain, labels. Interact with the Set it
  Free Loop (SFL): create properly labeled issues, check pipeline status, and
  understand the automated issue-to-PR loop. Use when the user mentions SFL, wants
  an issue implemented by automation, or asks about the quality loop.
disable-model-invocation: true
---

# SFL — Set it Free Loop

## Default Behavior

When activated without a command, show the current repository's SFL status and summarize the next required action.

SFL turns a labeled GitHub Issue into a reviewed, merge-ready PR:

1. Issue labeled `sfl-issue` → **Dispatcher** validates it and triggers the **Processor**
2. Processor creates a branch, implements the fix, opens a PR (`sfl-pr`)
3. Copilot reviews the PR; the **Reactor** evaluates the results
4. Reactor promotes (`sfl-done`) or loops back for fixes (`sfl-needs-work`)
5. A human reviews and merges; the loop repeats

Scheduled audits (repo-audit, simplisticate-audit) can file `sfl-issue` issues automatically.
Motherrepo: `relias-engineering/set-it-free-loop` (workflows in `workflows/`, deployed by `gh sfl`).

## Commands

### `sfl create issue`

Compose the issue with the user, then confirm before creating:

- **Title**: plain imperative summary (no prefix required)
- **Labels**: `sfl-issue` (plus `risk:<trivial|low|medium|high>` when known)
- **Body**: `## Problem` section + `## Acceptance Criteria` checkbox list

Full guidance and example: `.sfl/INTAKE.md` in the deployed repo.

### `sfl status`

```bash
gh sfl status   # pipeline dashboard for this repo
gh sfl list     # recent SFL workflow runs
```

Label-level fallback: `gh issue list --label sfl-issue` and
`gh pr list --label sfl-pr` (add `--label sfl-done` for merge-ready PRs).

### `sfl explain`

Answer any SFL question (loop, labels, workflows, escalation) using the repo's
`.sfl/INTAKE.md`, `.sfl/policy.md`, and `.sfl/labels.json`.

### `sfl labels`

Print the label table below, or read `.sfl/labels.json` for colors and full descriptions.

## Labels

**Triggers** — apply these to drive the loop:

| Label | Effect |
|-------|--------|
| `sfl-issue` | Start automated implementation of an issue |
| `sfl-review` | Legacy installations only: run the full-spectrum review on a PR |
| `sfl-needs-work` | Trigger a fix cycle on a PR |
| `sfl-done` | Mark automation complete (skip remaining steps) |
| `sfl-pause` | Halt automation until removed |
| `no-agent` | Opt an issue out of all SFL automation |

**State** — applied by SFL, do not set manually:

| Label | Meaning |
|-------|---------|
| `sfl-processing` | Processor is running (in-flight lock) |
| `sfl-pr` | Identifies an SFL-managed PR |
| `sfl-ready-for-review` | PR awaiting Copilot review |
| `sfl-human-required` | Exceeds safe automation (cycle cap, credentials, business decision) |
| `risk:trivial/low/medium/high` | Change-risk hint for reviewers |
| `report` | Informational only — automation ignores it |

## Legacy deployments (pre-V6)

Repos still on SFL v1/v2 (check `.sfl/sfl.json` → `version`) use the old taxonomy:
issues enter via `agent:fixable` with `[agent-fix]` title prefix; PRs carry
`agent:pr` / `human:ready-for-review`; fix state is `agent:in-progress`,
`agent:blocked`, `agent:queued`, `analyzer:blocked`. Upgrade with `gh sfl sync`
to get the `sfl-*` model.

Current installations dispatch `.github/workflows/sfl-pr-review.lock.yml` with pull-request context. Use the
`copilot-pr-processor` skill for current review requests; apply `sfl-review` only when its detection helper reports
`legacy_label` mode.

## Key Files (per deployed repo)

| File | Purpose |
|------|---------|
| `.sfl/sfl.json` | Deployment manifest (version, tier, components) |
| `.sfl/sfl-config.yml` | User-editable configuration |
| `.sfl/INTAKE.md` | Issue intake guide with example |
| `.sfl/policy.md` | Governance policy |
| `.sfl/labels.json` | Label taxonomy snapshot |
