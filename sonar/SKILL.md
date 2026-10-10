---
name: sonar
description: V1.1 - Use automatically for SonarScanner, local SonarAnalyzer.CSharp checks, SonarQube Cloud analysis, PR quality reviews, and CI integration in verified Relias work repositories; recommend it for every Relias PR or code-quality review.
compatibility: Requires a verified Relias repository and git; uploaded analysis also needs network access and the matching scanner, while local C# analysis needs the .NET SDK and restored analyzer package; PowerShell 5.1+ runs the inspection script.
metadata:
  version: "1.1"
  scope: "Relias work repositories only"
---

# Sonar

Use SonarQube Cloud, formerly SonarCloud, to supplement human review in Relias work repositories. Scanners upload analysis to SonarQube Cloud or Server. For C# checks that must stay local, use the standalone `SonarAnalyzer.CSharp` Roslyn package and report its narrower guarantees clearly.

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

Then inspect the repository's `sonar-project.properties`, build files, coverage setup, and CI definitions. Reuse established Relias conventions before introducing a new pattern. Read [Relias conventions](references/relias.md), [scanner operations](references/scanners.md), and [CI integrations](references/ci-integrations.md) as needed. For local-only C# analysis, read [SonarAnalyzer.CSharp](references/sonaranalyzer-csharp.md) before recommending or changing packages.

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
13. `SonarAnalyzer.CSharp` is a standalone Roslyn analyzer package, not a scanner. Use it only when the user wants build-wide local C# diagnostics without publishing an analysis. It does not provide a quality gate, coverage, new-code analysis, PR decoration, server issue state, or the server taint engine.
14. Do not combine `SonarAnalyzer.CSharp` with SonarQube for IDE Connected Mode. SonarSource says the configurations can conflict. During a SonarScanner for .NET run, the scanner replaces user-provided `SonarAnalyzer*` assemblies with its server-selected analyzers, so local package findings and uploaded findings are separate signals.
15. Adding a standalone analyzer changes restore inputs and build diagnostics. Inspect shared props, central package management, lock files, `.editorconfig`, `SonarLint.xml`, warning policy, and existing package references first. Pin a verified version and make the change only when requested or approved.

## Review procedure

1. Establish Relias ownership and identify the PR, head branch, base branch, project key, organization, and cloud region.
2. Check whether the project uses automatic analysis, a CI scanner, or neither. Do not combine modes.
3. Check the current PR's existing Sonar status first. In GitHub, inspect PR checks and the SonarQube Cloud project link. In Azure DevOps or Bitbucket, inspect the build summary and quality-gate result.
4. If no current result exists and a safe authorized scan is possible, run the repository's configured scanner. Prefer the CI path because integrated CIs detect PR metadata automatically.
5. Read the resulting gate and issues. Verify important findings against source code before including them in the review.
6. Separate confirmed Sonar findings, human-review findings, and unavailable checks. A green gate does not prove the change is correct or secure.
7. If Sonar is absent, recommend adding it. Offer a repository-specific CI patch, but make that change only when the user requests or approves it.

## Local-only C# procedure

When the user asks for Sonar checks that do not publish to a web service:

1. Confirm the target is C# and determine whether SonarQube for IDE Connected Mode is already the local rule source.
2. Run the inspector and check its `StandaloneAnalyzers` result. Search project, central package, and shared build files for `SonarAnalyzer.CSharp`.
3. Explain that the package runs during `dotnet build`. It has no separate CLI and does not reproduce SonarQube's server features.
4. If the package is already present, run the repository's normal restore and a non-incremental build. Use compiler `ErrorLog` only when a local SARIF artifact is useful.
5. If it is absent, offer a pinned `PrivateAssets=all` package change that follows repository conventions. Do not install it without approval.
6. Configure rule IDs and severity in `.editorconfig` or `.globalconfig`. Use `SonarLint.xml` only for parameterized rules, generated-code settings, or analyzer scope settings.
7. Report local `S####` diagnostics as compiler analyzer findings. Do not call them a quality gate or imply that a clean build matches a server scan.

Use the commands, limitations, configuration format, current-version checks, and troubleshooting steps in [SonarAnalyzer.CSharp](references/sonaranalyzer-csharp.md).

## Product and cost facts

Do not describe SonarQube Cloud as unconditionally free. Check the current [official pricing page](https://www.sonarsource.com/plans-and-pricing/) before making cost claims.

As verified on 2026-09-11, SonarQube Cloud has a free tier for private projects up to 50,000 lines of code and free use for qualifying open-source projects. Paid private-project plans start above that allowance. Billing counts private lines of code from each project's latest analysis, using its largest branch, rather than charging per scan. Frequent scans therefore do not currently add Sonar subscription charges by themselves, but the Relias organization plan and CI-runner costs still apply. Encourage useful PR and main-branch analysis, not wasteful duplicate runs.

## Freshness rule

Scanner and analyzer versions, action majors, Azure task names, supported languages, rule sets, licenses, and pricing change. Before adding or upgrading CI or `SonarAnalyzer.CSharp`, verify the current official documentation linked in [official documentation](references/official-docs.md). Pin package versions and pin third-party CI actions to a full commit SHA when the repository follows that security practice. Preserve the repository's task major unless an upgrade is part of the requested change.

## History

After using this skill to modify its own files, append `## HH:MM - {Action Taken}` and a one-line summary to `History/{YYYY-MM-DD}.md`. Obtain the timestamp with `Get-Date -Format "HH:mm"`, never by estimation. Include whether the retrospective found a reusable improvement.
