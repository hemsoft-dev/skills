# CI integrations

## Rules shared by every CI

1. Confirm the project exists in the correct Relias SonarQube Cloud organization.
2. Choose CI-based analysis or automatic analysis, never both.
3. Store `SONAR_TOKEN` in the CI secret store or use an approved service connection.
4. Trigger analysis for PR updates and the main integration branch.
5. Fetch full git history.
6. Build and test with the project's native tools. Import coverage reports.
7. Expose the quality-gate result in the PR or build summary.
8. Keep permissions narrow and never expose secrets to untrusted fork code.
9. Use one Sonar project key per independently analyzed monorepo project.
10. Check current official versions before changing an action, pipe, extension, or task major.

## GitHub Actions

For projects that do not need a build-specific scanner, use the official `SonarSource/sonarqube-scan-action`. Relias repositories commonly pin actions to a full commit SHA and use `fetch-depth: 0`.

```yaml
name: SonarQube Cloud
on:
  push:
    branches: [main]
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read

jobs:
  sonar:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@{verified-full-commit-sha}
        with:
          fetch-depth: 0
          persist-credentials: false
      - name: Analyze with SonarQube Cloud
        uses: SonarSource/sonarqube-scan-action@{verified-full-commit-sha}
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

Keep `sonar.projectKey` and `sonar.organization` in `sonar-project.properties` unless the repository has another established arrangement.

For .NET, use `dotnet-sonarscanner begin`, then build and test, then `end`. Install or restore a pinned scanner version in the workflow. Do not use the generic scan action as a substitute for SonarScanner for .NET.

Fork PRs do not receive repository secrets. Never switch to `pull_request_target` and execute fork code with secrets. Use Sonar's documented split build and analysis workflows if fork coverage is required.

For gate enforcement, prefer the SonarQube Cloud PR check plus required-check branch protection. Add `sonar.qualitygate.wait=true` only when the scanner job itself must wait and fail.

## Azure Pipelines

Use the official SonarQube Cloud Azure DevOps extension. Existing Relias pipelines may still use task names such as `SonarCloudPrepare`, `SonarCloudAnalyze`, and `SonarCloudPublish`, while current extension releases may use SonarQube-branded task names. Preserve the repository's working task family and major unless the task is being upgraded deliberately.

The order is:

1. Prepare Analysis Configuration
2. Build, test, and generate coverage
3. Run Code Analysis
4. Publish Quality Gate Result

For .NET, choose the .NET or MSBuild scanner mode. For Java, use Maven or Gradle mode. Use CLI mode for supported projects without a dedicated build scanner.

Existing Relias Azure YAML often uses the approved service connection `Relias SonarCloud`. Confirm it in the target Azure DevOps project rather than assuming it exists. Pass scanner properties without `/d:` in a task's `extraProperties` block.

Skeleton only, because task names and majors change:

```yaml
steps:
  - task: {Sonar-Prepare-Task}@{major}
    inputs:
      sonarCloud: 'Relias SonarCloud'
      organization: '{verified-organization}'
      scannerMode: '{verified-mode}'
      projectKey: '{project-key}'
      projectName: '{project-name}'
      extraProperties: |
        {coverage and exclusion properties}

  - script: '{build and test command}'

  - task: {Sonar-Analyze-Task}@{major}
  - task: {Sonar-Publish-Task}@{major}
```

Check PR triggers separately when Azure Pipelines builds code hosted in GitHub or Bitbucket. Repository binding affects PR decoration and may require provider-specific parameters outside Azure Pipelines.

## Bitbucket Pipelines

The official `sonarsource/sonarcloud-scan` and quality-gate pipes fit projects supported by generic CLI. They do not replace the dedicated Maven, Gradle, .NET, or CFamily flows.

Store `SONAR_TOKEN` as a secured repository or workspace variable. Add the analysis command to both the main branch and `pull-requests` sections. Cache `~/.sonar/cache` when useful.

For monorepos, run each project separately with a unique project key and explicit project base directory. Check the current official pipe version before editing YAML.

Blocking merges from the pipeline's gate result also depends on Bitbucket branch restrictions and plan features. Do not promise merge blocking until those settings are verified.

## GitLab CI

Use the build-specific scanner and a masked, protected `SONAR_TOKEN` CI/CD variable. Cache `.sonar/cache`, fetch enough history for new-code analysis, and trigger merge-request plus default-branch pipelines. GitLab projects accept one `SONAR_TOKEN` variable name, so monorepo jobs must coordinate credentials and unique Sonar project keys.

## Jenkins

Use the SonarQube Scanner Jenkins integration, configure the SonarQube Cloud server and credentials in Jenkins, run the build-specific scanner inside the configured environment, and use the quality-gate webhook or `waitForQualityGate` pattern. The webhook lets Jenkins wait without polling continuously.

## Other CI systems

Run the appropriate scanner and provide explicit PR metadata when the provider is not auto-detected:

```text
sonar.pullrequest.key={key}
sonar.pullrequest.branch={head}
sonar.pullrequest.base={base}
```

Projects bound to Azure DevOps may need extra Azure repository and PR-decoration parameters when analysis runs outside Azure Pipelines. Consult the official parameter page before constructing them.

## Reviewing or changing an existing integration

- Read the complete workflow and all referenced templates.
- Locate every Sonar invocation to avoid duplicate analysis.
- Identify scanner version, action or task version, project key, organization, region, token source, triggers, coverage paths, exclusions, and quality-gate enforcement.
- Verify renamed products and tasks before treating an old name as obsolete. Working `SonarCloud*` tasks may simply predate the SonarQube Cloud rename.
- Preserve generated coverage and build ordering.
- Validate YAML and run the repository's focused tests.
- For a PR review, report a missing or stale Sonar check as a review limitation. Do not manufacture a pass from an older branch scan.
