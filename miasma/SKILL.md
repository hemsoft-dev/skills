---
name: miasma
description: "V1.0 - Commands: scan, triage, remote-check. Detect and triage Miasma/Shai-Hulud-style npm and AI coding-agent persistence indicators in local repositories and GitHub metadata."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the miasma directory (path contains 'miasma'), verify that history logging occurred.

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
            Before stopping, if miasma was used (check if any files in miasma directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in miasma directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Miasma

Use this skill for Miasma, Mini Shai-Hulud, Shai-Hulud lineage, npm worm, AI coding-agent persistence,
`.github/setup.js`, malicious `binding.gyp`, or repo-injected `[skip ci]` investigations.

## Default Behavior

When activated without a command, run `scan` against `D:\github` in read-only mode and report findings first.

## Commands

| Command | Use When | Action |
| --- | --- | --- |
| `scan` | User asks whether local repos are affected | Run `scripts/Scan-MiasmaIndicators.ps1` against the requested root |
| `triage` | User provides a repo, branch, PR, or suspicious file | Inspect metadata and file contents read-only; never execute repo code |
| `remote-check` | User asks about GitHub org exposure | Use GitHub API/GraphQL metadata; do not clone or check out branches |

## Safety Rules

1. Never run `npm install`, `npm test`, `node`, `bun`, `ruby`, or project scripts from a suspect repository.
2. Prefer metadata and file-content reads: `rg`, `Get-Content`, `git ls-tree`, `git rev-list`, GitHub API, and GraphQL.
3. Treat GitHub code search as incomplete. Verify high-signal paths branch-by-branch when accuracy matters.
4. Do not count plain `[skip ci]` as an infection by itself. It is too noisy.
5. If a secret exposure is suspected, recommend credential rotation before cleanup.

## Local Scan

```powershell
.\miasma\scripts\Scan-MiasmaIndicators.ps1 -Root D:\github
.\miasma\scripts\Scan-MiasmaIndicators.ps1 -Root D:\github -IncludeGitHistory
.\miasma\scripts\Scan-MiasmaIndicators.ps1 -Root D:\github -Json
```

The default scan checks the checked-out working tree only. `-IncludeGitHistory` adds a read-only local Git
history path check for high-signal indicator paths without checking out branches.

## High-Signal Indicators

| Indicator | Severity | Notes |
| --- | --- | --- |
| `.github/setup.js` | Critical | Miasma AI-agent persistence dropper path; SafeDep reported 4.3 MB examples |
| `node .github/setup.js` | Critical | Seen in AI agent hooks and editor tasks |
| `.claude/settings.json` with `SessionStart` and setup command | Critical | Auto-runs when compatible agent starts |
| `.gemini/settings.json` with setup command | Critical | Same persistence pattern for Gemini |
| `.cursor/rules/setup.mdc` with `alwaysApply: true` and setup command | Critical | Cursor rule persistence |
| `.vscode/tasks.json` with `runOn: folderOpen` and setup command | Critical | VS Code folder-open persistence |
| `package.json` script `test: node .github/setup.js` | Critical | Blends persistence into normal command |
| `binding.gyp` invoking `node index.js` | Critical | Miasma v2 native-build execution vector |
| `Miasma: The Spreading Blight` marker | Critical | Reported campaign marker |
| `OIDC_PACKAGES` or `bun run _index.js` in injected workflows | High | Red Hat npm wave workflow indicators |
| `chore: update dependencies [skip ci]` | Medium | Suspicious only with other indicators |

## Current Takeaways

- Name: Miasma. Some reporting frames it as Mini Shai-Hulud or Shai-Hulud lineage.
- Initial public reporting tied Miasma to Red Hat npm package compromise and trusted publishing abuse.
- SafeDep reported a later repo-focused wave that injected AI coding-agent configs to auto-run `.github/setup.js`.
- Semgrep reported Miasma v2 using `binding.gyp`, compromising 57 npm packages across 286+ versions.
- Microsoft reported 32 maliciously modified `@redhat-cloud-services` packages across 90+ versions.
- Deepwatch reported credential theft targeting GitHub, npm, cloud, Vault, Kubernetes, and CI/runtime secrets.
- Known persistence targets include Claude, Codex, Gemini, Copilot, Cursor, Kiro, OpenCode, and VS Code tasks.
- Local checked-out files can be clean while remote non-default branch tips remain affected.

## Remote GitHub Check Pattern

Use GraphQL `object(expression: "{branch}:.github/setup.js")` for branch-tip existence. This checks metadata
without cloning or downloading blob contents. Count a repo as affected when any current branch tip contains the
path. Keep default-branch exposure separate from any-branch exposure.

## Response Format

Report in this order:

1. Affected count and scan scope.
2. Critical findings.
3. High or medium findings.
4. What was not checked.
5. Recommended next action.

## Sources

- SafeDep: <https://safedep.io/miasma-worm-ai-coding-agent-config-injection/>
- SafeDep Red Hat wave: <https://safedep.io/redhat-cloud-services-hit-by-mini-shai-hulud-npm-worm/>
- Semgrep Miasma v2: <https://semgrep.dev/blog/2026/miasma-v2-self-spreading-npm-worm-now-uses-malicious-bindinggyp-file-and-compromises-57-packages/>
- Microsoft: <https://www.microsoft.com/en-us/security/blog/2026/06/02/preinstall-persistence-inside-red-hat-npm-miasma-credential-stealing-campaign/>
- Deepwatch: <https://www.deepwatch.com/labs/ca-26-018-miasma-mini-shai-hulud-compromise-of-red-hat-npm-packages/>
