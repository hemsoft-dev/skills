---
name: github-init
description: V1.2 - Initializes a new GitHub repository and local git history for a project using a deterministic PowerShell script.
---

# GitHub Init

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Use this skill as the absolute first step in any project scaffolding to ensure history is tracked from the start. This skill uses a PowerShell script to ensure a deterministic outcome.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Workflow

1. **Profile Selection (CRITICAL)**
   - **Mandatory Step**: Ask the user which GitHub profile to use: **Personal1** (HemSoft) or **Work1** (Relias).
   - **Never proceed** without this information.
   - This selection determines the SSH host alias used for the remote.

2. **Owner Selection (CRITICAL)**
   - Determine if the repo should be created under the **user account** or an **organization**.
   - **Default**: Use the user account unless explicitly requested otherwise:
     - Personal1 → `HemSoft` (user) or `fhemmer` (org)
     - Work1 → `fhemmerrelias` (user) or `relias-engineering` (org)
   - **User account repos**: Personal projects, experiments, individual ownership (e.g., `github.com/HemSoft/repo`)
   - **Organization repos**: Team projects, official releases, shared ownership (e.g., `github.com/fhemmer/repo`)

3. **Execute Initialization Script**
   - Run the `github-init.ps1` script located in the scripts subdirectory: `c:\Users\User\.agents\skills\github-init\scripts\github-init.ps1`.
   - Use the following parameters:
     - `RepoName`: The name of the repository.
     - `Owner`: The GitHub **username** (e.g., `HemSoft`) or **organization** (e.g., `fhemmer`).
     - `Profile`: "Personal1" or "Work1".
     - `Visibility`: (Optional) "private" (default), "public", or "internal".
   - **Report Success**: Always provide the user with the URL to the newly created repository.

## Requirements

- Requires GitHub CLI (`gh`) to be installed and authenticated.
- SSH keys must be configured in `~/.ssh/config` with appropriate aliases (`github-personal1`, `github-work1`).

## Important: GitHub CLI Auth Switching

The `gh` CLI can have multiple accounts authenticated, but only one is **active** at a time. Before creating a repo, ensure the correct account is active:

```powershell
# Check current auth status
gh auth status

# Switch to the account matching your profile
gh auth switch --user HemSoft       # For Personal1
gh auth switch --user fhemmerrelias # For Work1
```

**The script does NOT auto-switch auth** - you must do this manually before running if the wrong account is active.

## Known Repositories

| Repo | Profile | Owner | Visibility | Path | Purpose |
|------|---------|-------|------------|------|---------|
| `public-skills` | Personal1 | HemSoft | Public | `D:\github\HemSoft\public-skills` | Public agent skills for skills.sh ecosystem |
| `hs-buddy-vscode-extension` | Personal1 | HemSoft | Private | `D:\github\HemSoft\hs-buddy-vscode-extension` | HemSoft Buddy VS Code productivity extension suite |
