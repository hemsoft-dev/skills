---
name: miasma
description: "V1.1 - Commands: scan, triage, remote-check. Detect and triage Miasma/Shai-Hulud-style npm and AI coding-agent persistence indicators in local repositories and GitHub metadata, with Relias SSH signed-commit guidance."
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
| `pr-check` | User asks whether GitHub PR branches/ranges are Miasma-free | Run `scripts/Test-MiasmaPullRequest.ps1`; default output is only clean/do-not-reopen status, with details behind `-Verbose` or `-Json` |
| `remote-check` | User asks about GitHub org exposure | Use GitHub API/GraphQL metadata; do not clone or check out branches |
| `remote-audit` | User asks for repeatable org-wide branch exposure report | Run `scripts/Invoke-MiasmaRemoteAudit.ps1`; keep JSON, TXT, and HTML under `output/remote/<org>/<timestamp>` |
| `signing-setup` | User needs work-only Relias signed commits | Run `scripts/Setup-ReliasSignedCommits.ps1`; keep signing scoped to `D:\github\Relias` |

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

## Pull Request Check

Use this to decide whether a closed or reopened PR's current branch range is clean enough to preserve PR review history.
It uses the GitHub API only: no clone, no checkout, and no project command execution.

```powershell
cd $env:USERPROFILE\.agents\skills\miasma

# PRs closed since June 15, 2026 in all repos under relias-engineering
.\scripts\Test-MiasmaPullRequest.ps1

# PRs closed since a specific date in all repos under relias-engineering
.\scripts\Test-MiasmaPullRequest.ps1 `
  -ClosedSince 2026-06-15

# PRs closed since June 15, 2026 in one repo
.\scripts\Test-MiasmaPullRequest.ps1 `
  -Repo example-repo

# One PR
.\scripts\Test-MiasmaPullRequest.ps1 `
  -Repo example-repo `
  -PR 123

.\scripts\Test-MiasmaPullRequest.ps1 `
  -PullRequestUrl https://github.com/relias-engineering/example-repo/pull/123

# Also generate the fixed-name HTML report
.\scripts\Test-MiasmaPullRequest.ps1 `
  -Repo example-repo `
  -Report

# Resume after an already-printed clean PR from an interrupted org/repo scan
.\scripts\Test-MiasmaPullRequest.ps1 `
  -ResumeAfter incident-service#86

# Include a known orphaned/unreferenced commit SHA from chat, audit logs, or a GitHub commit URL
.\scripts\Test-MiasmaPullRequest.ps1 `
  -AdditionalCommit relias-engineering/Builder-Buddy-Vs-RPA@<commit-sha> `
  -Report
```

The script checks both:

- every current PR commit tree returned by GitHub for high-signal paths/content; and
- the current final PR file delta, scanning only added patch lines as merge-introducing content.

For squash-merge decisions, the final delta is the artifact that enters the protected branch. For "safe to inspect or
reopen this branch" decisions, the current PR commit trees must also be clean. A clean result does not audit older
force-pushed-away PR timeline SHAs unless those commits are still in the current PR commit list.
GitHub can still serve known orphaned/unreferenced commit URLs after refs move, but the normal GitHub API does not
reliably enumerate every orphaned commit in a repository. If a chat thread, audit log, or GitHub commit URL identifies
one of those SHAs, pass it with `-AdditionalCommit` so the commit tree is scanned and included in JSON/HTML.

Default output is intentionally terse:

```text
relias-engineering
  relias-assistant
    PR #419 - Clean
    PR #418 - Clean
  content-library-service
    PR #512 - Do not reopen this PR - Critical Miasma setup dropper path (CommitTree abc123 .github/setup.js)
```

When `-PR` is omitted, the script scans PRs closed since `-ClosedSince`; `-ClosedSince` defaults to `2026-06-15` and
continues forward to the current time.
`-PR` requires `-Repo` because pull request numbers are repository-scoped. Multi-repo scans prompt before scanning and
show how many repositories and pull requests will be processed.
Use `-ResumeAfter REPO#PR` or `-ResumeAfter OWNER/REPO#PR` only when the previous console output already showed that
PR as clean. The resumed JSON/HTML contains only the remaining tail after that marker; it does not reconstruct earlier
clean console output from the aborted run.

Every completed run writes fixed-name JSON results to:

```text
output/pr-check/miasma-pr-check-results.json
```

Use `-Report` to also write the fixed-name HTML report:

```text
output/pr-check/miasma-pr-check-report.html
```

If only the HTML report template changed and a scan is already running or already complete, regenerate HTML from the
fixed JSON artifact without making GitHub API calls:

```powershell
.\scripts\Test-MiasmaPullRequest.ps1 -RegenerateReport
```

Use `-Verbose` for progress/API detail, `-Json` for structured results, and `-Help` for usage.
With `-Verbose`, the script lists the payload indicators once per run, and then names each checked PR's state, source
branch (PR head), target branch (PR base), commit-tree count, and final-diff file count. Organization and repository are
repeated only when they change.

## Remote Audit

Use this for the repeatable Relias-style org audit. It uses GitHub API metadata only:
no clone, no checkout, no project command execution.

```powershell
cd $env:USERPROFILE\.agents\skills\miasma

.\scripts\Invoke-MiasmaRemoteAudit.ps1 `
  -Owner relias-engineering `
  -ScanMode BranchTip `
  -Since ([datetime]'2026-05-01T04:00:00Z') `
  -Until (Get-Date)
```

Use `-ScanMode BranchTip` for cleanup verification: it answers whether current
remote branch tips still contain the indicator paths. Use `-ScanMode
CommitWindow` to reproduce the earlier incident-evidence style report that scans
all commits in the requested date window. Use `-ScanMode Both` when you need both
current branch-tip status and historical finding-bearing commits in one artifact.

For a user-executed handoff run with auth and rate-limit preflight, use:

```powershell
.\scripts\Start-ReliasMiasmaBranchTipReport.ps1 -Background
```

The handoff script defaults to `fhemmerrelias`, validates Relias repo access,
checks REST and GraphQL rate-limit headroom, and runs BranchTip with a 2000 ms
delay between GitHub calls.

Artifacts are written under `output/remote/<org>/<timestamp>/`:

- `miasma-remote-scan.json`: structured scan result and evidence source.
- `miasma-remote-scan.txt`: plain-text progress and findings.
- `miasma-remote-scan-console.txt`: captured scanner console output.
- `miasma-remote-audit.html`: standalone dark-mode HTML report.

Useful variants:

```powershell
# Fast smoke test against one repo
.\scripts\Invoke-MiasmaRemoteAudit.ps1 `
  -Owner relias-engineering `
  -ScanMode BranchTip `
  -RepositoryName authorization

# Regenerate HTML from an existing JSON artifact without rescanning GitHub
.\scripts\Invoke-MiasmaRemoteAudit.ps1 `
  -UseExistingJsonPath .\output\remote\relias-engineering\<run>\miasma-remote-scan.json
```

The full org scan can take hours and thousands of API calls. Re-running a past
date window is not guaranteed to reproduce old results if branches were deleted
or rewritten after the earlier scan.

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
- Relias internal PDF: `Git Commit Signing for Relias Engineering 1.pdf`


### Remote Org Date-Window Commit Scan Pattern

When the user asks for org-wide exposure across repositories and branches, prefer a GitHub API-only scan. Do not
clone, mirror, fetch, or check out repositories unless the user explicitly approves that tradeoff.

Recommended scan shape:

1. List repositories with `gh repo list <org> --json name`.
2. For each repo, list branches with `gh api repos/<org>/<repo>/branches`.
3. For each branch, list commits in the requested window with `gh api repos/<org>/<repo>/commits?sha=<branch>&since=<iso>&until=<iso>`.
4. Deduplicate commit SHAs per repo.
5. For each unique commit, inspect the commit tree with `gh api repos/<org>/<repo>/git/trees/<treeSha>?recursive=1`.
6. Count a commit as critical when the tree contains `.github/setup.js` plus agent/editor persistence paths.

For incident triage, distinguish these cases:

- `introduced`: the commit adds or modifies `.github/setup.js` or an auto-run config compared with its parent.
- `inherited`: the commit tree contains indicators, but the commit did not change those files.
- `operational branch affected`: indicators appear on long-lived branches such as `staging`, `production`, or default branches.

Do not report a branch as merely "affected" when the stronger statement is available. Prefer "introduced",
"modified", or "inherited".

### Audit Correlation

For GitHub org audit log checks, include Git transport events:

```powershell
gh api "/orgs/<org>/audit-log?include=git&phrase=<encoded phrase>&per_page=100"
```

Important details:

- Git audit events use `@timestamp` in Unix milliseconds; convert it locally for accurate time correlation.
- `created_at` can be null on `git.push`, `git.clone`, and `git.fetch` events.
- Org audit `git.push` records may not include branch/ref/SHA in the API payload. Treat actor/token correlation
  as strong supporting evidence, not definitive ref attribution, unless another log source includes the ref update.
- Commit author and committer fields are user-controlled metadata. They are not authoritative for source attribution.
- If the commit metadata says `github-actions` but no matching workflow run exists, treat it as ambiguous until audit
  or GitHub Support maps the ref update to a token/app/user.
- If suspicious commits align with `git.push` events from a user's public key or OAuth token at the same time, treat
  local developer Git environment compromise as the leading hypothesis.

### Relias GitHub Signed Commit Requirements

Relias-Engineering requires all commits to company repositories to be signed. Engineers must use SSH-based commit
signing with a dedicated Ed25519 signing key that is unique per device and protected with a passphrase. Do not reuse
SSH authentication keys for commit signing, do not share signing keys, and never upload private keys.

This is a separate concern from SSH authentication profiles. It is safe to keep one SSH host alias for personal GitHub
repositories and another for Relias work repositories, but the signing key must not be either authentication key. Signing
configuration must also stay scoped to work repositories: do not set `commit.gpgsign=true`, `user.signingkey`, or
`gpg.format=ssh` globally when the same workstation is used for personal repositories that should remain unsigned.

Recommended two-profile setup:

1. Keep personal repositories under a personal path such as `D:\github\HemSoft` or `D:\github\hemsoft`, using the
   personal SSH host alias and no signing include.
2. Keep Relias repositories under `D:\github\Relias`, using the work SSH host alias and a work-only Git include.
3. Create a dedicated signing key such as `~/.ssh/id_ed25519_relias_git_signing` with an interactive passphrase prompt:

```powershell
ssh-keygen -t ed25519 `
  -f "$env:USERPROFILE\.ssh\id_ed25519_relias_git_signing" `
  -C "fhemmer@relias.com git signing $(hostname)"
```

Add only the public key to GitHub as an SSH **Signing Key**. Do not add the private key anywhere, and do not add the
signing key as an SSH authentication key.

Preferred automation from the Miasma skill directory:

```powershell
.\scripts\Setup-ReliasSignedCommits.ps1 -PreflightOnly
.\scripts\Setup-ReliasSignedCommits.ps1
```

The setup script creates the dedicated key through `ssh-keygen`'s interactive passphrase prompt, uploads the public key
with `gh ssh-key add --type signing`, creates `~/.ssh/allowed-signers`, writes `~/.gitconfig-relias`, and adds only the
`D:\github\Relias` path-scoped include to the global Git config. Use `-SkipGitHubUpload` if the public key was already
added manually in GitHub. Use `-ConfigureOnly` after manually creating the key. If GitHub CLI reports a missing
`admin:ssh_signing_key` scope, refresh auth and rerun setup:

```powershell
gh auth refresh -h github.com -s admin:ssh_signing_key
.\scripts\Setup-ReliasSignedCommits.ps1
```

For a single repository, configure signing locally:

```powershell
git config --local gpg.format ssh
git config --local user.signingkey "$env:USERPROFILE\.ssh\id_ed25519_relias_git_signing.pub"
git config --local commit.gpgsign true
git config --local gpg.ssh.allowedSignersFile "$env:USERPROFILE\.ssh\allowed-signers"
```

For all Relias repositories under `D:\github\Relias`, prefer a path-scoped include instead of global signing:

```powershell
git config --global includeIf.gitdir:D:/github/Relias/.path ~/.gitconfig-relias
git config --file "$env:USERPROFILE\.gitconfig-relias" user.email fhemmer@relias.com
git config --file "$env:USERPROFILE\.gitconfig-relias" gpg.format ssh
git config --file "$env:USERPROFILE\.gitconfig-relias" user.signingkey "$env:USERPROFILE\.ssh\id_ed25519_relias_git_signing.pub"
git config --file "$env:USERPROFILE\.gitconfig-relias" commit.gpgsign true
git config --file "$env:USERPROFILE\.gitconfig-relias" gpg.ssh.allowedSignersFile "$env:USERPROFILE\.ssh\allowed-signers"
```

Create `~/.ssh/allowed-signers` with the user's Relias email and signing public key so local
`git log --show-signature` and `git show --show-signature` can verify the user's own commits:

```powershell
$publicKey = Get-Content "$env:USERPROFILE\.ssh\id_ed25519_relias_git_signing.pub" -Raw
"fhemmer@relias.com $publicKey".Trim() | Set-Content "$env:USERPROFILE\.ssh\allowed-signers" -NoNewline
```

Validate the scope before making work commits:

```powershell
git -C D:\github\Relias\org-metrics config --show-origin --get commit.gpgsign
git -C D:\github\Relias\org-metrics config --show-origin --get user.signingkey
git -C D:\github\hemsoft\codexbar config --show-origin --get commit.gpgsign
```

The Relias repository should return `true` and the dedicated signing public key. The personal repository should return
nothing unless it intentionally has its own unrelated signing policy. Seeing `No principal matched` for another
engineer's signed commit is expected when their public key is not present locally; GitHub can still validate the commit
signature.

For Miasma incident triage, treat GitHub "Verified" or locally valid signed commits as integrity evidence for the
commit object, not proof that the named human intentionally authored the change. If suspicious Miasma commits are
signed with a user's signing key, preserve the signing evidence and treat the user's signing key, GitHub account, and
endpoint as potentially compromised until investigated. Immediately remove suspected compromised signing keys from
GitHub, notify InfoSec and Engineering leadership, and rotate or recreate signing keys only after containment.

### Relias Investigation Learnings

- `platform-reporting-service` had Miasma-like branch-tip injections on old PR branches where commit metadata said
  `github-actions`, but no matching workflow run was found. The `.github/setup.js` blobs were about 4.63 MB.
- `nurse-mobile-app` showed a stronger local-compromise pattern: several feature branches had paired commits where
  one commit added the persistence files and the next modified `.github/setup.js`; org audit pushes lined up with
  named users' public keys and normal Git clients.
- `supernurse-backend` had indicators on `staging` and `production`, which should be treated as operationally urgent
  even if app runtime execution is not yet proven.
- Plain `[skip ci]` remains noisy, but `[skip ci]` plus `.github/setup.js` and agent/editor auto-run configs is
  critical.

### Response Guidance

For confirmed or high-confidence findings:

1. Preserve evidence before cleanup: branch refs, commit SHAs, parent SHAs, blob SHAs, audit records, actor names,
   token/key hashes, timestamps, and workflow/run context.
2. Warn developers not to checkout, open, or run affected branches in Cursor, Claude, Gemini, VS Code, or agent-enabled
   IDEs.
3. Prioritize long-lived branches (`staging`, `production`, default branches) before stale feature branches.
4. For user-key-aligned pushes, revoke or rotate GitHub SSH keys and tokens, then investigate endpoints before
   restoring access.
5. Clean branches by deleting stale branches, resetting to last known-good commits, or applying auditable removal
   commits on protected or operational branches.
6. After containment, add rulesets or monitoring for high-signal paths such as `.github/setup.js`, AI-agent auto-run
   configs, and unexpected `binding.gyp`.
