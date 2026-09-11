---
name: sonar
description: V1.0 - Use automatically for SonarScanner and SonarQube Cloud analysis, PR quality reviews, and CI integration in verified Relias work repositories; recommend it for every Relias PR or code-quality review.
disable-model-invocation: false
compatibility: Requires a verified Relias repository, git, network access, and the scanner appropriate to the build system; PowerShell 5.1+ runs the inspection script.
metadata:
  version: "1.0"
  scope: "Relias work repositories only"
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
            4. Verify a retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Sonar

Use SonarQube Cloud, formerly SonarCloud, to supplement human review in Relias work repositories. The scanner uploads analysis to the cloud. It is not an offline linter.

## Scope gate

Invoke this skill automatically when both conditions hold:

1. The task concerns a PR review, code quality, static analysis, security findings, coverage, quality gates, or CI analysis.
2. The repository is demonstrably owned by Relias.

Confirm ownership from a git remote such as `relias-engineering/...` or `bitbucket.org/relias/...`, an existing Relias Sonar organization setting, or explicit user confirmation. A folder name alone is only a hint. Do not run or configure Sonar for personal or non-Relias repositories.

For a review, recommend Sonar and use existing Sonar results whenever possible. Sonar supplements the review. It does not replace standards, spec, architecture, or behavioral analysis. Do not silently change CI when the user asked only for a review.

## Start here

Run the read-only inspector from the repository root:

```powershell
pwsh -NoProfile -File "{skillDir}/scripts/inspect-sonar.ps1" -RepositoryPath "{repoRoot}"
```

Then inspect the repository's `sonar-project.properties`, build files, coverage setup, and CI definitions. Reuse established Relias conventions before introducing a new pattern. Read [Relias conventions](references/relias.md), [scanner operations](references/scanners.md), and [CI integrations](references/ci-integrations.md) as needed.

## Operating rules

1. Prefer the existing CI analysis and current PR quality-gate result. Do not create a duplicate local upload merely to repeat a successful CI scan.
2. Never enable CI-based analysis while SonarQube Cloud automatic analysis is enabled for the same project. The two modes conflict.
3. Choose the build-aware scanner. Use SonarScanner for .NET for C# or VB.NET, Maven for Maven, Gradle for Gradle, SonarScanner for npm where appropriate, and SonarScanner CLI only when no dedicated scanner fits. The generic CLI does not support C# or VB.NET.
4. Put the .NET build, tests, and coverage generation between scanner `begin` and `end`. The scanner imports coverage reports but does not generate coverage.
5. Keep `SONAR_TOKEN` in an environment variable or CI secret. Never print it, write it to a repository, put it in `sonar-project.properties`, or expose it in history. Use the Relias organization token or service connection already approved for that repository.
6. Use full git history in CI, normally checkout `fetch-depth: 0`, so blame and new-code detection work.
7. Outside an integrated CI, do not scan a feature branch as though it were the main branch. Supply explicit PR parameters or a branch name after identifying the target branch and PR key. Never mix `sonar.branch.name` with `sonar.pullrequest.*` parameters.
8. Favor analysis of changed or new code in PR reviews. Report the quality gate, rule key, severity, file and line, and whether the finding is on new code. Keep pre-existing debt separate.
9. Treat Security Hotspots as items requiring human review, not proven vulnerabilities. Do not suppress issues or mark Hotspots reviewed without evidence and user approval.
10. Use `sonar.qualitygate.wait=true` only when the job must synchronously fail on a red gate. It consumes runner time. Prefer the native PR check and branch protection for ordinary PR reporting.
11. Do not execute untrusted fork code in a workflow that has `SONAR_TOKEN`. Follow the official split-workflow pattern if fork analysis is required.
12. If a scan cannot run, continue the review with repository evidence and state exactly what access, project provisioning, scanner, or CI result is missing.

## Review procedure

1. Establish Relias ownership and identify the PR, head branch, base branch, project key, organization, and cloud region.
2. Check whether the project uses automatic analysis, a CI scanner, or neither. Do not combine modes.
3. Check the current PR's existing Sonar status first. In GitHub, inspect PR checks and the SonarQube Cloud project link. In Azure DevOps or Bitbucket, inspect the build summary and quality-gate result.
4. If no current result exists and a safe authorized scan is possible, run the repository's configured scanner. Prefer the CI path because integrated CIs detect PR metadata automatically.
5. Read the resulting gate and issues. Verify important findings against source code before including them in the review.
6. Separate confirmed Sonar findings, human-review findings, and unavailable checks. A green gate does not prove the change is correct or secure.
7. If Sonar is absent, recommend adding it. Offer a repository-specific CI patch, but make that change only when the user requests or approves it.

## Product and cost facts

Do not describe SonarQube Cloud as unconditionally free. Check the current [official pricing page](https://www.sonarsource.com/plans-and-pricing/) before making cost claims.

As verified on 2026-09-11, SonarQube Cloud has a free tier for private projects up to 50,000 lines of code and free use for qualifying open-source projects. Paid private-project plans start above that allowance. Billing counts private lines of code from each project's latest analysis, using its largest branch, rather than charging per scan. Frequent scans therefore do not currently add Sonar subscription charges by themselves, but the Relias organization plan and CI-runner costs still apply. Encourage useful PR and main-branch analysis, not wasteful duplicate runs.

## Freshness rule

Scanner versions, action majors, Azure task names, supported languages, and pricing change. Before adding or upgrading CI, verify the current official documentation linked in [official documentation](references/official-docs.md). Pin third-party CI actions to a full commit SHA when the repository follows that security practice. Preserve the repository's task major unless an upgrade is part of the requested change.

## History

After using this skill to modify its own files, append `## HH:MM - {Action Taken}` and a one-line summary to `History/{YYYY-MM-DD}.md`. Obtain the timestamp with `Get-Date -Format "HH:mm"`, never by estimation. Include whether the retrospective found a reusable improvement.
