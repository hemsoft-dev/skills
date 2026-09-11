# Relias conventions

## Proving work scope

Treat the repository as Relias work only when there is concrete evidence, such as:

- a git remote under `relias-engineering` on GitHub
- a git remote under `bitbucket.org/relias`
- an existing `sonar.organization` value for a Relias organization
- explicit confirmation from the user

Local folders such as `D:\github\Relias` and `D:\bitbucket` help locate likely work but do not prove ownership by themselves.

## Observed organization patterns

Current local Relias repositories show more than one Sonar organization identifier:

- GitHub-hosted projects commonly use `sonar.organization=relias-github` and keys such as `relias-engineering_{repository}`.
- Some Azure Pipelines for Bitbucket-hosted projects use organization `relias`, project-specific keys, and the service connection `Relias SonarCloud`.

These are observations, not universal defaults. Copy the organization and key from the target project's existing Sonar configuration or SonarQube Cloud setup instructions. Never infer a new project key only from a repository name when an existing project may already exist.

## Observed CI patterns

Relias repositories currently include:

- GitHub Actions using `SonarSource/sonarqube-scan-action`
- GitHub Actions using the .NET global tool around `dotnet build` and tests
- Azure Pipeline templates using prepare, analyze, and publish tasks
- checked-in `sonar-project.properties` files
- coverage imports for OpenCover and other test tooling
- action pinning to full commit SHAs in security-conscious workflows

Reuse the target repository's established pattern. Do not copy a workflow from another Relias repository without checking language, organization, key, region, runner OS, secret name, and coverage paths.

## Local workstation snapshot

Verified on 2026-09-11:

- `dotnet-sonarscanner` is installed as a global .NET tool, version 11.3.0.
- `SONAR_TOKEN` is present in the environment. Its value was not read or displayed.
- Generic `sonar-scanner` was not found on `PATH`.
- Java was not found on the Git Bash `PATH`.

Run `scripts/inspect-sonar.ps1` every time. This snapshot will age.

## Review behavior

For every Relias PR or quality review:

1. Look for a current Sonar PR check before running anything.
2. Use Sonar findings as evidence, then verify important findings in the source.
3. Focus on the changed code and the new-code quality gate.
4. State when Sonar is absent, skipped, stale, or inaccessible.
5. Recommend CI integration when absent, but do not add it during a review without approval.
6. Do not assume a green gate covers spec compliance, architecture, authorization logic, runtime behavior, or every dependency risk.

## Cost guidance

The SonarQube Cloud subscription is currently LOC-based rather than scan-count-based. Re-running analysis does not by itself add billable LOC when the same private project and largest branch size are unchanged. Even so, CI minutes and developer time have costs, and duplicate scans can create confusing or stale results. Use Sonar often where it creates a current PR or main-branch signal. Skip redundant uploads.
