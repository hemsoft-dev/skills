# Stack-aware deterministic tooling

Choose tools only after inventorying the repository. Prefer tools already pinned by the project. Confirm current syntax and compatibility from official documentation before recommending or running a version-sensitive tool.

Run external analyzers in non-writing mode. Record the exact version and command. Do not add packages, rewrite configuration, or update a lockfile during the audit.

## JavaScript and TypeScript

- Compiler and lint: TypeScript, ESLint, framework linters, Prettier check mode, markdownlint, and actionlint.
- Dead code and dependency use: Knip or an established equivalent.
- Dependency shape: dependency-cruiser, Madge, package-manager duplicate reports, bundle analyzers, and package-health tools such as e18e when compatible.
- React: React Doctor for deterministic component and hook findings, React Profiler evidence, Testing Library accessibility checks, axe, Lighthouse, Web Vitals, and bundle budgets.
- Tests: Vitest or Jest coverage, Cucumber implementations for Gherkin, Playwright or Cypress for E2E, and StrykerJS for mutation testing.
- Security: package-manager audit, CodeQL or Semgrep rules already supported by the project, dependency review, secret scanning, and framework-specific security checks.
- Desktop JavaScript: Electron security configuration, renderer and main-process memory measurement, IPC schema validation, packaging checks, and update-signing verification.

Do not treat React Doctor or any single score as the audit result. Reproduce high-impact findings and account for framework version, generated code, and deliberate patterns.

## .NET

- Build and style: `dotnet build`, analyzers, warnings-as-errors policy, and `dotnet format --verify-no-changes` when configured.
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

- Build and lint: `go test`, `go vet`, Staticcheck or golangci-lint, formatting, and module verification.
- Tests: race detector, fuzz targets, coverage profiles, benchmarks, and mutation tooling only when maintained and compatible.
- Complexity and CRAP inputs: a maintained cyclomatic or cognitive complexity analyzer plus function-level coverage.
- Security: govulncheck, gosec where useful, secret scanning, and module provenance.
- Performance and memory: Go benchmarks with benchstat, pprof CPU and heap profiles, goroutine growth, and descriptor checks.

## Rust

- Build and lint: Cargo checks, rustfmt check mode, Clippy with repository policy, documentation tests, and feature-matrix builds.
- Tests: cargo test, llvm-cov or the repository's coverage tool, cargo-mutants when compatible, property tests, fuzzing, and Miri for suitable unsafe-code checks.
- Security and supply chain: cargo-audit, cargo-deny, lockfile review, unsafe-code policy, and provenance.
- Performance and memory: Criterion or project benchmarks, cargo-bloat, allocation or heap profilers, and sanitizer runs where supported.

## Web, mobile, infrastructure, and mixed repositories

- Web applications: Lighthouse, axe, browser performance traces, request waterfalls, bundle budgets, visual regression tests, and heap snapshots.
- Native mobile: platform linters, unit and UI tests, startup metrics, package size, leak detectors, accessibility scans, signing, and store-policy checks.
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

- A tool must cover a real audit question and support the repository's current language or framework version.
- Prefer structured output and stable exit codes over subjective scores.
- Do not stack multiple tools that report the same signal unless they catch meaningfully different defects.
- Treat unavailable credentials, unsupported platforms, and flaky analyzers as coverage gaps, not passing results.
- If adoption would materially slow CI, design tiered pull-request and scheduled gates with explicit required-check behavior.
