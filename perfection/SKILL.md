---
name: perfection
description: "V1.1 - Commands: audit, fix. Discovers and runs a repository's declared quality gates, reports evidence and gaps, and fixes failures when requested."
disable-model-invocation: true
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the perfection directory (path contains 'perfection'), verify that history logging occurred.

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
            Before stopping, if perfection was used (check if any files in perfection directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in perfection directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. Verify the retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Log this interaction in History/{YYYY-MM-DD}.md using: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Perfection

Audit a repository against its real quality policy. Do not impose generic
targets such as 100 percent coverage unless the repository declares them.

## Commands

### `audit`

Run a read-only quality audit.

1. Confirm the repository root and read its applicable `AGENTS.md` files.
2. Inspect the working tree. Preserve all existing changes.
3. Discover quality gates from CI workflows, build and package manifests,
   configuration files, and documented repository scripts.
4. Record each gate's exact command and declared target before running it.
5. Run every independent local gate, even after another gate fails. Capture the
   exit code and useful evidence. Never estimate coverage, CRAP, mutation, or
   other metrics.
6. Mark a gate `blocked` when credentials, services, missing tools, or an
   impractical runtime prevent a valid result. State the exact blocker. Do not
   install tools, change dependencies, or trigger remote workflows to clear it.
7. Inspect for material gaps that declared gates may miss, such as ignored test
   failures, warnings, stale exclusions, or untested error paths. Report only
   findings backed by repository evidence.
8. Recheck the working tree. Remove only temporary artifacts created by this
   audit when their exact paths are known.

Report:

| Gate | Command | Target | Result | Evidence |
| --- | --- | --- | --- | --- |

Use `pass`, `fail`, or `blocked`. Follow the table with the highest-priority
finding, any uncovered policy gap, and the final working-tree state.

### `fix`

Run `audit`, then fix confirmed failures only when the user requested changes.

1. Reproduce one failure with its exact command.
2. Make the smallest root-cause fix that follows repository conventions.
3. Do not weaken thresholds, add suppressions, update snapshots, or exclude code
   only to make a gate pass. Treat any gate-policy change as a separate decision.
4. Run the narrow check that proves the fix, then run affected regression tests.
5. Continue through the confirmed failures. Keep blocked gates visible.
6. Finish with the full audit and inspect the complete diff and working tree.

Do not commit, push, create issues or pull requests, change remote settings, or
dispatch workflows unless the user separately asks for that action.

## Rules

- Repository instructions and CI are the source of truth. If they conflict,
  report the conflict instead of choosing the easier target.
- Use the repository's pinned package manager and versions.
- A clean audit means every discovered gate passed and no evidence-backed gap
  remains. It does not promise that the code is flawless.
- External dashboards count only when checked during the current run. Label
  cached or historical results with their date.

## History

After using this skill, append `## HH:MM - {Action Taken}` and a one-line
summary to `History/{YYYY-MM-DD}.md`. Note whether a retrospective found a
reusable improvement. Get the timestamp from the shell, never an estimate.
