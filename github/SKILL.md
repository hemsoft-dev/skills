---
name: github
description: V2.0 - GitHub API operations including billing, usage statistics, Copilot metrics, SSH keys, releases/tags, account management, and unified PR checking for GitHub/Bitbucket via CLI Tools.
---

# GitHub API Skill

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

**CRITICAL:** When running a Copilot usage report:

1. Always run the `Get-MyCopilotUsage.ps1` script to ensure data is current.
2. Present the results in a **Markdown table format** for better readability.
3. Always log the summary results in the `History/` file for the current date.
4. If quotas or plans have changed, update the `Copilot Quota System` section in `SKILL.md`.

## Franz's GitHub Accounts

| Account     | Type        | Email                      | Username      | Plan                                                  |
|-------------|-------------|----------------------------|---------------|-------------------------------------------------------|
| Personal #1 | HemSoft     | <franz_hemmer@hotmail.com> | HemSoft       | Copilot Pro+ (1500 req/mo) + Business (fhemmer org)   |
| Personal #2 | franzhemmer | <fphemmer@gmail.com>       | franzhemmer   | Copilot Business (fhemmer org)                        |
| Work #1     | Relias      | <fhemmer@relias.com>       | fhemmerrelias | Copilot Pro+ (1500 req/mo)                            |

## Franz's Organizations

| Organization                    | Owner(s)                 | Enterprise   | URL                                       |
|---------------------------------|--------------------------|--------------|-------------------------------------------|
| fhemmer (HemSoft Developments)  | Personal #1, Personal #2 | hemsoft-corp | <https://github.com/fhemmer>              |
| Relias Engineering (Relias LLC) | Work #1                  | —            | <https://github.com/relias-engineering>   |

## Franz's Enterprises

| Enterprise   | Slug         | Licenses | Admins               | Orgs    |
|--------------|--------------|----------|----------------------|---------|
| HemSoft Corp | hemsoft-corp | 50       | HemSoft, franzhemmer | fhemmer |

**Enterprise URL**: <https://github.com/enterprises/hemsoft-corp>

## Default Owners by Profile

**CRITICAL**: When creating new repositories, distinguish between **user accounts** and **organizations**:

| Profile     | Username      | Default Owner (User) | Can Also Create In (Org)     | Example User Repo                          | Example Org Repo                           |
|-------------|---------------|----------------------|------------------------------|--------------------------------------------|-----------------------------------------|
| Personal #1 | HemSoft       | `HemSoft`            | `fhemmer`                    | `github.com/HemSoft/repo`                  | `github.com/fhemmer/repo`               |
| Personal #2 | franzhemmer   | `franzhemmer`        | `fhemmer`                    | `github.com/franzhemmer/repo`              | `github.com/fhemmer/repo`               |
| Work #1     | fhemmerrelias | `fhemmerrelias`      | `relias-engineering`         | `github.com/fhemmerrelias/repo`            | `github.com/relias-engineering/repo`    |

**When to use user vs org:**

- **User account** (`HemSoft`, `franzhemmer`, `fhemmerrelias`) - Personal projects, experiments, individual ownership
- **Organization** (`fhemmer`, `relias-engineering`) - Team projects, official releases, shared ownership

**Default behavior**: Unless explicitly specified, create repos under the **user account**, not the organization.

## Copilot Quota System

### Personal Quotas (Pro+ Plans)

- **Pro+**: 1500 premium requests/month included
- Overage: $0.04/request after quota exhausted
- Resets on 1st of each month

### Organization Quotas (Business Plans)

- **Business**: **300 premium requests/seat/month** ($19/seat/mo)
- fhemmer org: 2 seats × 300 = **600 requests/month**
- Overage: $0.04/request after quota exhausted
- GitHub UI shows percentage like "147.6%" when over quota (often relative to individual seat allowance)

### Value Comparison (Requests per Dollar)

| Plan | Price | Requests | Req/$1 |
| :--- | :--- | :--- | :--- |
| Pro | $10/mo | 300 | 30.0 |
| **Pro+** | $39/mo | **1,500** | **38.5** |
| Business | $19/mo | 300 | 15.8 |
| Enterprise | $39/mo | 1,000 | 25.6 |

### Important: Personal vs Org Usage

When a user has BOTH Pro+ personal AND Business org seat:

- **Personal quota**: Tracks requests made under personal context (1,500 req/mo)
- **Org quota**: Tracks requests made in org repos/context (300 req/seat/mo)
- These are **separate quotas** - HemSoft can use 1,500 personal + share 600 org (total 2,100)
- **Context-Based Billing**: Copilot automatically uses the Org quota when working in an Org repo, and the
  Personal quota otherwise.

## Primary Repos (fhemmer org)

| Repo      | Description                              | SSH Clone                                         |
|-----------|------------------------------------------|---------------------------------------------------|
| dashboard | Personal dashboard app (Next.js/Supabase)| `git@github-personal1:fhemmer/dashboard.git`      |

## Usage Check

Run the script to get current billing for all accounts:

```powershell
& "c:\Users\User\.claude\skills\github\scripts\Get-MyCopilotUsage.ps1"
```

Options: -Account personal1|personal2|work|all

## Pull Requests Check

### Quick Check (CLI Tools Repository)

Check PRs across GitHub and Bitbucket with interactive features:

```powershell
& "D:\github\HemSoft\cli-tools\scripts\check-my-prs.ps1" -Once
```

**Options:**

- `-Once` - Run once and exit (default is continuous watch mode)
- `-ApprovedAndOpen` - Show only PRs you approved that are still open
- `-ApprovedAndMergedSince [date]` - Show PRs you approved merged since a date
- `-Interactive` - Enable interactive PR browser (press I to browse, Enter to open)
- `-SkipBitbucket` - Check GitHub only
- `-GitHubOrg [org]` - GitHub org to check (default: relias-engineering)
- `-BitbucketWorkspace [ws]` - Bitbucket workspace (default: relias)
- `-Watch [minutes]` - Refresh interval in watch mode (default: 15)

**Examples:**

```powershell
# Run once (default)
& "D:\github\HemSoft\cli-tools\scripts\check-my-prs.ps1" -Once

# Watch mode (continuous, refresh every 5 minutes)
& "D:\github\HemSoft\cli-tools\scripts\check-my-prs.ps1" -Watch 5

# Check only approved PRs still open
& "D:\github\HemSoft\cli-tools\scripts\check-my-prs.ps1" -ApprovedAndOpen -Once

# GitHub only (skip Bitbucket)
& "D:\github\HemSoft\cli-tools\scripts\check-my-prs.ps1" -SkipBitbucket -Once
```

**Requirements:**

- `gh` CLI installed and authenticated
- `BITBUCKET_API_KEY` and `BITBUCKET_USERNAME` environment variables (for Bitbucket checks)

---

### Legacy Check (Skills Repository)

Check for open PRs you created and PRs awaiting your review:

```powershell
& "c:\Users\User\.claude\skills\github\scripts\Get-MyPRs.ps1"
```

### Required Token Scopes

For full enterprise visibility, ensure the GitHub token has these scopes:

```powershell
gh auth refresh -h github.com -s read:enterprise,manage_billing:enterprise,read:org,repo,user,workflow,gist
```

## SSH Keys (Home PC 2026)

| Account     | Host Alias       | Key File                                        |
|-------------|------------------|-------------------------------------------------|
| Personal #1 | github-personal1 | ~/.ssh/id_ed25519_github_home2026_personal1     |
| Personal #2 | github-personal2 | ~/.ssh/id_ed25519_github_home2026_personal2     |
| Work #1     | github-work1     | ~/.ssh/id_ed25519_github_home2026_work1         |

SSH config location: `~/.ssh/config`

### SSH Config Content

```text
# HemSoft (Personal #1) - franz_hemmer@hotmail.com / HemSoft
Host github-personal1
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_home2026_personal1
    IdentitiesOnly yes

# franzhemmer (Personal #2) - fphemmer@gmail.com / franzhemmer
Host github-personal2
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_home2026_personal2
    IdentitiesOnly yes

# Relias (Work #1) - fhemmer@relias.com / fhemmerrelias
Host github-work1
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_home2026_work1
    IdentitiesOnly yes
```

### Usage Examples

Clone using alias: `git clone git@github-personal1:fhemmer/dashboard.git`

Set remote: `git remote set-url origin git@github-personal1:fhemmer/dashboard.git`

Test connection: `ssh -T git@github-personal1`

## Transferring Repos to fhemmer Org

1. **Transfer on GitHub**: Settings → Danger Zone → Transfer ownership → Select `fhemmer`
2. **Update local remote**: `git remote set-url origin git@github-personal1:fhemmer/REPO.git`
3. **Update Vercel** (if applicable):
   - Install Vercel GitHub App in fhemmer org: <https://github.com/apps/vercel/installations/new>
   - Link project: `bunx vercel link`
   - Connect Git: <https://vercel.com/franz-hemmers-projects/PROJECT/settings/git>
4. **Set secrets**: `gh auth token | gh secret set SECRET_NAME --repo fhemmer/REPO`

## Releases and Tags

### Creating a Release

```powershell
# Tag the current commit
git tag -a v1.0.0 -m "Release v1.0.0 - Description"
git push --tags

# Create release with asset
gh release create v1.0.0 --title "Project v1.0.0" --notes "Release notes here" path/to/asset.zip
```

### Updating a Release (Moving Tag to New Commit)

**CRITICAL**: Tags and releases are linked by name. If you delete and recreate a tag, the release becomes
**orphaned** and points to a non-existent tag (`untagged-XXXXX`).

**Correct workflow to update a release:**

```powershell
# 1. Commit your changes
git add .
git commit -m "Additional changes for v1.0.0"

# 2. Delete the old tag locally AND remotely
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

# 3. Delete the orphaned release
gh release delete v1.0.0 --yes

# 4. Create new tag on latest commit
git tag -a v1.0.0 -m "Release v1.0.0 - Description"
git push
git push --tags

# 5. Recreate the release
gh release create v1.0.0 --title "Project v1.0.0" --notes "Release notes" path/to/asset.zip
```

### Viewing Release Status

```powershell
# View release details (check if orphaned)
gh release view v1.0.0

# List all releases
gh release list

# List all tags
git tag -l
```

### Common Pitfalls

| Problem                         | Cause                                 | Solution                                                                     |
|---------------------------------|---------------------------------------|------------------------------------------------------------------------------|
| Release shows "untagged-XXXXX" | Tag deleted but release not recreated | Delete release with `gh release delete`, recreate both tag and release      |
| Release shows "Draft"           | Release not published                 | Edit on GitHub or recreate without `--draft` flag                           |
| Asset missing from release      | Forgot to attach file                 | `gh release upload v1.0.0 path/to/file.zip`                                 |
