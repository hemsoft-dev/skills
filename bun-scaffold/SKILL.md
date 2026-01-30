# Bun Scaffold

```skill
---
name: bun-scaffold
description: V1.2 - Scaffolds production-ready TypeScript utilities with Bun, Biome linting, Vitest testing (90%+ coverage), pre-commit hooks, and GitHub integration.
---

# Bun Scaffold

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert guide for scaffolding production-quality CLI tools and utilities using TypeScript + Bun with strict quality gates.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Prerequisites

- **Bun**: Must be installed (`powershell -c "irm bun.sh/install.ps1 | iex"`)
- **Git**: Required for repository initialization
- **GitHub CLI**: Authenticated with HemSoft account (verify with `gh auth status`)
- **SSH Config**: `github-personal1` host alias configured in `~/.ssh/config` for HemSoft organization

## Required Metadata

Before scaffolding, collect the following from the user:

1. **Repository Name** (kebab-case, e.g., `my-awesome-tool`)
2. **Project Type** (Tool/Utility/Script/CLI/Automation) - suggest if not provided
3. **Description** (one-liner for README and package.json)
4. **Entry Point Name** (default: camelCase of repo name, e.g., `myAwesomeTool`)
5. **CLI Arguments Needed?** (yes/no - determines if commander is included)
6. **Compile to Executable?** (default: yes)
7. **GitHub Visibility** (default: private)

## Local Project Structure

**MANDATORY**: All projects are created under `D:\github\HemSoft\{repo-name}` where `{repo-name}` is the
kebab-case repository name.

## Tech Stack

- **Runtime**: Bun
- **Language**: TypeScript (strict mode)
- **Linting/Formatting**: Biome (replaces ESLint + Prettier)
- **Testing**: Vitest with 90%+ coverage requirement
- **Console Output**: consola (beautiful logging)
- **CLI Parsing**: commander (if needed)
- **Pre-commit**: husky + lint-staged
- **CI/CD**: GitHub Actions
- **Validation**: Zod (for env vars and inputs)

## Scaffolding Workflow

### High-Level Steps

1. **Collect Metadata** → Get all required information from user
2. **Create Local Directory** → `D:\github\HemSoft\{repo-name}`
3. **Initialize Git** → Local git repository
4. **Switch GitHub Account** → Ensure HemSoft account is active
5. **Create GitHub Repo** → Using HemSoft account
6. **Configure SSH Remote** → Use `github-personal1` host alias
7. **Initialize Bun** → package.json with scripts (NO prepare script yet)
8. **Install Dependencies** → Core + dev dependencies including husky
9. **Add Husky prepare script** → AFTER husky is installed
10. **Configure Tools** → TypeScript, Biome, Vitest, Husky
11. **Create Templates** → README, AGENTS.md, .vscode, .editorconfig
12. **Generate Source** → index.ts + test file
13. **Commit & Push** → Initial commit to GitHub

### 1. Create Project Directory

```powershell
cd D:\github\HemSoft
$repoName = "{repo-name}"
mkdir $repoName
cd $repoName
```

### 2. Initialize Git + GitHub Repository

**CRITICAL**: Ensure correct GitHub account is active before creating repository.

```powershell
# Initialize git
git init
New-Item -ItemType Directory -Force -Path src, tests

# Create .gitignore
@"
node_modules/
bun.lockb
dist/
*.exe
*.log
.env
.env.local
.env.*.local
.vscode/*
!.vscode/settings.json
!.vscode/extensions.json
.idea/
*.swp
*.swo
.DS_Store
Thumbs.db
coverage/
.nyc_output/
*.tsbuildinfo
.eslintcache
"@ | Out-File -FilePath .gitignore -Encoding utf8

git add .gitignore
git commit -m "chore: initialize repository"

# CRITICAL: Switch to HemSoft account before creating repo
gh auth switch -u HemSoft

# Create GitHub repository
gh repo create "HemSoft/{repo-name}" --private --description "{description}" --source=. --remote=origin

# CRITICAL: Update remote to use SSH host alias (not github.com directly)
git remote set-url origin git@github-personal1:HemSoft/{repo-name}.git

git push -u origin main
```

### 3. Initialize Bun Project

**CRITICAL**: Do NOT include `prepare` script initially - it will fail because husky isn't installed yet.

```powershell
bun init -y
# Then manually update package.json WITHOUT the prepare script
```

### 4. Install Dependencies

```powershell
# Core dependencies
bun add zod consola
# CLI parsing (if needed): bun add commander

# Dev dependencies
bun add -d typescript @types/node @types/bun vitest @vitest/coverage-v8 @biomejs/biome husky lint-staged

# NOW add the prepare script (after husky is installed)
# Add "prepare": "husky" to package.json scripts
```

### 5. Configure Biome

**CRITICAL**: Use minimal config or run migration to avoid version mismatch issues.

```powershell
bunx biome init
bunx biome migrate --write
```

Or use this minimal `biome.json` that works with Biome 2.x:

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "vcs": {
    "enabled": true,
    "clientKind": "git",
    "useIgnoreFile": true,
    "defaultBranch": "main"
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true
    }
  },
  "javascript": {
    "formatter": {
      "quoteStyle": "double",
      "trailingCommas": "all",
      "semicolons": "always"
    }
  }
}
```

### 6. Configure Vitest

**CRITICAL**: Use `node:path` protocol for Node.js builtins.

```typescript
import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html", "lcov"],
      thresholds: { lines: 90, functions: 90, branches: 90, statements: 90 },
      exclude: ["node_modules/", "dist/", "tests/", "*.config.*", "**/*.d.ts", "**/*.test.ts"],
    },
  },
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
});
```

### 7. VS Code Settings

**CRITICAL**: Use `source.fixAll.biome` instead of deprecated `quickfix.biome`.

```json
{
  "editor.defaultFormatter": "biomejs.biome",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.biome": "explicit"
  },
  "[typescript]": {
    "editor.defaultFormatter": "biomejs.biome"
  }
}
```

### 8. Source Code Template (with CLI)

**CRITICAL**: Use `error.issues` not `error.errors` for Zod v4.

```typescript
import { Command } from "commander";
import { consola } from "consola";
import { z } from "zod";

const program = new Command();

program
  .name("{entry-point-name}")
  .description("{description}")
  .version("1.0.0")
  .argument("<input>", "input value to process")
  .action((input: string) => {
    try {
      const schema = z.string().min(1);
      const validated = schema.parse(input);
      consola.success("Done!", validated.toUpperCase());
      process.exit(0);
    } catch (error) {
      if (error instanceof z.ZodError) {
        // CRITICAL: Use .issues not .errors for Zod v4
        consola.error("Invalid input:", error.issues[0]?.message);
      } else {
        consola.error("Failed:", error);
      }
      process.exit(1);
    }
  });

program.parse();
```

### 9. Final Steps

```powershell
bun run lint:fix
bun run type-check
bun run lint
bun run test:run
git add .
git commit -m "feat: initial project scaffold"
git push -u origin main
```

## Troubleshooting

### GitHub CLI Wrong Account

```powershell
gh auth status
gh auth switch -u HemSoft
```

### SSH Push Fails

```powershell
git remote -v
git remote set-url origin git@github-personal1:HemSoft/{repo-name}.git
```

### Biome Config Errors

```powershell
bunx biome migrate --write
```

### Husky prepare script fails during bun add

Don't include `"prepare": "husky"` in initial package.json. Add it AFTER installing husky.

## Related Skills

- **`bun-manager`**: For Bun CLI usage and configuration
- **`github-init`**: For repository initialization patterns
- **`how-to-write-tests`**: For testing best practices

```markdown
