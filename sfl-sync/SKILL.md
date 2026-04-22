---
name: sfl-sync
description: "V1.0 - Sync SFL workflow files, documentation, and scripts across consumer repositories."
---

# SFL Sync

Sync Set-it-Free-Loop (SFL) workflow files, documentation, and scripts between consumer repositories.

## Default Behavior

When activated, identify discrepancies in SFL files across all known consumer repositories and report them.

## Known Repositories

| Repository | Role | Path |
|------------|------|------|
| set-it-free-loop | Mother repo (source of truth) | `D:\github\HemSoft\set-it-free-loop` |
| hs-buddy | Consumer | `D:\github\Relias\hs-buddy` |
| relias-assistant | Consumer | `D:\github\Relias\relias-assistant` |

## Workflow

1. Scan all known repositories for SFL workflow files, documentation, and scripts
2. Compare files across repositories to identify discrepancies
3. Determine which version is newest — give newest version preference
4. Generate a report listing all discrepancies with suggested resolutions
5. If no discrepancies found, report that everything is in sync

## Rules

- The mother repo (`set-it-free-loop`) is the source of truth when versions are equal
- Always give the newest version preference regardless of which repo it is in
- Report discrepancies before making changes — do not auto-fix without user confirmation
