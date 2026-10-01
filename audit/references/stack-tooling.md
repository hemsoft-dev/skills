# Stack-aware deterministic tooling

Choose tools only after inventorying the repository. Prefer tools already pinned by the project. Confirm current syntax and compatibility from official documentation before recommending or running a version-sensitive tool.

Run external analyzers in non-writing mode. Record the exact version and command. Do not add packages, rewrite configuration, or update a lockfile during the audit.

## Required stack evidence

Create one row for every applicable check. Use these columns in the HTML report:

| Stack or project | Check | Tool and version | Command and scope | Result | Native score or summary | Enforcement | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |

Use `Pass`, `Fail`, `Blocked`, or `Missing control` for `Result`. A missing configured tool is not a reason to omit its row. State whether the check runs on pull requests, merge, release, schedule, or only on demand. Keep these checks separate when they apply:

- compiler diagnostics;
- type checking;
- source linting;
- formatter check mode;
- framework-specific diagnostics;
- Markdown and documentation linting;
- workflow, configuration, and infrastructure linting.

Record tool-native scores verbatim with the tool version, scan scope, project name, and finding counts. Do not normalize, average, or add them to the repository score. Map their evidence to the appropriate fixed concerns instead. If a score requires network access, source upload, telemetry, or a write, follow the audit safety contract and mark only that score `Blocked` when it cannot run safely.

Run Markdown linting for maintained Markdown whenever the repository contains it. Exclude generated, vendored, fixture, and cached files only with evidence. Inspect configuration, ignored paths, and whether CI enforces the same scope.

## JavaScript and TypeScript

- Type checking: run the repository's pinned TypeScript command, such as `tsc --noEmit`, separately from ESLint. Record project references, skipped library checks, emitted files, and included or excluded source sets.
- Source and configuration lint: ESLint, framework linters, actionlint, and relevant configuration linters. Record warning counts and whether warnings fail CI.
- Formatting and documentation: Prettier check mode and markdownlint. Do not treat formatting as a substitute for linting or type checking.
- Dead code and dependency use: Knip or an established equivalent.
- Dependency shape: dependency-cruiser, Madge, package-manager duplicate reports, bundle analyzers, and package-health tools such as e18e when compatible.
- React: run a full compatible React Doctor scan for every detected React project and record its numeric score, tool version, scan scope, project or aggregate name, and error and warning counts. Prefer structured JSON and the repository's pinned command. Use the official [React Doctor CLI reference](https://www.react.doctor/docs/reference/cli-reference) for current options such as `--json`, `--score`, `--scope full`, and `--project`. Also inspect React Profiler evidence, Testing Library accessibility checks, axe, Lighthouse, Web Vitals, and bundle budgets where applicable.
- Tests: Vitest or Jest coverage, Cucumber implementations for Gherkin, Playwright or Cypress for E2E, and StrykerJS for mutation testing.
- Security: package-manager audit, CodeQL or Semgrep rules already supported by the project, dependency review, secret scanning, and framework-specific security checks.
- Desktop JavaScript: Electron security configuration, renderer and main-process memory measurement, IPC schema validation, packaging checks, and update-signing verification.

Do not treat React Doctor or any single score as the audit result. Reproduce high-impact findings and account for framework version, generated code, deliberate patterns, monorepo project selection, and whether scoring required an external request.

## .NET

- Compiler and Roslyn analyzers: run the repository's pinned `dotnet build` configuration and capture compiler and analyzer diagnostics separately when the output permits it. Inspect `EnableNETAnalyzers`, `AnalysisLevel`, `AnalysisMode`, `.editorconfig` severities, warnings-as-errors settings, `NoWarn`, generated-code exclusions, global suppressions, and analyzer package versions.
- Style and formatting: run `dotnet format --verify-no-changes` or its repository-owned equivalent when configured. Keep whitespace, style, and analyzer diagnostics distinct in the evidence.
- Additional analyzers: exercise checked-in StyleCop, Roslynator, Meziantou, SonarAnalyzer, security analyzers, or custom Roslyn analyzers through the build that owns them. Prefer SARIF or structured logs when already configured. Do not install a new analyzer during the audit.
- Tests and coverage: `dotnet test`, the repository's coverage collector, and report generation that preserves per-method complexity and coverage.
- Mutation: Stryker.NET with checked-in thresholds and CI enforcement.
- Architecture: existing architecture tests, dependency rules, API compatibility checks, and package vulnerability scanning.
- Performance and memory: BenchmarkDotNet, allocation diagnostics, `dotnet-counters`, traces, and dump analysis when suitable for the target.

## Python

- Build and lint: Ruff, formatter check mode, mypy or Pyright, packaging validation, and documentation lint.
- Tests: pytest with branch coverage, Hypothesis where property testing fits, mutmut or Cosmic Ray for mutation, and behave or pytest-bdd for Gherkin.
- Complexity and CRAP inputs: Radon or another maintained complexity source plus per-function coverage data.
- Security and dependencies: Bandit, pip-audit, lockfile checks, and existing Semgrep rules.
- Performance and memory: pyperf or pytest-benchmark, cProfile or py-spy, tracemalloc, and object-growth evidence.

## Java and JVM

- Build and style: Maven or Gradle verification, Checkstyle, SpotBugs, PMD, Error Prone, and dependency analysis already compatible with the build.
- Tests: JUnit, JaCoCo branch coverage, Cucumber JVM, PIT mutation testing, ArchUnit, and Testcontainers where integration boundaries justify it.
- Security: OWASP dependency checks, supported static analysis, secret scanning, and build provenance.
- Performance and memory: JMH, Java Flight Recorder, heap histograms, and retained-object analysis.

## Go

- Build and lint: run `gofmt -l`, `go test`, `go vet`, and the repository-pinned Staticcheck or golangci-lint configuration as separate checks. Record build tags, package scope, generated-code exclusions, disabled linters, warning policy, and module verification.
- Tests: race detector, fuzz targets, coverage profiles, benchmarks, and mutation tooling only when maintained and compatible.
- Complexity and CRAP inputs: a maintained cyclomatic or cognitive complexity analyzer plus function-level coverage.
- Security: govulncheck, gosec where useful, secret scanning, and module provenance.
- Performance and memory: Go benchmarks with benchstat, pprof CPU and heap profiles, goroutine growth, and descriptor checks.

## Rust

- Build and lint: run Cargo build or check, `cargo fmt --check`, Clippy with the repository's warning policy, documentation tests, and feature-matrix builds as separate checks. Record target triples, enabled features, workspace exclusions, allowed lints, and whether all targets are covered.
- Tests: cargo test, llvm-cov or the repository's coverage tool, cargo-mutants when compatible, property tests, fuzzing, and Miri for suitable unsafe-code checks.
- Security and supply chain: cargo-audit, cargo-deny, lockfile review, unsafe-code policy, and provenance.
- Performance and memory: Criterion or project benchmarks, cargo-bloat, allocation or heap profilers, and sanitizer runs where supported.

## Swift and Apple platforms

- Inventory: distinguish Swift Package Manager libraries and tools from Xcode application, framework, extension, widget, watchOS, visionOS, and mixed Swift or Objective-C targets. Record the Swift and Xcode versions, SDKs, deployment targets, package resolution, schemes, configurations, test plans, destinations, and supported device and OS matrix.
- Compiler and build: run the repository-owned `swift build` or `xcodebuild build` command for every supported configuration that CI claims to cover. Capture warnings, warnings-as-errors policy, strict concurrency settings, actor-isolation diagnostics, availability checks, generated-source behavior, and conditional compilation flags.
- Lint and formatting: run the pinned SwiftLint configuration and SwiftFormat or `swift format` check mode as separate rows when present. Record enabled and disabled rules, baseline files, inline suppressions, excluded paths, analyzer rules, warning counts, and whether CI enforces the same scope.
- Static analysis: run the repository's Xcode Analyze or `xcodebuild analyze` flow when declared. Include Clang Static Analyzer results for Objective-C, C, or C++ targets and any checked-in security or architecture analyzers. Do not treat a clean Swift compiler build as a substitute for these checks.
- Tests and coverage: run Swift Testing or XCTest unit, integration, snapshot, and UI suites through the declared SwiftPM or Xcode test plan. Record skipped tests, expected failures, retries, destination coverage, parallelization, and code coverage from the current `.xcresult` or `xccov` output. Do not reuse an older result bundle as current evidence.
- UI and accessibility: inspect XCUITest coverage of critical journeys, accessibility identifiers, Dynamic Type, VoiceOver labels and traits, contrast, reduced motion, localization, right-to-left layouts, keyboard input, multitasking, and supported form factors. Run automated accessibility audits when the repository and target OS support them.
- Performance and memory: inspect XCTest performance metrics, launch and hang measurements, MetricKit evidence, Instruments or `xctrace` runs, retain cycles, task and notification cancellation, autorelease behavior, background execution, thermal impact, disk growth, and package size. Require repeatable evidence before calling a leak or regression.
- Security and privacy: inspect entitlements, capabilities, App Transport Security, keychain access groups, data protection, URL schemes, universal links, WebView policy, local storage, logging, privacy manifests, required-reason APIs, usage descriptions, and secret handling. Treat code signing, provisioning, notarization, and App Store credentials as external controls that need authorization before use.
- Release: inspect archive and export settings, signing identities, version and build numbering, dSYM and symbol upload, TestFlight or store workflows, phased release, migration and rollback behavior, and whether every shipped target comes from the audited revision.

Apple-platform execution requires a compatible macOS host and installed Xcode toolchain. When the audit runs elsewhere, inspect project files and hosted CI evidence, then mark only the commands that require the unavailable host, simulator, device, signing identity, or store access as `Blocked`.

## Web, mobile, infrastructure, and mixed repositories

- Web applications: Lighthouse, axe, browser performance traces, request waterfalls, bundle budgets, visual regression tests, and heap snapshots.
- Native mobile outside Apple platforms: platform linters, unit and UI tests, startup metrics, package size, leak detectors, accessibility scans, signing, and store-policy checks.
- Shell and automation: ShellCheck, PSScriptAnalyzer, actionlint, zizmor, pinned action references, least-privilege workflow permissions, and safe quoting.
- Containers and infrastructure: Hadolint, Trivy, Checkov, tfsec or TFLint, policy-as-code, kubeconform, image provenance, non-root execution, and minimal build context.
- Databases and APIs: migration verification, schema lint, contract tests, query plans, N+1 detection, load tests, rate-limit behavior, and backup restore evidence.

## CRAP measurement

Use a tool that can join per-function cyclomatic complexity with per-function coverage. If the ecosystem lacks a maintained direct CRAP reporter, export machine-readable complexity and coverage data and calculate:

```text
CRAP = complexity^2 * (1 - coverage)^3 + complexity
```

Coverage is a fraction from 0 to 1. Prefer branch coverage, identify the coverage source, keep generated code exclusions explicit, and publish the worst functions as a CI artifact. The gate should fail on new functions above the repository threshold and prevent the existing worst score from increasing. A separate cleanup plan can lower legacy scores without hiding them.

## Tool-selection rules

- Prefer a repository-owned quality runner after inspecting its side effects and comparing its gate list, targets, tool pins, exclusions, and failure behavior with CI and configuration. Run omitted independent gates separately.
- Use the repository's pinned tool versions. A missing pin or unavailable pinned tool is a policy gap or blocker, not permission to install `latest` or substitute a different version.
- A tool must cover a real audit question and support the repository's current language or framework version.
- Prefer structured output and stable exit codes over subjective scores.
- Do not stack multiple tools that report the same signal unless they catch meaningfully different defects.
- Treat unavailable credentials, unsupported platforms, and flaky analyzers as coverage gaps, not passing results.
- If adoption would materially slow CI, design tiered pull-request and scheduled gates with explicit required-check behavior.
