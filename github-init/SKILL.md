---
name: github-init
description: V1.1 - Initializes a new GitHub repository and local git history for a project using a deterministic PowerShell script.
---

# GitHub Init

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

2. **Execute Initialization Script**
   - Run the `github-init.ps1` script located in the skill directory: `c:\Users\franz\.claude\skills\github-init\github-init.ps1`.
   - Use the following parameters:
     - `RepoName`: The name of the repository.
     - `Owner`: The GitHub organization or username.
     - `Profile`: "Personal1", "Personal2", or "Work1".
     - `Private`: (Optional) Default is `$true`.
   - **Report Success**: Always provide the user with the URL to the newly created repository.

## Requirements
- Requires GitHub CLI (`gh`) to be installed and authenticated.
- SSH keys must be configured in `~/.ssh/config` with appropriate aliases (`github-personal1`, `github-personal2`, `github-work1`).
