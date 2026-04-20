---
name: mutation-testing
description: "V1.0 - Ad-hoc mutation testing for TypeScript and C# projects using Stryker. Use when assessing test suite quality, finding weak tests, or running periodic mutation analysis. NOT for CI/per-commit use."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the mutation-testing directory (path contains 'mutation-testing'), verify that history logging occurred.
            
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
            Before stopping, if mutation-testing was used (check if any files in mutation-testing directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in mutation-testing directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Mutation Testing with Stryker

Ad-hoc mutation testing to assess test suite quality in TypeScript and C# projects.

## Default Behavior

When activated without a specific request, ask:

> What would you like to do?
>
> 1. **Setup** — initialize Stryker in a project (TypeScript or C#)
> 2. **Run** — execute mutation testing on a target module
> 3. **Review** — analyze a previous mutation report and identify weak tests
> 4. **Compare** — compare mutation scores across runs to track trends

Then guide through the relevant workflow below.

## Philosophy: Ad-Hoc, Not CI

| Principle | Detail |
|---|---|
| **Frequency** | Monthly, quarterly, or per-sprint — NOT per-commit or in CI |
| **Scope** | Target critical modules (auth, payments, business logic) — not the entire codebase |
| **Goal** | Find weak tests, not gate deployments |
| **Output** | Actionable list of survived mutants → write targeted tests to kill them |
| **Tracking** | Compare mutation scores over time to measure test quality improvement |

## Tool: Stryker

| Language | Package | Docs |
|---|---|---|
| TypeScript/JavaScript | `@stryker-mutator/core` | [stryker-mutator.io](https://stryker-mutator.io) |
| C# / .NET | `dotnet-stryker` | [stryker-mutator.io/docs/stryker-net](https://stryker-mutator.io/docs/stryker-net/introduction/) |

## Project Layout

All mutation testing artifacts live in a dedicated `.mutation-testing/` folder at the project root. This keeps configs, reports, and scripts separate from production code.

```text
{project-root}/
├── .mutation-testing/
│   ├── stryker.conf.json          # TypeScript: Stryker config
│   ├── stryker-config.json        # C#: Stryker.NET config
│   ├── run-mutation-test.ps1      # Script to execute a run
│   └── reports/                   # HTML/JSON reports (gitignored)
│       └── {YYYY-MM-DD}/
├── .gitignore                     # Add: .mutation-testing/reports/
└── src/                           # Your source code
```

**Add to `.gitignore`:**

```text
.mutation-testing/reports/
```

## Workflow 1: Setup — TypeScript

### Step 1: Install Stryker

```bash
npm install --save-dev @stryker-mutator/core @stryker-mutator/typescript-checker @stryker-mutator/jest-runner
```

Swap `@stryker-mutator/jest-runner` for the appropriate test runner plugin:

| Test Runner | Package |
|---|---|
| Jest | `@stryker-mutator/jest-runner` |
| Vitest | `@stryker-mutator/vitest-runner` |
| Karma | `@stryker-mutator/karma-runner` |
| Mocha | `@stryker-mutator/mocha-runner` |

### Step 2: Create config

Run the setup script or create `.mutation-testing/stryker.conf.json` manually:

```powershell
.\mutation-testing\scripts\Setup-TypeScript.ps1 -ProjectRoot "{project-root}" -TestRunner "jest"
```

Or use Stryker's init command and move the config:

```bash
npx stryker init
```

### Step 3: Configure target modules

Edit `.mutation-testing/stryker.conf.json` — set `mutate` to target specific modules:

```json
{
  "$schema": "https://raw.githubusercontent.com/stryker-mutator/stryker/master/packages/core/schema/stryker-core.json",
  "mutate": [
    "src/services/**/*.ts",
    "!src/**/*.test.ts",
    "!src/**/*.spec.ts"
  ],
  "testRunner": "jest",
  "checkers": ["typescript"],
  "reporters": ["html", "json", "clear-text"],
  "htmlReporter": {
    "fileName": ".mutation-testing/reports/latest/index.html"
  },
  "jsonReporter": {
    "fileName": ".mutation-testing/reports/latest/report.json"
  },
  "thresholds": {
    "high": 80,
    "low": 60,
    "break": null
  }
}
```

## Workflow 2: Setup — C# / .NET

### Step 1: Install Stryker.NET

```bash
dotnet tool install --global dotnet-stryker
```

Or as a local tool:

```bash
dotnet new tool-manifest
dotnet tool install dotnet-stryker
```

### Step 2: Create config

Run the setup script or create `.mutation-testing/stryker-config.json` manually:

```powershell
.\mutation-testing\scripts\Setup-CSharp.ps1 -ProjectRoot "{project-root}" -TestProject "{test-project-path}"
```

### Step 3: Configure target modules

Edit `.mutation-testing/stryker-config.json`:

```json
{
  "stryker-config": {
    "project": "src/MyProject/MyProject.csproj",
    "test-projects": [
      "tests/MyProject.Tests/MyProject.Tests.csproj"
    ],
    "mutate": [
      "src/MyProject/Services/**/*.cs",
      "!src/MyProject/Migrations/**/*.cs"
    ],
    "reporters": ["html", "json", "cleartext"],
    "thresholds": {
      "high": 80,
      "low": 60,
      "break": null
    }
  }
}
```

## Workflow 3: Run Mutation Testing

### TypeScript

```powershell
.\mutation-testing\scripts\Run-MutationTest.ps1 -Language "TypeScript" -ProjectRoot "{project-root}"
```

Or manually:

```bash
npx stryker run --configFile .mutation-testing/stryker.conf.json
```

### C# / .NET

```powershell
.\mutation-testing\scripts\Run-MutationTest.ps1 -Language "CSharp" -ProjectRoot "{project-root}"
```

Or manually:

```bash
cd {test-project-path}
dotnet stryker --config-file ../../.mutation-testing/stryker-config.json
```

### Targeting specific modules

Both scripts accept a `-Mutate` parameter to override the default mutate globs:

```powershell
# TypeScript — only test the auth service
.\mutation-testing\scripts\Run-MutationTest.ps1 -Language "TypeScript" -ProjectRoot "." -Mutate "src/services/auth/**/*.ts"

# C# — only test the payment domain
.\mutation-testing\scripts\Run-MutationTest.ps1 -Language "CSharp" -ProjectRoot "." -Mutate "src/PaymentService/Domain/**/*.cs"
```

## Workflow 4: Review Results

### Reading the report

1. Open the HTML report: `.mutation-testing/reports/latest/index.html`
2. Focus on **survived mutants** — these reveal test gaps
3. For each survived mutant, ask: "Should my tests have caught this?"

### Triage survived mutants

| Category | Action |
|---|---|
| **Real gap** — test should catch this | Write a new test targeting this mutation |
| **Equivalent mutant** — code change has no observable effect | Ignore (Stryker can't always detect these) |
| **Low-value code** — getters, DTOs, boilerplate | Exclude from `mutate` globs |

### Track scores over time

Record after each run:

| Date | Module | Mutation Score | Killed | Survived | Total |
|---|---|---|---|---|---|
| 2026-04-20 | `src/services/auth` | 78% | 156 | 44 | 200 |

## Scripts Reference

| Script | Purpose |
|---|---|
| `scripts/Setup-TypeScript.ps1` | Initialize Stryker config for a TypeScript project |
| `scripts/Setup-CSharp.ps1` | Initialize Stryker config for a C# project |
| `scripts/Run-MutationTest.ps1` | Run mutation testing (supports both languages) |

## ALWAYS: Log This Interaction

Append to `History/{YYYY-MM-DD}.md`:

```markdown
## HH:MM - {Action Taken}
{One-line summary}
```
