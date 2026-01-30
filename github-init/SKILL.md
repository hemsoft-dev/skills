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
   - **Mandatory Step**: Ask the user which GitHub profile to use: **Personal1** (HemSoft), **Personal2** (franzhemmer), or **Work1** (Relias).
   - **Never proceed** without this information.
   - This selection determines the SSH host alias used for the remote.

2. **Owner Selection (CRITICAL)**
   - Determine if the repo should be created under the **user account** or an **organization**.
   - **Default**: Use the user account unless explicitly requested otherwise:
     - Personal1 → `HemSoft` (user) or `fhemmer` (org)
     - Personal2 → `franzhemmer` (user) or `fhemmer` (org)
     - Work1 → `fhemmerrelias` (user) or `relias-engineering` (org)
   - **User account repos**: Personal projects, experiments, individual ownership (e.g., `github.com/HemSoft/repo`)
   - **Organization repos**: Team projects, official releases, shared ownership (e.g., `github.com/fhemmer/repo`)

3. **Execute Initialization Script**
   - Run the `github-init.ps1` script located in the scripts subdirectory: `c:\Users\franz\.claude\skills\github-init\scripts\github-init.ps1`.
   - Use the following parameters:
     - `RepoName`: The name of the repository.
     - `Owner`: The GitHub **username** (e.g., `HemSoft`) or **organization** (e.g., `fhemmer`).
     - `Profile`: "Personal1", "Personal2", or "Work1".
     - `Private`: (Optional) Default is `$true`.
   - **Report Success**: Always provide the user with the URL to the newly created repository.

## Requirements

- Requires GitHub CLI (`gh`) to be installed and authenticated.
- SSH keys must be configured in `~/.ssh/config` with appropriate aliases (`github-personal1`, `github-personal2`, `github-work1`).
