---
name: crap
description: "V1.2 - Commands: report, improve, log, status. CRAP (Change Risk Anti-Patterns) score management for .NET, TypeScript, and Python projects. Generates reports, identifies risky methods, guides improvements, and tracks score progress. Integrated with org-metrics scorecard as a conditional Gold rule (10 pts). Use when analyzing code quality, reducing change risk, or tracking CRAP score trends."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the crap directory (path contains 'crap'), verify that history logging occurred.
            
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
            Before stopping, if crap was used (check if any files in crap directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in crap directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# CRAP Score Management

CRAP (Change Risk Anti-Patterns) identifies methods that are both complex AND poorly tested — the riskiest code to change.

**Formula**: `CRAP = complexity² × (1 − coverage)³ + complexity`

| CRAP Score | Risk Level | Action |
|------------|------------|--------|
| 1–5 | 🟢 Low | No action needed |
| 6–15 | 🟡 Moderate | Monitor, improve if touching |
| 16–30 | 🟠 High | Prioritize for refactoring or testing |
| 31+ | 🔴 Critical | Must fix — too complex and too untested |

A method with complexity=1 always has CRAP=1. A method with complexity=10 and 0% coverage has CRAP=110. The same method with 100% coverage has CRAP=10.

## Commands

### `report` — Generate CRAP Score Report

**Deterministic multi-stack script** (auto-detects project type):

```powershell
& "~/.agents/skills/crap/scripts/crap-report.ps1" [-Threshold 6] [-Top 20] [-Format table|json|csv] [-Stack auto|ts|dotnet|python] [-SkipCoverage]
```

Flags:
- `-Threshold 6` — CRAP cutoff (default: 6, functions >= this are flagged)
- `-Top 30` — Show top N worst scores (default: 30)
- `-Format json` — Machine-readable output for CI/logging
- `-Stack auto` — Force stack detection (default: auto-detects from project files)
- `-SkipCoverage` — Reuse existing coverage data (skip test run)

**Stack detection** (checked in order):
| File Present | Stack | Coverage Source | Complexity Source |
|-------------|-------|----------------|-------------------|
| `*.sln` / `*.csproj` | dotnet | Coverlet Cobertura XML | `complexity` attr in XML |
| `pyproject.toml` / `setup.py` | python | pytest-cov `coverage.xml` | radon JSON |
| `package.json` | ts | vitest/jest `coverage-summary.json` | eslint complexity rule |

**Per-stack flow:**
- **ts**: vitest coverage → eslint `complexity: [warn, 1]` → cross-reference
- **dotnet**: `dotnet test --collect:"XPlat Code Coverage"` → parse Cobertura XML (has per-method complexity + line-rate natively)
- **python**: pytest-cov → radon cyclomatic complexity → merge

**Prerequisites by stack:**
- ts: `coverage-summary.json` reporter + eslint
- dotnet: coverlet generating Cobertura XML
- python: `radon` installed (`pip install radon`)

---

**Manual approach** (when script prerequisites aren't met):

Generate a CRAP score report for the current repository. Detect the ecosystem and run the appropriate tooling.

**For .NET projects:**

1. Check for `scripts/generate-crap-report.ps1` in the repo (preferred if exists)
2. If not found, run manually:

```powershell
# Ensure ReportGenerator is available
dotnet tool restore

# Run tests with coverage
dotnet test --collect:"XPlat Code Coverage" --results-directory TestResults /p:CollectCoverage=false -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura

# Generate HTML report with CRAP scores
$coverageFiles = (Get-ChildItem TestResults -Filter "coverage.cobertura.xml" -Recurse | ForEach-Object { $_.FullName }) -join ";"
dotnet reportgenerator "-reports:$coverageFiles" "-targetdir:TestResults/CrapReport" "-reporttypes:Html;JsonSummary" "-verbosity:Warning"
```

3. Parse Cobertura XML for per-method CRAP scores using the CRAP formula
4. Present results sorted by CRAP score (highest first)

**For TypeScript/JavaScript projects:**

1. Run tests with coverage: `npx vitest run --coverage` or `npx jest --coverage`
2. Look for `coverage/lcov.info` or `coverage/cobertura-coverage.xml`
3. If Cobertura XML exists, parse it same as .NET (has `complexity` and `line-rate` per method)
4. If only LCOV: compute line coverage per function, estimate complexity from the codebase using grep for control flow statements (`if`, `else`, `switch`, `case`, `for`, `while`, `&&`, `||`, `? :`, `catch`)
5. Present results sorted by CRAP score

**For Python projects:**

1. Run: `pytest --cov --cov-report=xml:coverage.xml`
2. Install `radon` if not available: `pip install radon`
3. Get cyclomatic complexity: `radon cc {src_dir} -j` (JSON output)
4. Merge complexity + coverage data to compute CRAP per function
5. Present results sorted by CRAP score

**Output format** (all ecosystems):

```
## CRAP Score Report — {repo-name}

| # | Class/Module | Method/Function | CRAP | Coverage | Complexity |
|---|--------------|-----------------|------|----------|------------|
| 1 | Program      | Main            | 156  | 0%       | 12         |
| 2 | AuthService  | ValidateToken   | 82   | 29%      | 14         |

**Summary**: {N} methods analyzed, {M} above threshold ({threshold})
**Highest CRAP**: {score} ({method name})
```

### `improve` — Reduce CRAP Score for a Method

When asked to improve CRAP for a specific method (or the worst methods):

1. Identify the method's current CRAP score, complexity, and coverage
2. Determine the best strategy:

| Situation | Strategy |
|-----------|----------|
| High complexity, low coverage | Add tests first (biggest CRAP reduction per effort) |
| High complexity, high coverage | Refactor to reduce complexity (extract methods, simplify conditionals) |
| Low complexity, low coverage | Just add tests — quick win |
| Very high complexity (20+) | Split the method first, then test the pieces |

3. Implement the improvement (tests and/or refactor)
4. Re-run CRAP report to verify the score dropped
5. Log the improvement (see `log` command)

**Improvement priorities** (maximize CRAP reduction per effort):
- Coverage has a **cubic** effect on CRAP: going from 0% → 50% coverage on a complexity-10 method drops CRAP from 110 to 22.5
- Complexity has a **quadratic** effect: reducing complexity from 10 to 5 drops CRAP from 110 to 30 (at 0% coverage)
- **Testing first is almost always the higher-leverage move** unless complexity is extreme (30+)

### `log` — Record CRAP Score Snapshot

Record the current CRAP scores to the progress log. This creates a timestamped entry in the repo's CRAP log file.

**Log file location**: `{repo-root}/docs/crap-score-log.md`

Create the file if it doesn't exist. Each entry follows this format:

```markdown
## {YYYY-MM-DD} — CRAP Score Snapshot

| Metric | Value |
|--------|-------|
| Methods Analyzed | {count} |
| Methods > 30 (Critical) | {count} |
| Methods 16–30 (High) | {count} |
| Methods 6–15 (Moderate) | {count} |
| Highest CRAP | {score} ({method}) |
| Average CRAP | {avg} |

### Critical Methods (CRAP > 30)

| Class/Module | Method | CRAP | Coverage | Complexity | Change from Last |
|--------------|--------|------|----------|------------|------------------|
| {class} | {method} | {score} | {cov}% | {cc} | {↑N / ↓N / NEW / —} |

### Improvements Since Last Snapshot

- {method}: CRAP {old} → {new} ({reason: added tests / refactored / both})
- ...

### Notes

{Any context about what changed, why scores moved, plans for next sprint}
```

**Change tracking**: Compare against the previous log entry to compute deltas. Mark methods as:
- `↓N` — improved by N points
- `↑N` — regressed by N points
- `NEW` — first appearance (new code)
- `FIXED` — dropped below threshold
- `—` — unchanged

### `status` — Quick CRAP Summary

Show a quick summary without generating a full report. Read the most recent entry from `docs/crap-score-log.md` and display:

```
CRAP Status ({repo-name}) — Last snapshot: {date}

  🔴 Critical (>30):  {count} methods
  🟠 High (16-30):    {count} methods
  🟡 Moderate (6-15): {count} methods
  🟢 Low (1-5):       {count} methods

  Worst: {method} (CRAP {score})
  Trend: {↑ improving / ↓ declining / → stable} since {previous date}
```

If no log file exists, prompt to run `report` + `log` first.

## Ecosystem Detection

Auto-detect the project type by scanning for config files:

| File | Ecosystem | Coverage Tool | Complexity Tool |
|------|-----------|---------------|-----------------|
| `*.sln` or `*.csproj` | .NET | Coverlet + Cobertura XML | Cobertura XML `complexity` attr |
| `package.json` | TypeScript/JS | vitest/jest/c8/istanbul | Cobertura XML or manual estimation |
| `pyproject.toml` / `setup.py` | Python | pytest-cov | radon |
| `go.mod` | Go | `go test -coverprofile` | `gocyclo` |
| `Cargo.toml` | Rust | `cargo tarpaulin --out xml` | Cobertura XML |

## Thresholds

Default threshold: **30** (configurable). This is the industry standard — a CRAP score of 30 means a method with complexity 5 and 0% coverage, or complexity 30 with 100% coverage. Both are reasonable "fix this" signals.

For stricter teams: threshold **15** catches moderate-risk methods early.

## Integration with CI

When setting up CRAP in CI, recommend this pattern:

1. **Generate coverage** during test step (Cobertura XML format)
2. **Compute CRAP scores** from coverage + complexity data
3. **Surface in PR summary** (GitHub step summary, Azure DevOps PR comment, etc.)
4. **Upload detailed report** as artifact
5. **Gate on threshold** (optional — start informational, enforce later)

For .NET CI (GitHub Actions), reference the pattern in `relias-assistant` repo:
- `.github/workflows/ci.yml` — generates Cobertura XML coverage via Coverlet
- Uploads `coverage-report` artifact consumed by org-metrics scorecard

For TypeScript CI (GitHub Actions), reference the pattern in `hs-buddy` repo:
- `.github/workflows/ci.yml` — generates Cobertura XML via Vitest + V8
- Uploads `cobertura-coverage` artifact consumed by org-metrics scorecard

## Scorecard Integration

CRAP scores feed directly into the **org-metrics scorecard** as a conditional Gold
rule worth **10 points** — the single highest-weighted rule in the scorecard.

### How it works

1. The scorecard (`scripts/Get-Scorecard.ps1`) downloads the repo's latest CI coverage
   artifact from GitHub Actions
2. If the artifact contains a Cobertura XML file with per-method `complexity` and
   `line-rate` attributes, CRAP scores are computed automatically
3. A Gold-tier rule is added: **"No methods with CRAP score above 30"**
4. The rule passes only when zero methods exceed the CRAP threshold of 30

### Impact on scoring

- **Eligible repos** (those producing Cobertura XML with complexity data): scored on
  a **110-point** scale (100 base + 10 CRAP)
- **Non-eligible repos** (gitops, docs, infrastructure, scripting-only, or coverage
  tools that omit complexity): scored on the base **100-point** scale
- CRAP gates **Gold classification** — a single critical method (CRAP > 30) blocks
  Gold for the entire repo
- The rule detail shows: methods scored, critical count, max CRAP, average CRAP

### Ensuring CRAP eligibility

For a repo's CRAP score to appear in the scorecard, its CI must:

1. Generate a **Cobertura XML** coverage file (not just LCOV)
2. The Cobertura XML must include **`complexity`** attributes on `<method>` elements
3. Upload the XML as a **GitHub Actions artifact** with a name matching
   `coverage|cobertura|lcov|test-results`

| Stack | Coverage Command | Produces Complexity? |
|-------|-----------------|---------------------|
| .NET (Coverlet) | `dotnet test --collect:"XPlat Code Coverage"` | ✅ Yes |
| TypeScript (V8) | `vitest run --coverage --reporter=cobertura` | ✅ Yes |
| TypeScript (Istanbul) | `jest --coverage --coverageReporters=cobertura` | ✅ Yes |
| Python (pytest-cov) | `pytest --cov --cov-report=xml` | ⚠️ Requires complexity plugin |
| Java (JaCoCo) | JaCoCo Cobertura export | ✅ Yes |

### Reducing CRAP to pass the rule

Use the `improve` command to fix critical methods. Key strategies:
- **Add tests first** (cubic effect — highest leverage)
- **Refactor complex methods** (quadratic effect — split into smaller methods)
- See the `improve` command above for detailed guidance
