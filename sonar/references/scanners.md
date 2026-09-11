# Scanner operations

## Know which command you mean

Sonar has two different command-line products:

- **SonarScanner CLI**, invoked as `sonar-scanner`, runs CI-oriented source analysis when no build-specific scanner fits.
- **SonarQube CLI** is a newer management and agent-oriented tool. It can inspect projects and issues and perform other Sonar operations. It is not a drop-in replacement for every build scanner.

This workstation currently uses the .NET global tool `dotnet-sonarscanner`. Always detect installed tools rather than relying on that snapshot.

## Scanner selection

| Project | Preferred scanner |
| --- | --- |
| C# or VB.NET | SonarScanner for .NET |
| Maven | SonarScanner for Maven |
| Gradle | SonarScanner for Gradle |
| npm-based project | SonarScanner for npm when it fits the build |
| Other supported languages | SonarScanner CLI |
| C, C++, Objective-C | The documented CFamily flow, often including Build Wrapper |

Do not use generic SonarScanner CLI for C# or VB.NET. Do not replace Maven, Gradle, or .NET scanners with the generic CLI. Build-aware scanners produce better analysis.

## Read-only preflight

Run the inspector and then verify:

- Relias ownership
- active branch and remote default branch
- clean or intentionally dirty worktree
- existing Sonar project key and organization
- existing CI or automatic-analysis mode
- scanner and runtime availability
- `SONAR_TOKEN` presence without revealing its value
- build and test commands
- coverage report format and path
- whether the project uses the EU default or US region

The scanner sends analysis data to SonarQube Cloud. A successful command only means upload succeeded. Quality-gate computation may still be pending.

## Generic CLI

Typical `sonar-project.properties`:

```properties
sonar.projectKey={project-key}
sonar.organization={organization}
sonar.sources=.
sonar.sourceEncoding=UTF-8
```

Run from the project base directory:

```powershell
$env:SONAR_TOKEN = "{secret supplied outside the repository}"
sonar-scanner
```

Current scanner versions default to SonarQube Cloud's EU instance. Use `sonar.region=us` for a US-region organization. Older scanners may require `sonar.host.url=https://sonarcloud.io`. Do not add it automatically when the existing setup works.

Useful diagnostics:

```powershell
sonar-scanner --version
sonar-scanner -X
```

Use debug logs only when needed. Review them before sharing because paths and infrastructure details may be sensitive.

## .NET scanner

The .NET global tool is installed as package `dotnet-sonarscanner`. Either invocation may work depending on installation:

```powershell
dotnet-sonarscanner --version
dotnet sonarscanner --version
```

A local analysis has three required phases:

```powershell
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

dotnet-sonarscanner begin `
  /k:"{project-key}" `
  /o:"{organization}" `
  /d:sonar.token="$env:SONAR_TOKEN"

dotnet build "{solution-or-project}" --no-incremental --disable-build-servers
dotnet test "{test-project-or-solution}" --no-build "{coverage arguments}"

dotnet-sonarscanner end /d:sonar.token="$env:SONAR_TOKEN"
```

Pass the token to both `begin` and `end`. On Windows, `--disable-build-servers` or MSBuild `/nodeReuse:false` avoids scanner DLL locks during cleanup. Sonar's build hooks can turn off `WarningsAsErrors`; use a dedicated analysis build if that conflicts with the normal build.

The .NET scanner does not support `sonar.sources` or `sonar.tests`. MSBuild project membership determines those inputs. Use exclusions and supported .NET properties instead.

## PR and branch parameters outside integrated CI

Integrated CI systems normally detect these values. For a truly local PR upload, establish the values from the host before running:

```text
sonar.pullrequest.key={numeric-or-provider-PR-key}
sonar.pullrequest.branch={head-branch}
sonar.pullrequest.base={base-branch}
```

For a non-PR branch analysis:

```text
sonar.branch.name={branch-name}
```

For generic CLI, pass command-line properties with `-D`. For .NET, pass them to `begin` with `/d:`. Never set both branch and PR parameters in one analysis. Prefer CI because local metadata mistakes can attach analysis to the wrong branch or PR.

## Coverage and test results

Sonar does not calculate test coverage. Run the test coverage tool first or during the .NET begin/end window, then point Sonar to the generated report. Common properties include:

- .NET OpenCover: `sonar.cs.opencover.reportsPaths`
- .NET Visual Studio coverage XML: `sonar.cs.vscoveragexml.reportsPaths`
- JavaScript or TypeScript LCOV: `sonar.javascript.lcov.reportPaths`
- Python coverage XML: `sonar.python.coverage.reportPaths`

Reuse the repository's current format. Confirm current property names in the language-specific test coverage docs before adding one. Paths are evaluated in the scanner's workspace, so container and host paths must agree.

## Quality gate and results

Use `sonar.qualitygate.wait=true` to make the scanner wait and fail when the gate is red. `sonar.qualitygate.timeout` controls the wait, with 300 seconds as the documented default. Waiting occupies a CI runner, so use it only where synchronous enforcement is required.

Scanner output includes a dashboard URL and writes a task report, commonly under `.scannerwork/report-task.txt` for generic CLI or `.sonarqube/out/.sonar/report-task.txt` for .NET. Do not commit scanner working directories. Use the task URL to distinguish upload success from server-side processing success.

## Interpreting findings

- Verify each issue against the checked-out revision.
- Focus PR reviews on new code and changed lines.
- A Security Hotspot asks for review. It is not automatically a vulnerability.
- Coverage and duplication are measures, not proof of behavior or maintainability.
- Quality profiles and gates vary by organization and project.
- A green gate means the configured gate passed. It does not mean the PR matches its spec.

## Common failures

- **CI scan conflicts with automatic analysis:** disable one analysis mode.
- **Unauthorized:** verify the secret exists, has Execute Analysis permission, and belongs to the correct organization. Never print it.
- **Missing blame or wrong new code:** fetch full git history.
- **Coverage file not resolved:** verify report generation, file format, paths inside the scanner workspace, and source paths embedded in the report.
- **Wrong project or branch:** stop before retrying. Recheck key, organization, region, and PR or branch parameters.
- **Java runtime failure:** use a current scanner with JRE auto-provisioning or install the documented Java prerequisite.
- **Out of memory:** for SonarScanner CLI 6+, set `SONAR_SCANNER_JAVA_OPTS`, such as `-Xmx512m`, using platform-correct quoting.
- **.NET cleanup lock:** disable build servers or MSBuild node reuse.
