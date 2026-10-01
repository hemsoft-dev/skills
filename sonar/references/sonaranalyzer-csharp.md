# SonarAnalyzer.CSharp

Research verified on 2026-09-11 against SonarSource source code, Sonar documentation, NuGet, Microsoft documentation, and a local smoke test.

## Identity

The exact package ID is `SonarAnalyzer.CSharp`, with American spelling and a `z`. It is a NuGet package containing SonarSource's C# Roslyn diagnostic analyzer. It is not a CLI and does not provide a `sonar-analyzer` command. Adding it to a project makes the compiler run it during IDE and build analysis. The official [sonar-dotnet repository](https://github.com/SonarSource/sonar-dotnet) describes it as the standalone NuGet form of Sonar's .NET analyzer, and the official [NuGet package](https://www.nuget.org/packages/SonarAnalyzer.CSharp) identifies SonarSource as its verified owner.

The package is different from:

| Component | Job | Sends an analysis to a server |
| --- | --- | --- |
| `SonarAnalyzer.CSharp` | Runs C# Roslyn rules in the compiler | No |
| `dotnet-sonarscanner` | Orchestrates build analysis and submits it to SonarQube Cloud or Server | Yes |
| SonarQube for IDE | Reports issues while editing; Connected Mode syncs server settings and advanced findings | No full-project upload; Connected Mode communicates with the server |
| SonarQube Cloud or Server | Stores findings, computes measures, and applies quality profiles and gates | Receives scanner analysis |

SonarSource staff describes the NuGet package's purpose as providing rules when developers cannot access SonarQube Cloud or Server. The same guidance says not to combine the package with SonarQube for IDE in Connected Mode because the setups can contradict each other. See the first-party [Sonar community answer](https://community.sonarsource.com/t/intention-of-nuget-package-sonaranalyzer-csharp-after-change-in-sonarlint/114941/4) and its [explicit confirmation](https://community.sonarsource.com/t/intention-of-nuget-package-sonaranalyzer-csharp-after-change-in-sonarlint/114941/6).

## What stays local

A normal `dotnet build` with the package emits `S####` diagnostics through Roslyn. It does not need `SONAR_TOKEN`, a Sonar project key, `dotnet-sonarscanner begin`, or `dotnet-sonarscanner end`. The released package contains the analyzer DLL and package support files, not a scanner client. The analyzer source contains no upload path. Scanner-only metric exporters stay disabled unless scanner-generated configuration and an output path are present. See the released [NuGet specification](https://github.com/SonarSource/sonar-dotnet/blob/842fee9569f61c426f48218c3733b3fad124fd78/analyzers/packaging/SonarAnalyzer.CSharp.nuspec) and [utility analyzer activation code](https://github.com/SonarSource/sonar-dotnet/blob/842fee9569f61c426f48218c3733b3fad124fd78/analyzers/src/SonarAnalyzer.Core/Rules/Utilities/UtilityAnalyzerBase.cs).

Package restore can still contact a NuGet feed, perform NuGet audit checks, and download the package. That network activity is package acquisition, not publication of source analysis. After restore, `dotnet build --no-restore` runs the analyzer without a Sonar service.

## What local analysis provides

The package provides compiler diagnostics for Sonar's public C# Roslyn rules. Findings include source locations, rule IDs, messages, related locations where a rule supplies them, and occasional code fixes in supported IDEs. Findings obey normal Roslyn severity and suppression controls. The current source tree advertises more than 480 C# rules in the [official README](https://github.com/SonarSource/sonar-dotnet/blob/842fee9569f61c426f48218c3733b3fad124fd78/README.md).

At version `10.34.0.3385`, the source release has metadata for 481 C# rules. Its bundled [Sonar way profile](https://github.com/SonarSource/sonar-dotnet/blob/842fee9569f61c426f48218c3733b3fad124fd78/analyzers/rspec/cs/Sonar_way_profile.json) enables 345 by default. That default set contains 90 rules categorized as bugs, 39 as vulnerabilities, and 216 as code smells in the standard classification. These counts change as rules are added, removed, or reclassified. Verify the current release rather than copying the snapshot into policy.

The analyzer maps Sonar way membership to Roslyn's `IsEnabledByDefault`. Ordinary diagnostics use Roslyn warning severity even when Sonar metadata calls a rule Blocker, Critical, Major, or Minor. See the [diagnostic descriptor factory](https://github.com/SonarSource/sonar-dotnet/blob/842fee9569f61c426f48218c3733b3fad124fd78/analyzers/src/SonarAnalyzer.Core/Analyzers/DiagnosticDescriptorFactory.cs). This means local compiler severity is not a complete copy of server-side issue severity or impact.

## What it does not provide

The standalone package is not a local edition of SonarQube. It does not provide:

- a Sonar dashboard, project history, issue workflow, or shared quality profile;
- a quality gate or new-code comparison;
- branch or pull-request decoration;
- coverage calculation or coverage import;
- duplication and project measures as a consumable local report;
- server-side issue status such as Accepted or False Positive;
- commercial advanced rules or injection vulnerabilities that require Sonar's taint engine;
- dependency analysis or Software Composition Analysis;
- a supported standalone Sonar report format.

Sonar's IDE documentation says injection vulnerabilities requiring taint analysis are available only in Connected Mode after server analysis. See [rules in SonarQube for Visual Studio](https://docs.sonarsource.com/sonarqube-for-visual-studio/using/rules#unsupported-rules). SonarSource also states that the commercial taint analyzer is not distributed as a public NuGet package in its [security analyzer answer](https://community.sonarsource.com/t/finding-sonaranalyzer-security-analyzer/21199/4).

A compiler SARIF file is available and useful, but it is a compiler and analyzer log rather than a SonarQube report. It can include compiler diagnostics and findings from every loaded analyzer.

## Choosing it

Use `SonarAnalyzer.CSharp` when all of these are true:

1. The repository is C#.
2. The user wants build-wide local diagnostics with no Sonar upload.
3. A shared Sonar quality gate, advanced server analysis, and PR decoration are not required for this run.
4. The repository does not already rely on SonarQube for IDE Connected Mode as its local rule source.

Keep using SonarScanner for .NET when the result must appear in SonarQube Cloud or Server, use the server quality profile, feed a quality gate, import coverage, or participate in pull-request analysis. The official C# documentation requires [SonarScanner for .NET](https://docs.sonarsource.com/sonarqube-cloud/analyzing-source-code/languages/csharp) for server analysis.

Do not add the package merely to repeat a healthy existing CI scan. Do not add it during a review without approval because it changes restore inputs, build diagnostics, and potentially build success.

## Installation

First inspect all project, central package, and shared build files:

```powershell
rg -n 'SonarAnalyzer\.(CSharp|VisualBasic)' --glob '*.csproj' --glob '*.props' --glob '*.targets' --glob 'Directory.Packages.props'
dotnet list package --include-transitive
```

Check the current [NuGet package](https://www.nuget.org/packages/SonarAnalyzer.CSharp) and [release notes](https://github.com/SonarSource/sonar-dotnet/releases). Pin the approved version. As verified on 2026-09-11, the latest stable package and release are `10.34.0.3385`. The package version does not need to match the SonarQube Server version.

For one project:

```powershell
dotnet add path/to/Project.csproj package SonarAnalyzer.CSharp --version {verified-version}
```

The explicit project form recommended by NuGet is:

```xml
<ItemGroup>
  <PackageReference Include="SonarAnalyzer.CSharp" Version="{verified-version}">
    <PrivateAssets>all</PrivateAssets>
    <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
  </PackageReference>
</ItemGroup>
```

`PrivateAssets=all` prevents the analyzer dependency from flowing to consumers of a packaged library. The package itself is marked as a development dependency. See the package's [NuGet metadata](https://www.nuget.org/packages/SonarAnalyzer.CSharp#dependencies-body-tab) and Microsoft's [PackageReference asset rules](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#controlling-dependency-assets).

A reference only analyzes the project that receives it. For a solution-wide policy, use the repository's existing central package management or `Directory.Build.props` convention rather than editing projects inconsistently. Preserve lock files and run restore after the change.

## Running it

There is no package-specific command. Build the intended solution or project:

```powershell
dotnet restore path/to/Solution.sln
dotnet build path/to/Solution.sln --no-restore --no-incremental
```

`--no-incremental` is useful for a deliberate audit because it prevents an up-to-date build from hiding whether analyzers ran. A normal development build need not force this.

To save compiler and analyzer findings locally as SARIF:

```powershell
New-Item -ItemType Directory -Force artifacts | Out-Null
dotnet build path/to/Solution.sln `
  --no-restore `
  --no-incremental `
  /p:ErrorLog=artifacts/sonar-analyzer.sarif
```

Microsoft documents `ErrorLog` as a log of all compiler and analyzer diagnostics in [C# compiler options](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-options/errors-warnings#errorlog). Do not present that file as a Sonar quality gate or upload it without checking repository policy. It may contain source paths and diagnostic excerpts.

## Configuring rules

Use `.editorconfig` or `.globalconfig` for rule activation and Roslyn severity. Sonar rule IDs use the `S####` form:

```ini
root = true

[*.cs]
dotnet_diagnostic.S1764.severity = error
dotnet_diagnostic.S3903.severity = warning
dotnet_diagnostic.S100.severity = none
```

Valid Roslyn severity values include `default`, `error`, `warning`, `suggestion`, `silent`, and `none`. Rule-specific entries can enable a rule that is disabled by default. They can also disable or raise a default rule. Microsoft documents precedence and severity behavior in [code-analysis configuration](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/configuration-options#severity-level). SonarSource confirms `.editorconfig` and `.globalconfig` support in its [standalone NuGet instructions](https://github.com/SonarSource/sonar-dotnet/blob/842fee9569f61c426f48218c3733b3fad124fd78/README.md#standalone-nuget).

Prefer explicit rule IDs for enforceable policy. Broad `TreatWarningsAsErrors` affects compiler warnings and all analyzers, not only Sonar. A verified smoke test showed that it promotes Sonar warnings to build errors. Roll out a baseline deliberately rather than surprising a mature repository with hundreds of newly enforced diagnostics.

Standard Roslyn suppression methods apply, including `.editorconfig`, `NoWarn`, `#pragma warning`, and `SuppressMessage`. Suppress only with evidence. Keep the reason near the suppression when the mechanism supports one.

### Parameterized rules and scope

Rule parameters, generated-code behavior, and file inclusion settings use an additional `SonarLint.xml` file. The official README gives this shape:

```xml
<?xml version="1.0" encoding="utf-8"?>
<AnalysisInput xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Settings>
    <Setting>
      <Key>sonar.cs.analyzeGeneratedCode</Key>
      <Value>false</Value>
    </Setting>
  </Settings>
  <Rules>
    <Rule>
      <Key>S107</Key>
      <Parameters>
        <Parameter>
          <Key>max</Key>
          <Value>2</Value>
        </Parameter>
      </Parameters>
    </Rule>
  </Rules>
</AnalysisInput>
```

Add it to each affected project as an analyzer input:

```xml
<ItemGroup>
  <AdditionalFiles Include="SonarLint.xml" />
</ItemGroup>
```

The current reader recognizes rule parameters and settings including `sonar.cs.analyzeGeneratedCode`, `sonar.cs.analyzeRazorCode`, `sonar.cs.ignoreHeaderComments`, source and test inclusions, and source and test exclusions. See [SonarLintXmlReader](https://github.com/SonarSource/sonar-dotnet/blob/842fee9569f61c426f48218c3733b3fad124fd78/analyzers/src/SonarAnalyzer.Core/Configuration/SonarLintXmlReader.cs). Generated code is skipped by default. The standalone analyzer detects test projects heuristically and applies each rule's Main, Tests, or All scope.

Do not hand-maintain `SonarLint.xml` as an attempted clone of a server quality profile unless the repository owns that maintenance cost. The NuGet package cannot connect to SonarQube Cloud to synchronize the profile. Connected Mode is the supported synchronized setup.

## Interaction with SonarScanner for .NET

During scanner analysis, SonarScanner for .NET downloads the analyzer and active rule settings selected by the server. Its build targets remove user-provided assemblies whose file names begin with `SonarAnalyzer` and replace them with scanner-selected analyzers. See the scanner's [duplicate removal code](https://github.com/SonarSource/sonar-scanner-msbuild/blob/111abab6aeccf9d2f8c4908d8084322cea5dbf4b/src/SonarScanner.MSBuild.Tasks/GetAnalyzerSettings.cs#L250-L264) and [MSBuild target replacement](https://github.com/SonarSource/sonar-scanner-msbuild/blob/111abab6aeccf9d2f8c4908d8084322cea5dbf4b/src/SonarScanner.MSBuild.Tasks/Targets/SonarQube.Integration.targets#L695-L703).

This prevents straightforward duplicate loading during a scanner build, but it also means the checked-in package version and local `.editorconfig` are not proof of which Sonar analyzer or rule profile the server scan used. Review local package diagnostics and uploaded Sonar results as related but distinct signals.

## Versioning, compatibility, and license

The analyzer package has its own release line. Do not infer compatibility from matching major numbers with SonarQube Server or SonarScanner for .NET. Check the package release notes, build host, SDK, language version, and repository lock policy before upgrading.

The current package has no target-framework library assets and no NuGet dependencies. It carries one merged analyzer DLL under the NuGet `analyzers` directory, so the compiler host rather than the application's target framework loads it. The current Sonar Cloud language page states support for C# 1 through C# 14, but that statement changes over time. Verify the [current C# support page](https://docs.sonarsource.com/sonarqube-cloud/analyzing-source-code/languages/csharp#supported-versions) during upgrades.

Current source and package releases use the [SONAR Source-Available License v1.0](https://github.com/SonarSource/sonar-dotnet/blob/842fee9569f61c426f48218c3733b3fad124fd78/LICENSE.txt). It is source-available rather than a conventional permissive open-source license. Review the license before redistributing, modifying, or embedding the analyzer in another product.

## Troubleshooting

- No `S####` findings: confirm the package is referenced by every intended project, restore succeeded, analyzers run during build, the rule is enabled, and the build was not skipped as up to date.
- Wrong rule set: check `.editorconfig`, `.globalconfig`, `NoWarn`, ruleset files, `SonarLint.xml`, and whether a scanner build replaced the package analyzer.
- IDE and build disagree: compare IDE analyzer execution settings, SDK and Roslyn versions, package restore state, generated code, target framework builds, and Connected Mode.
- Build suddenly fails: inspect `TreatWarningsAsErrors`, `WarningsAsErrors`, and rule-specific error settings before suppressing findings.
- Slow builds: measure a clean or non-incremental build with and without the package at the same revision. Do not disable rules based on a subjective timing impression.
- `AD0001` analyzer failures: capture the complete diagnostic, SDK version, package version, and minimal source. Upgrade only after checking current release notes and reproducing the failure.
- Missing injection findings: the standalone package does not include the server taint engine. Use authorized SonarQube Cloud or commercial Server analysis.

## Verified smoke test

A .NET 8 console project was tested on 2026-09-11 with .NET SDK `10.0.108` and `SonarAnalyzer.CSharp` `10.34.0.3385`.

- `dotnet build --no-restore` reported `S1764` locally.
- `/p:ErrorLog=sonar.sarif` created a SARIF file containing compiler and Sonar diagnostics.
- `.editorconfig` set `S1764` to `none`, and the Sonar finding disappeared while the equivalent compiler warning remained.
- `TreatWarningsAsErrors=true` promoted Sonar warnings to errors.
- No scanner command, token, project key, server URL, scanner working directory, or Sonar upload was involved.

Treat this as a behavior check, not a compatibility guarantee for other SDK and analyzer versions.
