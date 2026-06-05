---
name: sonar
description: "V1.0 - Commands: PRIssues, ProjectIssues, QualityGate. Fetch SonarCloud (SonarQube Cloud) issues, quality gate status, and measures for the Relias configurator project and other projects. Use when asked whether a pull request has Sonar issues, what they are, or about Sonar quality gate / coverage / duplication results. Knows where the SONAR_TOKEN lives and how to query the private SonarCloud API."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the sonar directory (path contains 'sonar'), verify that history logging occurred.

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
            Before stopping, if sonar was used (check if any files in sonar directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in sonar directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Sonar (SonarCloud / SonarQube Cloud)

Fetch issues, quality gate, and measures from SonarCloud for pull requests and projects.

## Key Fact: Quality Gate passed ≠ zero issues

A green "Quality Gate passed" status (and the green GitHub status check) only means
the gate's threshold conditions were met. A PR can still have **new issues** (often
INFO/code-smell severity) that don't breach the gate. When asked "does PR X have Sonar
issues?", **always query the issues API** — do not just report the GitHub status check.

## Authentication — where the token lives

The SonarCloud user token is stored in the **machine environment variable `SONAR_TOKEN`**.

```powershell
$tok = [Environment]::GetEnvironmentVariable('SONAR_TOKEN', 'Machine')
if (-not $tok) { $tok = $env:SONAR_TOKEN }  # fallback to process env
```

> If `SONAR_TOKEN` is empty, ask the user to set it (machine env var) or paste a token.
> Generate one at <https://sonarcloud.io/account/security> (a "User Token").
> Note: a newly-set machine env var is NOT visible in already-running shells; start a
> fresh process or read it explicitly with the `[Environment]::GetEnvironmentVariable(...,'Machine')` call above.

SonarCloud auth uses HTTP Basic with the token as username and an empty password:

```powershell
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($tok):"))
$headers = @{ Authorization = "Basic $b64" }
```

## Project coordinates (Relias configurator)

| Field             | Value                              |
|-------------------|------------------------------------|
| Project key       | `relias-engineering_configurator`  |
| Organization      | `relias-github`                    |
| Host              | `https://sonarcloud.io`            |

These come from `.github/workflows/build.yml` (`/k:` and `/o:` scanner args). For other
repos, read that workflow to find the `dotnet-sonarscanner begin /k:"<key>" /o:"<org>"`.

## Commands

### PRIssues — issues for a pull request

Use `scripts/Get-SonarIssues.ps1`:

```powershell
pwsh -File scripts/Get-SonarIssues.ps1 -PullRequest 49
# Optional overrides:
#   -ProjectKey relias-engineering_configurator
#   -IncludeResolved   (default: only unresolved/open)
```

Or inline:

```powershell
$tok = [Environment]::GetEnvironmentVariable('SONAR_TOKEN','Machine'); if(-not $tok){$tok=$env:SONAR_TOKEN}
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($tok):"))
$headers = @{ Authorization = "Basic $b64" }
$url = 'https://sonarcloud.io/api/issues/search?componentKeys=relias-engineering_configurator&pullRequest=49&resolved=false&ps=100'
(Invoke-RestMethod -Uri $url -Headers $headers).issues |
  Select-Object severity, type, rule, @{n='file';e={$_.component -replace '.*:',''}}, line, message |
  Format-Table -Auto
```

### ProjectIssues — issues on a branch (default: main)

Replace `pullRequest=49` with `branch=main` (or omit for the default branch).

### QualityGate — gate status + measures

```powershell
# Quality gate status for a PR:
$url = 'https://sonarcloud.io/api/qualitygates/project_status?projectKey=relias-engineering_configurator&pullRequest=49'
Invoke-RestMethod -Uri $url -Headers $headers | ConvertTo-Json -Depth 6
```

## Reporting format

When reporting PR issues, present a table with: #, Rule, File, Line, Message, plus
severity/type. Then give a short summary grouping by rule and noting whether anything
is blocking (security/bug/blocker) vs. minor (INFO code smell). Offer to fix trivial ones.

## Useful API endpoints

- Issues:        `GET /api/issues/search?componentKeys={key}&pullRequest={n}&resolved=false&ps=100`
- Quality gate:  `GET /api/qualitygates/project_status?projectKey={key}&pullRequest={n}`
- Measures:      `GET /api/measures/component?component={key}&pullRequest={n}&metricKeys=coverage,new_coverage,duplicated_lines_density,bugs,vulnerabilities,code_smells,security_hotspots`
- Component show: `GET /api/components/show?component={key}` (404 "Project doesn't exist" usually means unauthenticated against a private project)

## Common rules seen on this project & fixes

- **xUnit2032**: `Assert.IsAssignableFrom<T>(x)` → `Assert.IsType<T>(x, exactMatch: false)`.
- **CA2263**: `Enum.GetValues(typeof(T))` → `Enum.GetValues<T>()`.

## Notes / gotchas

- The project is **private**; unauthenticated API calls return `total: 0` or a 404 — always send the auth header.
- GitHub repo secret `SONAR_TOKEN` exists but is **write-only / unreadable**; use the machine env var instead.
- Build PowerShell URLs as a single-quoted literal string to avoid `?`/`&` interpolation issues.
