---
name: agent-workflows
description: "V1.0 - Expert in GitHub Agentic Workflows (gh-aw). Complete reference for frontmatter, safe-outputs, file protection, GitHub App config, token/permission model, CLI commands, engines, triggers, and troubleshooting. Covers Relias-Engineering environment specifics including SFL app, Integrations-relias service account, and SSH alias workarounds."
---

# GitHub Agentic Workflows (gh-aw) — Expert Skill

Comprehensive reference for building, debugging, and operating GitHub Agentic Workflows.
Always consult the live docs at <https://github.github.com/gh-aw/> — this system changes daily.

## Quick Reference

| Resource | URL |
|----------|-----|
| Docs | <https://github.github.com/gh-aw/> |
| Frontmatter | <https://github.github.com/gh-aw/reference/frontmatter/> |
| Safe Outputs | <https://github.github.com/gh-aw/reference/safe-outputs/> |
| PR Safe Outputs | <https://github.github.com/gh-aw/reference/safe-outputs-pull-requests/> |
| Releases | <https://github.github.com/gh-aw/releases/> |
| Source | <https://github.com/github/gh-aw> (private) |

## Default Behavior

When activated, help the user with their gh-aw workflow task. Always fetch the latest release notes before giving version-specific advice:

```bash
gh aw releases --latest
```

---

## 1. ARCHITECTURE

### How It Works

1. **Author**: Write a `.md` file with YAML frontmatter + markdown body in `.github/workflows/`
2. **Compile**: `gh aw compile` produces a `.lock.yml` (auto-generated, ~80KB, DO NOT EDIT)
3. **Run**: The lock.yml runs as a standard GitHub Actions workflow

### Job Pipeline

```
activation → agent → detection → safe_outputs → conclusion
```

- **activation**: Validates trigger, checks roles/skip conditions, posts reaction/status comment
- **agent**: AI engine runs read-only with no write permissions and no secrets
- **detection**: Threat detection scan of agent output
- **safe_outputs**: Permission-controlled job that applies agent's requested changes
- **conclusion**: Housekeeping — posts success/failure comments, creates failure issues

### Security Layers

1. **Read-only tokens** — agent never gets write permissions
2. **Zero secrets in agent** — secrets only available in activation and safe_outputs jobs
3. **Network firewall (AWF)** — Squid-based proxy controlling all egress
4. **Safe outputs** — structured output processing with limits and file protection
5. **Threat detection** — scans agent output for injection attempts

---

## 2. FRONTMATTER — Complete Field Reference

```yaml
---
# === IDENTITY ===
description: "Human-readable description"
source: "owner/repo/path@ref"             # auto-set by gh aw add
private: true                             # prevent gh aw add by others
labels: ["automation", "ci"]              # organize/filter via gh aw status
metadata:                                 # key-value pairs
  author: Jane Doe
  version: 1.0.0

# === TRIGGERS ===
on:
  schedule: "daily"                       # fuzzy: daily, weekly, hourly, "every 10 minutes", "daily around 14:00"
  workflow_dispatch:
  issues:
    types: [opened, labeled]
  pull_request:
    types: [opened, synchronize]
  slash_command:
    name: investigate
  label_command: deploy
  roles: [admin, maintainer, write]       # who can trigger (default)
  bots: ["dependabot[bot]"]
  reaction: "eyes"                        # +1 -1 laugh confused heart hooray rocket eyes
  status-comment: true
  stop-after: "2025-12-31"
  manual-approval: true
  forks: ["trusted-org/*"]
  skip-if-match: "is:issue is:open label:x"
  skip-if-no-match: "is:issue is:open"
  github-app:
    client-id: ${{ vars.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}

# === ENGINE ===
engine:
  id: copilot                             # copilot | claude | codex | gemini | crush | opencode
  model: claude-opus-4.6                  # override model
  version: "0.0.422"                      # pin version
  agent: technical-doc-writer             # .github/agents/*.agent.md (Copilot only)
  bare: true                              # disable AGENTS.md/CLAUDE.md loading
  harness: custom_harness.cjs             # Copilot only
  concurrency:
    group: "gh-aw-copilot-${{ github.workflow }}"
  env:
    # BYOK (Bring Your Own Key):
    COPILOT_PROVIDER_BASE_URL: ${{ secrets.PROVIDER_BASE_URL }}
    COPILOT_MODEL: claude-sonnet-4
    COPILOT_PROVIDER_API_KEY: ${{ secrets.PROVIDER_API_KEY }}
    COPILOT_PROVIDER_TYPE: anthropic       # openai | azure | anthropic

max-turns: 20                              # Claude only
max-continuations: 3                       # Copilot only

# === PERMISSIONS ===
permissions:
  contents: read
  issues: read
  pull-requests: read
# Shorthand: read-all | {}

# === TOOLS ===
tools:
  edit:                                    # file editing
  bash: true                               # default safe commands
  bash: [":*"]                             # unrestricted (⚠️ triggers bypassPermissions in Claude)
  github:
    toolsets: [repos, issues, pull_requests, users]
    # All: context, repos, issues, pull_requests, users, actions, code_security,
    #   discussions, labels, notifications, orgs, projects, gists, search,
    #   dependabot, experiments, secret_protection, security_advisories, stargazers
    # Shorthand: default, all
    lockdown: false                        # disable tool restrictions
    mode: local                            # local | remote | gh-proxy
    github-app:
      client-id: ${{ vars.APP_ID }}
      private-key: ${{ secrets.APP_PRIVATE_KEY }}
    allowed-repos: "all"                   # "all" | "public" | ["owner/repo"]
  web-fetch:
  web-search:
  playwright:
    version: "1.56.1"
  cache-memory:                            # persistent memory across runs
  agentic-workflows:                       # introspection (requires actions: read)

# === NETWORK ===
network: defaults                          # or object form:
network:
  allowed:
    - defaults                             # basic infra
    - github                               # github.com ecosystem
    - python | node | go | rust | ruby | java | dotnet | dart | deno
    - containers | linux-distros | dev-tools | terraform | playwright
    - local                                # localhost
    - "api.example.com"                    # custom domain
    - "*.cdn.example.com"                  # wildcard
  blocked:
    - "cdn.example.com"

# === MCP SERVERS ===
mcp-servers:
  slack:
    command: "npx"
    args: ["-y", "@slack/mcp-server"]
    env:
      SLACK_BOT_TOKEN: "${{ secrets.SLACK_BOT_TOKEN }}"
    allowed: ["send_message", "get_history"]

# === SANDBOX ===
sandbox:
  agent: awf                               # awf (default) | false

# === STRICT MODE ===
strict: true                               # default; false for dev/testing

# === RUN CONFIG ===
runs-on: ubuntu-latest                     # ubuntu-24.04, ubuntu-22.04, ubuntu-24.04-arm
timeout-minutes: 30                        # default: 20; max: 360
concurrency:
  group: custom-${{ github.ref }}
  cancel-in-progress: true

# === CHECKOUT ===
checkout:
  - fetch-depth: 0
    fetch: ["refs/pulls/open/*"]
  - repository: owner/other-repo
    path: ./libs/other
    github-token: ${{ secrets.CROSS_REPO_PAT }}

# === STEPS ===
steps:
  - name: Install dependencies
    run: npm ci
pre-agent-steps:
  - name: Prepare context
    run: ./scripts/prepare.sh
post-steps:
  - name: Upload results
    if: always()
    uses: actions/upload-artifact@v4
---
```

---

## 3. SAFE OUTPUTS — Complete Reference

### Global Fields

```yaml
safe-outputs:
  github-app:                              # GitHub App for minting write tokens
    client-id: ${{ vars.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
    owner: "my-org"
    repositories: ["repo1", "repo2"]       # omit = current repo; "*" = org-wide
  concurrency-group: "safe-outputs-${{ github.repository }}"
  github-token: ${{ secrets.CUSTOM_TOKEN }}  # global token override
```

### Issue Types

```yaml
  create-issue:
    title-prefix: "[ai] "
    labels: [automation]
    assignees: [user1, copilot]
    max: 5                                 # default: 1
    expires: "7d"                          # auto-close; also 2h, 2w, 1m, 1y, false
    group: true                            # sub-issues under parent
    close-older-issues: true               # close previous workflow issues
    group-by-day: true                     # merge same-day runs into one issue
    target-repo: "owner/repo"

  update-issue:
    target: "*"                            # "triggering" | "*" | number
    max: 5

  close-issue:
    target: "*"
    max: 1
```

### Pull Request Types

```yaml
  create-pull-request:
    title-prefix: "[ai] "
    labels: [automation]
    reviewers: [user1, copilot]
    team-reviewers: [platform-reviewers]
    assignees: [user1]
    draft: true                            # POLICY — agent cannot override
    max: 3                                 # default: 1
    expires: "14d"
    if-no-changes: "warn"                  # "warn" | "error" | "ignore"
    base-branch: "vnext"
    allowed-base-branches: [main, release/*]
    fallback-as-issue: true                # default: true
    auto-close-issue: true                 # appends "Fixes #N" (default: true)
    preserve-branch-name: false            # default: false
    recreate-ref: false                    # force-push (requires preserve-branch-name)
    allow-workflows: true                  # ⚠️ requires github-app
    allowed-files: ["src/**", "docs/**"]   # exclusive allowlist
    excluded-files: ["**/*.lock"]          # stripped from patch entirely
    protected-files: allowed               # blocked | fallback-to-issue | allowed
    github-token: ${{ secrets.CUSTOM }}
    github-token-for-extra-empty-commit: ${{ secrets.CI_TOKEN }}
    target-repo: "owner/repo"

  push-to-pull-request-branch:
    target: "*"                            # "triggering" | "*" | number
    title-prefix: "[bot] "
    labels: [automated]
    max: 3
    fallback-as-pull-request: true
    ignore-missing-branch-failure: false
    check-branch-protection: true
    allow-workflows: true                  # ⚠️ requires github-app
    allowed-files: [".changeset/**"]
    protected-files: allowed
    target-repo: "owner/repo"              # REQUIRES checkout with path:

  update-pull-request:
    title: true
    body: true
    update-branch: false
    target: "*"

  close-pull-request:
    target: "triggering"
    required-labels: [automated, stale]
    max: 10
```

### Review Types

```yaml
  create-pull-request-review-comment:
    max: 10
    side: "RIGHT"                          # "LEFT" | "RIGHT"
    target: "*"
    footer: "if-body"                      # "always" | "none" | "if-body"

  submit-pull-request-review:
    max: 1
    allowed-events: [COMMENT]              # APPROVE | COMMENT | REQUEST_CHANGES
    supersede-older-reviews: true

  reply-to-pull-request-review-comment:
    max: 10

  resolve-pull-request-review-thread:
    max: 10

  add-reviewer:
    reviewers: [user1, copilot]
    team-reviewers: [platform-reviewers]
    max: 3
```

### Other Types

```yaml
  add-comment:
    max: 1
    target: "*"

  add-labels:
    max: 3

  remove-labels:
    max: 3

  dispatch-workflow:
    max: 3

  upload-artifact:
    max: 1

  noop:
    max: 1
```

---

## 4. FILE PROTECTION — Deep Dive

### How It Works (from source code)

Two independent checks run in sequence. **Both must pass.**

```
Step 1: allowed-files check (if patterns exist, file must match)
    ↓ pass
Step 2: protected-files check (protected_files_policy evaluation)
    ↓ pass
ALLOW
```

**Source**: `actions/setup/js/manifest_file_helpers.cjs`

```javascript
function checkFileProtection(patchContent, config) {
  // STEP 1: Allowlist — runs FIRST, even when policy is "allowed"
  if (allowedFilePatterns.length > 0) {
    const { disallowedFiles } = checkAllowedFiles(patchContent, allowedFilePatterns);
    if (disallowedFiles.length > 0) {
      return { action: "deny", source: "allowlist", files: disallowedFiles };
    }
  }

  // STEP 2: Protected-files policy
  if (config.protected_files_policy === "allowed") {
    return { action: "allow" };   // ← BYPASSES all remaining checks
  }

  // Three protection detectors run in parallel, results union-merged:
  // 1. checkForManifestFiles — basename matching
  // 2. checkForProtectedPaths — path prefix matching
  // 3. checkForTopLevelDotFolders — any .xxx/ directory
  // If any file found → apply policy (deny or fallback)
}
```

### CRITICAL: `allowed-files` and `protected-files` are ORTHOGONAL

- `allowed-files` is Step 1 — an exclusive allowlist
- `protected-files` is Step 2 — security policy
- Having `protected-files: allowed` does NOT bypass `allowed-files`
- Having `allowed-files: ["src/**"]` means files outside `src/` are ALWAYS denied, regardless of `protected-files`

### `protected-files` Policy Values

| Value | Behavior |
|-------|----------|
| `blocked` (default) | Hard failure — safe output aborted |
| `fallback-to-issue` | Creates review issue with manual instructions |
| `allowed` | Bypasses ALL protection (manifest, path prefix, dot-folder) |

### Object Form

```yaml
protected-files:
  policy: fallback-to-issue
  exclude:
    - AGENTS.md           # basename — removes from protected set
    - CHANGELOG.md
    - .agents/            # path prefix — also opts out of dot-folder rule
    - .cursor/
```

### What Is Always Protected (Unless Overridden)

| Category | Files |
|----------|-------|
| Node.js | `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| Go | `go.mod`, `go.sum` |
| Python | `requirements.txt`, `Pipfile`, `pyproject.toml`, `setup.py` |
| .NET | `global.json`, `NuGet.Config`, `Directory.Packages.props` |
| Java | `pom.xml`, `build.gradle`, `build.gradle.kts` |
| Ruby | `Gemfile`, `Gemfile.lock` |
| Copilot engine | `AGENTS.md` |
| Claude engine | `CLAUDE.md`, `.claude/` |
| Repo security | `.github/`, `.agents/`, `.githooks/`, `.husky/` |
| Dot folders | Any top-level `.xxx/` directory |
| Common docs | `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md` |
| Access control | `CODEOWNERS`, `DESIGN.md` |

### `protect_top_level_dot_folders` (hardcoded `true`)

Flags any changed file whose first path component starts with `.` and is ≥2 chars:
- `.github/workflows/ci.yml` → FLAGGED (`.github` starts with `.`)
- `.env` → NOT flagged (root-level file, no `/`)
- Exclusions require trailing slash: `[".agents/"]`

### `excluded_files` — Patch Pre-Filter

Applied at `git format-patch :(exclude)` time. Matching files are stripped from the patch entirely — they never reach `checkFileProtection`. This is NOT a protection override.

### Glob Matching (Hand-Rolled, No Library)

- `*` → `[^/]*` — matches anything except `/` (one segment)
- `**` → `.*` — matches everything including `/` (multiple segments)
- `.` → `\\.` — literal dot
- Anchored: `^...$` (full path must match)
- Case-sensitive by default

---

## 5. GITHUB APP CONFIGURATION

### When You Need a GitHub App

- `allow-workflows: true` (push to `.github/workflows/`)
- Cross-repo write operations
- `assign-to-agent` (Copilot coding agent)
- GitHub Projects v2 operations
- Triggering CI on PRs (alternative to `github-token-for-extra-empty-commit`)

### Frontmatter Config

```yaml
safe-outputs:
  github-app:
    client-id: ${{ vars.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
    owner: "Relias-Engineering"                    # optional; default: current org
    repositories: ["ai-workflows"]                 # optional; omit = current repo; "*" = org-wide
  create-pull-request:
    allow-workflows: true
    protected-files: allowed
```

### Setup Commands

```bash
# Set the app client-id as a repo/org variable
gh variable set APP_ID --body "YOUR_APP_CLIENT_ID"

# Set the private key as a secret (use gh aw secrets for encrypted storage)
gh aw secrets set APP_PRIVATE_KEY --value "$(cat path/to/private-key.pem)"
```

### Token Resolution Chain (from source)

```
1. config["github-token"]          ← per-handler PAT
2. global github object            ← step-level token, which is:
   a. GitHub App token             ← if github-app configured (minted from app)
   b. safe-outputs.github-token    ← global override
   c. "magic secrets"              ← fallback chain:
      GH_AW_GITHUB_MCP_SERVER_TOKEN → GH_AW_GITHUB_TOKEN → GITHUB_TOKEN
```

### Push Mechanism

**Primary**: GraphQL `createCommitOnBranch` mutation — commits are cryptographically signed by GitHub.

**Fallback**: `git push origin <branch>` — credentials via `GIT_CONFIG_*` env vars (never written to `.git/config`).

**CI Trigger**: After main push, an empty commit is pushed via `GH_AW_CI_TRIGGER_TOKEN` to trigger downstream CI. Skipped for cross-repo targets.

---

## 6. TOKEN & SECRET MODEL

### Secret Precedence (Compiled Lock.yml)

```yaml
GH_TOKEN: ${{ secrets.GH_AW_GITHUB_MCP_SERVER_TOKEN || secrets.GH_AW_GITHUB_TOKEN || github.token }}
```

### Engine Secrets

| Engine | Required Secret | Notes |
|--------|----------------|-------|
| Copilot | `COPILOT_GITHUB_TOKEN` | Fine-grained PAT; owner must be personal account |
| Claude | `ANTHROPIC_API_KEY` | `CLAUDE_CODE_OAUTH_TOKEN` NOT supported |
| Codex | `OPENAI_API_KEY` or `CODEX_API_KEY` | `CODEX_API_KEY` tried first |
| Gemini | `GEMINI_API_KEY` | From Google AI Studio |

### Magic Secrets (No Frontmatter Ref Needed)

| Secret | Purpose |
|--------|---------|
| `GH_AW_GITHUB_MCP_SERVER_TOKEN` | Cross-repo GitHub MCP server auth |
| `GH_AW_GITHUB_TOKEN` | Override GITHUB_TOKEN for safe-outputs |
| `GH_AW_CI_TRIGGER_TOKEN` | Token for empty commit CI trigger |
| `COPILOT_GITHUB_TOKEN` | Copilot engine authentication |

### GitHub App-Only Permissions

These permissions **cannot** be granted via `GITHUB_TOKEN` — only via GitHub App tokens:

`administration`, `environments`, `git-signing`, **`workflows`**, `repository-hooks`, `single-file`, `codespaces`, `repository-custom-properties`, `organization-projects`, `members`

---

## 7. RELIAS-ENGINEERING ENVIRONMENT

### Accounts & Identity

| Entity | Role | Details |
|--------|------|---------|
| `Integrations-relias` | Service account | PAT stored as `GH_AW_GITHUB_TOKEN` org secret; last active via `copilot-cli` |
| `fhemmerrelias` | Human user | Primary `gh auth` identity; token scopes: admin:org, admin:public_key, copilot, delete_repo, gist, repo |
| `HemSoft` | Personal account | Inactive gh auth; no longer owns set-it-free-loop (migrated to Relias-Engineering) |

### Set-it-Free-Loop (SFL) GitHub App

The SFL app is installed on **all** Relias-Engineering repos:

| Field | Value |
|-------|-------|
| App Slug | `set-it-free-loop` |
| App ID | `3650906` |
| Installation ID | `130729346` |
| Target | Organization (Relias-Engineering) |
| Repository Selection | **all** |

**Current Permissions:**

| Permission | Level |
|------------|-------|
| administration | read |
| checks | read |
| contents | write |
| issues | write |
| metadata | read |
| pull_requests | write |
| statuses | read |
| workflows | write |

**Credentials (org-level, all repos):**

| Kind | Name | Value / Purpose |
|------|------|-----------------|
| Variable | `SFL_APP_CLIENT_ID` | `Iv23liwZid0CBWCRuWdd` |
| Secret | `SFL_APP_PRIVATE_KEY` | PEM key (expires 2026-05-12) |

**Usage in workflow frontmatter:**

```yaml
safe-outputs:
  github-app:
    client-id: ${{ vars.SFL_APP_CLIENT_ID }}
    private-key: ${{ secrets.SFL_APP_PRIVATE_KEY }}
  create-pull-request:
    allow-workflows: true
    protected-files: allowed
```

### Org/Repo Secrets

| Scope | Kind | Name | Purpose |
|-------|------|------|---------|
| Org | Secret | `COPILOT_GITHUB_TOKEN` | Copilot engine auth (Integrations-relias PAT) |
| Org | Secret | `ORG_SCAN_TOKEN` | Organization scanning |
| Org | Secret | `SONAR_TOKEN` | SonarQube |
| Org | Variable | `SFL_APP_CLIENT_ID` | SFL GitHub App client ID |
| Org | Secret | `SFL_APP_PRIVATE_KEY` | SFL GitHub App private key (PEM) |
| Repo (ai-workflows) | Secret | `SONAR_TOKEN` | SonarQube (repo-level override) |

### SSH Config & `gh aw audit` Bug

The remote URL uses SSH alias `github-work1` instead of `github.com`:
```
git@github-work1:relias-engineering/ai-workflows.git
```

`gh aw audit` parses this literally and tries to connect to `github-work1` as API host → fails.

**Workaround**: Use `gh run view <run-id> --repo relias-engineering/ai-workflows` instead.

### Local Environment

| Tool | Version |
|------|---------|
| gh aw | v0.71.5 (update with `gh aw update`) |
| gh CLI | Check with `gh --version` |

---

## 8. CLI COMMANDS

### Setup & Development

| Command | Purpose |
|---------|---------|
| `gh aw new [name]` | Create new workflow from template |
| `gh aw new --interactive` | Interactive workflow creation wizard |
| `gh aw add [ref]` | Install workflow from another repo |
| `gh aw add-wizard` | Interactive workflow installer |
| `gh aw compile [workflow...]` | Compile .md → .lock.yml |
| `gh aw compile --watch` | Watch mode |
| `gh aw compile --dependabot` | Generate Dependabot manifests |
| `gh aw fix [workflow...]` | Auto-fix codemod-style issues |
| `gh aw upgrade` | Upgrade repo with latest agent files |
| `gh aw lint` | Fast lock-file validation (no recompile) |
| `gh aw secrets set NAME` | Set encrypted secret |

### Execution

| Command | Purpose |
|---------|---------|
| `gh aw run [workflow]` | Trigger workflow |
| `gh aw status` | List workflow runs |
| `gh aw logs [run-id]` | View run logs |
| `gh aw audit [run-id]` | Detailed run analysis |
| `gh aw health` | Repository health check |
| `gh aw list` | List workflows |

### Analysis

| Command | Purpose |
|---------|---------|
| `gh aw experiments` | A/B experiment management |
| `gh aw experiments analyze` | Analyze experiment results |
| `gh aw releases` | View release notes |
| `gh aw releases --latest` | Latest release only |

### Utilities

| Command | Purpose |
|---------|---------|
| `gh aw update` | Update gh-aw extension |
| `gh aw update --cool-down` | Update with cool-down period |
| `gh aw docs` | Open documentation |
| `gh aw version` | Show version |

---

## 9. ENGINE REFERENCE

### Available Engines

| Engine | Secret | Special Features |
|--------|--------|-----------------|
| `copilot` (default) | `COPILOT_GITHUB_TOKEN` | `agent`, `harness`, `max-continuations`, inline sub-agents |
| `claude` | `ANTHROPIC_API_KEY` | `max-turns`, bypassPermissions mode |
| `codex` | `OPENAI_API_KEY` / `CODEX_API_KEY` | Built-in web-search |
| `gemini` | `GEMINI_API_KEY` | — |
| `crush` | — | — |
| `opencode` | — | — |

### Claude `bypassPermissions` Gotcha

When bash is set to unrestricted (`bash: [":*"]` or `bash: "*"` or `bash: null`), Claude enters `bypassPermissions` mode where `--allowed-tools` is **silently ignored**. Only the AWF gateway `allowed:` list enforces tool restrictions.

### Schedule Fuzzy Formats

| Format | Example |
|--------|---------|
| `daily` | Deterministic cron per workflow |
| `daily around 14:00` | ±1 hour scatter |
| `daily between 9am and 5pm utc-5` | Scatter in range with timezone |
| `weekly on monday` | Weekly |
| `hourly` | Every hour |
| `every 10 minutes` | Min 5 min interval |

---

## 10. TROUBLESHOOTING PATTERNS

### "patch modifies protected files"

**Diagnosis**: Step 2 (protected-files check) is blocking. The patch touches files in `.github/`, dot-folders, or manifest files.

**Fix**: Set `protected-files: allowed` on the handler. If you want selective exemption, use object form with `exclude`.

### "patch modifies files outside the allowed-files list"

**Diagnosis**: Step 1 (allowlist check) is blocking. You have `allowed-files` configured and the patch touches files not matching any pattern.

**Fix**: Either add the file pattern to `allowed-files` or remove `allowed-files` entirely (empty = no allowlist check).

### Push fails with "Resource not accessible by integration"

**Diagnosis**: The token lacks required permission. Most common: trying to push to `.github/workflows/` without `workflows:write`.

**Fix**: Configure a GitHub App with `allow-workflows: true`. `GITHUB_TOKEN` **cannot** get `workflows:write` — this is architecturally impossible.

### Safe-outputs creates issue instead of PR

**Diagnosis**: The git push succeeded but something triggered the fallback-to-issue path. Check the run logs for "Code push ... fell back to review issue".

**Possible causes**:
1. Protected files detected → set `protected-files: allowed`
2. Push failed (permission) → configure GitHub App
3. Non-fast-forward push → `fallback-as-pull-request: true` (default) handles this
4. Org setting "Allow GitHub Actions to create and approve pull requests" is disabled

### `gh aw audit` fails with "failed to fetch run metadata"

**Diagnosis**: Either the run is still in progress, or your git remote uses an SSH alias.

**Fix**:
- Wait for run to complete, then retry
- If SSH alias issue: use `gh run view <id> --repo owner/repo` instead
- File a bug with `gh aw` team

### `gh aw compile` fails

**Diagnosis**: Check for:
- Duplicate frontmatter blocks
- Invalid YAML in frontmatter
- `allow-workflows: true` without `safe-outputs.github-app`
- `id-token: read` (invalid — only `write` accepted)
- Strict mode violations (wildcard `*` in network, missing network config)

### CI not triggered after PR creation

**Diagnosis**: `GITHUB_TOKEN`-pushed commits don't trigger workflows by default.

**Fix**: Set `github-token-for-extra-empty-commit: ${{ secrets.CI_TRIGGER_TOKEN }}` with a PAT or App token.

---

## 11. CONCURRENCY CONTROL

| Trigger | Auto-Generated Group |
|---------|---------------------|
| Issues | `gh-aw-{workflow}-{issue.number}` |
| Pull Requests | `gh-aw-{workflow}-{pr.number}` |
| Push | `gh-aw-{workflow}-{github.ref}` |
| Schedule | `gh-aw-{workflow}` |

Override with:
```yaml
concurrency:
  group: custom-${{ github.ref }}
  cancel-in-progress: true
  job-discriminator: ${{ inputs.finding_id }}   # for fan-out

safe-outputs:
  concurrency-group: "safe-outputs-${{ github.repository }}"
```

---

## 12. CROSS-REPOSITORY OPERATIONS

```yaml
# Checkout target repo
checkout:
  - repository: org/target-repo
    path: ./target-repo                    # REQUIRED for push cross-repo
    github-token: ${{ secrets.CROSS_REPO_PAT }}
    fetch: ["refs/pulls/open/*"]

# Read cross-repo (magic secret — no frontmatter ref needed)
# Just set GH_AW_GITHUB_MCP_SERVER_TOKEN as org/repo secret

# Write cross-repo
safe-outputs:
  github-token: ${{ secrets.CROSS_REPO_PAT }}
  create-issue:
    target-repo: "org/tracking-repo"
  push-to-pull-request-branch:
    target-repo: "org/target-repo"         # REQUIRES checkout with path:
```

---

## 13. WORKFLOW-ID MARKER

All items created by workflows include a hidden marker:
```html
<!-- gh-aw-workflow-id: WORKFLOW_NAME -->
```

Search for workflow-created items:
```
repo:owner/repo is:issue is:open "gh-aw-workflow-id: simplisticate-pr" in:body
```

---

## 14. IMPORTANT GOTCHAS

1. **`id-token: read` is invalid** — only `write` or none; compile-time error
2. **`draft:` is a policy** — agent cannot override the frontmatter value
3. **CI not triggered by default** on PR create/push
4. **`push-to-pull-request-branch` cross-repo** requires `checkout:` with `path:`
5. **`allow-workflows: true`** requires `safe-outputs.github-app` — compile-time enforced
6. **Strict mode ON by default** — set `strict: false` for dev
7. **`CLAUDE_CODE_OAUTH_TOKEN` NOT supported** — only `ANTHROPIC_API_KEY`
8. **macOS and Windows runners NOT supported** — AWF requires Linux
9. **`bypassPermissions` in Claude** silently ignores `--allowed-tools`
10. **`COPILOT_GITHUB_TOKEN` owner** must be personal account, not organization
11. **`allowed-files` runs BEFORE `protected-files`** — allowlist can block even with `protected-files: allowed`
12. **`excluded_files` is a patch pre-filter** — NOT a protection override
13. **Lock.yml is auto-generated** — never edit; always use `gh aw compile`
14. **`protect_top_level_dot_folders: true`** is hardcoded — only `protected-files: allowed` bypasses it

---

## 15. RECENT RELEASES

### v0.72.1 (2026-05-07) — Latest

- `gh aw lint` — fast lock-file validation
- Import `engine.mcp.tool-timeout` / `session-timeout` from shared workflows
- **BUG FIX**: `&&` corrupted to `\u0026\u0026` in AWF config JSON
- **BUG FIX**: `update-project` co-presence downgraded App token
- **BUG FIX**: Conclusion comment reported ✅ when `safe_outputs` failed
- **BUG FIX**: Firewall binary 404 (shipped firewall v0.25.29)
- **BUG FIX**: `COPILOT_API_KEY` dummy key caused 10-100x over-billing

### v0.72.0 (2026-05-06)

- Inline sub-agents default-on (deprecated `features.inline-agents`)
- **BUG FIX**: `push_to_pull_request_branch` add/add conflict on reruns

### v0.71.6 (2026-05-06)

- **BUG FIX**: Safe-outputs App token incorrectly capped `issues:*` permissions
- **BUG FIX**: `dispatch-workflow` "No ref found" error
- **BUG FIX**: Compiler ignored push/update target-repo without create-pull-request

### v0.71.5 (2026-05-05)

- **BUG FIX**: Claude "Fast mode unavailable" crash
- **BUG FIX**: `engine.env` multi-line values broken YAML
- **BUG FIX**: `pull_request_review` activation signal missed
- `allow-bot-authored-trigger-comment: true`

---

## 16. LESSONS LEARNED (ai-workflows repo)

### The Five Failed Runs

| Run | Failure | Root Cause | Fix |
|-----|---------|-----------|-----|
| 1 | Agent error | Duplicate frontmatter blocks, wrong safe-outputs | Consolidated frontmatter, switched to PR-based outputs |
| 2 | Protected files (`.github/workflows/lint.yml`) | Missing `allowed-files` | Added `allowed-files` globs |
| 3 | Protected files (same) | Broader globs needed | Added `**` patterns |
| 4 | Protected files (`.markdownlint-cli2.jsonc`) | Root dotfiles blocked by dot-folder check | Added `".*"` to allowed-files |
| 5 | Fallback to issue #6 | `allowed-files` + `protected-files` are orthogonal checks; `protect_top_level_dot_folders: true` was the real blocker | Set `protected-files: allowed`, removed all `allowed-files` |

**Key Insight**: We were fixing Step 1 (allowlist) while Step 2 (protected-files, including the hardcoded `protect_top_level_dot_folders: true`) was the actual blocker. The two checks are **independent and orthogonal**.

### Remaining Blocker: `workflows:write`

Even with `protected-files: allowed`, pushing commits that modify `.github/workflows/` files requires `workflows:write` — a GitHub App-only permission. The safe-outputs job falls back to creating a review issue when the push fails.

**Solution path**: Configure the SFL GitHub App with `workflows` permission and use `allow-workflows: true` + `safe-outputs.github-app` in the workflow frontmatter. See section 7 for setup steps.

---

## Rules

- Always check `gh aw releases --latest` before giving version-specific advice
- Always consult the live docs — this system changes daily with new releases
- Never edit `.lock.yml` files — always use `gh aw compile`
- When debugging safe-outputs failures, check BOTH Step 1 (allowed-files) and Step 2 (protected-files) independently
- Remember `GITHUB_TOKEN` CANNOT get `workflows:write` — this requires a GitHub App
- Account for SSH alias in `gh aw audit` — use `gh run view` as workaround
- The SFL app (`set-it-free-loop`) is installed on all Relias-Engineering repos and is the intended actor for write operations
