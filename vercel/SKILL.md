---
name: vercel
description: V1.3 - Vercel CLI for deploying, managing, and developing Next.js and frontend applications on Vercel's platform.
---

# Vercel CLI

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Command-line interface for deploying and managing applications on Vercel.

## Franz's Vercel Setup

| Account | Username | Projects |
|---------|----------|----------|
| Personal | fphemmer | franz-hemmers-projects |

### Key Projects

| Project | Domain | Repo |
|---------|--------|------|
| dashboard | <https://dashboard.hemmer.us> | fhemmer/dashboard |

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Installation

```bash
# Bun (preferred)
bun add -g vercel

# npm
npm i -g vercel

# yarn
yarn global add vercel

# pnpm
pnpm i -g vercel
```

Verify: `vercel --version`

## Authentication

```bash
# Interactive login (opens browser)
vercel login

# Login with token (CI/CD)
vercel login --token <TOKEN>

# Logout
vercel logout
```

### Config Locations

- **Linux**: `~/.local/share/com.vercel.cli/`
- **macOS**: `~/Library/Application Support/com.vercel.cli/`
- **Windows**: `%APPDATA%\Roaming\xdg.data\com.vercel.cli\`

Files: `config.json` (settings), `auth.json` (credentials - never share)

## Core Commands

### Deploy

```bash
# Deploy to preview
vercel

# Deploy to production
vercel --prod

# Deploy specific directory
vercel ./app

# Deploy with environment variables
vercel --env KEY1=value1 --env KEY2=value2

# Deploy with build-time env vars
vercel --build-env NODE_ENV=production

# Deploy to specific regions
vercel --regions iad1,sfo1

# Deploy prebuilt output
vercel --prebuilt

# Skip domain assignment (manual promote later)
vercel --prod --skip-domain

# Non-interactive deployment
vercel --yes
```

### Project Linking

```bash
# Link local directory to Vercel project
vercel link

# Creates .vercel directory with project.json
```

### Environment Variables

```bash
# Pull env vars to local file
vercel env pull                    # → .env.local
vercel env pull .env               # → .env
vercel env pull --environment=production

# Add env var
vercel env add MY_VAR production
vercel env add MY_VAR --project my-project

# List env vars
vercel env ls
vercel env ls --project my-project

# Remove env var
vercel env rm MY_VAR production
```

### Local Development

```bash
# Start local dev server (mirrors Vercel environment)
vercel dev

# Custom port
vercel dev --listen 5005

# Skip setup prompts
vercel dev --yes
```

### Inspect & Logs

```bash
# View deployment details
vercel inspect <deployment-url>

# View build logs
vercel inspect <deployment-url> --logs

# View logs and wait for completion
vercel inspect <deployment-url> --logs --wait

# Stream deployment logs
vercel logs <deployment-url>
```

### Domains & Aliases

```bash
# Set alias for deployment
vercel alias set <deployment-url> <custom-domain>

# Remove alias
vercel alias rm <custom-domain>

# Remove with confirmation skip
vercel alias rm <custom-domain> --yes
```

### Promote & Rollback

```bash
# Promote deployment to production
vercel promote <deployment-url>

# Promote with team scope
vercel promote <deployment-url> --scope my-team
```

### Redeploy

```bash
# Redeploy existing deployment
vercel redeploy <deployment-id-or-url>

# Redeploy without waiting
vercel redeploy <deployment-url> --no-wait
```

### Remove

```bash
# Remove single deployment
vercel remove <deployment-url>

# Remove multiple deployments
vercel remove <url-1> <url-2>

# Remove entire project
vercel remove <project-name>

# Safe removal (protects active URLs)
vercel remove <project-name> --safe

# Skip confirmation
vercel remove <deployment-url> --yes
```

### Pull Project Settings

```bash
# Pull project settings and env vars
vercel pull

# Pull for specific environment
vercel pull --environment=preview
vercel pull --environment=production
vercel pull --environment=staging

# Non-interactive
vercel pull --yes
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to Vercel
env:
  VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
  VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Vercel CLI
        run: npm install --global vercel@latest
      - name: Pull Vercel Environment
        run: vercel pull --yes --environment=production --token=${{ secrets.VERCEL_TOKEN }}
      - name: Build
        run: vercel build --prod --token=${{ secrets.VERCEL_TOKEN }}
      - name: Deploy
        run: vercel deploy --prebuilt --prod --token=${{ secrets.VERCEL_TOKEN }}
```

### Required Secrets

- `VERCEL_TOKEN`: Personal access token from Vercel dashboard
- `VERCEL_ORG_ID`: Team/org ID (from `.vercel/project.json` after linking)
- `VERCEL_PROJECT_ID`: Project ID (from `.vercel/project.json` after linking)

## Token-Based Authentication

For CI/CD and automation:

```bash
# Use token directly
vercel --token <TOKEN> <command>

# Or set environment variable
export VERCEL_TOKEN=<TOKEN>
vercel <command>
```

## Project Configuration (vercel.json)

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "buildCommand": "bun run build",
  "devCommand": "bun run dev",
  "installCommand": "bun install",
  "framework": "nextjs",
  "regions": ["iad1"],
  "functions": {
    "api/**/*.ts": {
      "memory": 1024,
      "maxDuration": 10
    }
  }
}
```

## Common Workflows

### Initial Setup

```bash
vercel login
vercel link
vercel env pull
vercel dev
```

### Deploy Preview → Production

```bash
vercel                           # Preview deployment
vercel --prod                    # Production deployment
```

### Staged Rollout

```bash
vercel --prod --skip-domain      # Deploy without domain assignment
vercel promote <deployment-url>  # Manually promote when ready
```

### Using bunx (No Global Install)

```bash
bunx vercel whoami               # Check auth
bunx vercel link                 # Link project
bunx vercel --prod               # Deploy to production
bunx vercel env ls               # List env vars
```

## Connecting Git Repository After Repo Transfer

When transferring a GitHub repo to a new org/account:

1. **Install Vercel GitHub App** in the new org:

   ```
   https://github.com/apps/vercel/installations/new
   ```

   - Select the organization
   - Grant access to specific repos or all repos

2. **Link the local project**:

   ```bash
   bunx vercel link
   ```

3. **Connect Git via Dashboard** (CLI has issues with SSH URLs):

   ```
   https://vercel.com/<team>/<project>/settings/git
   ```

   - Disconnect old repo (if connected)
   - Connect new repo from the org

4. **Test deployment**:

   ```bash
   bunx vercel --prod
   ```

### Git Connect CLI Issues

The `vercel git connect` command may fail with SSH-style URLs:

```bash
# This may fail:
vercel git connect https://github.com/org/repo

# Error: Failed to parse URL "git@github-personal:org/repo.git"
```

**Workaround**: Use the Vercel Dashboard to connect Git repos.

## CLI Shortcuts

| Command | Shorthand |
|---------|-----------|
| `vercel` | `vc` |
| `--env` | `-e` |
| `--build-env` | `-b` |
| `--listen` | `-l` |
| `--yes` | `-y` |

## Troubleshooting

### Diagnosing Failed Deployments

The most reliable way to get build logs for failed deployments:

```bash
# This is the key command - vercel logs doesn't work for errored deployments
vercel inspect <deployment-url> --logs --wait
```

Note: `vercel logs <url>` will fail with "Deployment not ready" for errored builds. Always use `inspect --logs --wait` instead.

### Repeated Login Prompts

- Token may have expired
- Check `auth.json` exists and is valid
- Re-run `vercel login`

### Build Failures

Common causes:

1. **TypeScript errors** - Vercel runs fresh builds with strict checking. Always run `tsc --noEmit` locally before pushing.
2. **Missing environment variables** - Use `vercel env ls` to verify
3. **Nullable database fields** - Ensure null checks for fields like `created_at` when using `new Date()`

```bash
# Get detailed build logs
vercel inspect <url> --logs --wait

# List deployments to find URLs
vercel ls
```

### Environment Variable Issues

```bash
vercel env ls
vercel env pull --environment=production
```

### Deprecated CLI Flags (Avoid)

These flags are silently ignored:

- `--output` (on logs command)
- `--since` (on logs command)

### VS Code Extension

The community extension `frenco.vscode-vercel` has known issues:

- Endless "Loading..." spinner (GitHub Issue #11)
- OAuth authentication problems
- **Recommendation**: Use CLI instead of the extension for reliability
