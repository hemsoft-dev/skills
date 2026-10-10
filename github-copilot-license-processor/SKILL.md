---
name: github-copilot-license-processor
description: "V1.7 - Commands: Process, Status, Install, SetMode. Polls Slack for Relias GitHub Copilot license requests, validates organization membership, safely assigns seats, and posts audit receipts."
compatibility: Requires PowerShell 7, GitHub CLI authentication, Slack bot access, and Windows Task Scheduler or a Linux systemd user timer
---

# GitHub Copilot License Processor

## Default Behavior

When activated without a command, run **Status**. Never enable live mode without
explicit user approval.

## Commands

| Command | Script | Purpose |
| --- | --- | --- |
| `Process` | `scripts/Invoke-CopilotLicenseProcessor.ps1` | Scan Slack and process the pending queue |
| `Status` | `scripts/Get-CopilotLicenseProcessorStatus.ps1` | Show mode, queue, task, and last-run status |
| `Install` | `scripts/Install-CopilotLicenseProcessorTask.ps1` | Secure the Slack token and register the task |
| `SetMode` | `scripts/Set-CopilotLicenseProcessorMode.ps1` | Switch between `DryRun` and `Live` |

One-shot live processing:

```powershell
.\scripts\Invoke-CopilotLicenseProcessor.ps1 -Live -ConfirmLive
```

## Workflow

1. Poll `#github-copilot` for new top-level messages.
2. Treat a message as a request when it uses the legacy Copilot request phrase
   or tags GH Admin. Extract the GitHub username and email.
3. Respond explicitly when a recognized request is missing either required field.
4. Queue requests persistently so dry-run scans do not lose them.
5. In dry-run mode, validate organization membership without Slack or billing writes.
6. In live mode, add `:eyes:`, validate membership, assign the seat, replace
   `:eyes:` with `:github-approved:`, and reply `Invite sent`.
7. For non-members, reply with the approved Relias-Engineering SSO onboarding steps.
8. Post success, rejection, and first-attempt failure receipts to
   `#prod-eng-devex-automation`.
9. Leave transient failures pending for a later retry.

## Safety

- Default mode is `DryRun`.
- Slack writes and Copilot seat assignments require `Live` mode.
- Live mode requires:

```powershell
.\scripts\Set-CopilotLicenseProcessorMode.ps1 -Mode Live -ConfirmLive
```

- On Windows, the Slack token is stored outside the repository using
  user-scoped DPAPI encryption.
- On Linux, `GH_TOKEN` and `SLACK_TOKEN` are read from a mode-600 credentials
  file outside the repository and cleared from the runner environment on exit.
- The scheduled task only runs while the current Windows user is logged on.

## Schedule

Task: `\HemSoft\GitHub Copilot License Processor`

- Every 5 minutes
- Monday-Friday
- 8:00 AM-6:00 PM Eastern Time

The Windows trigger repeats daily; the processor enforces the weekday and
business-hours restriction before calling Slack.

On Mini, `copilot-license-processor.timer` runs the processor every five
minutes as a persistent systemd user timer. The service starts
`scripts/Run-CopilotLicenseProcessorLinux.ps1`, which reads
`~/.config/github-copilot-license-processor/credentials.json`. User lingering
keeps the timer active while Franz is logged out.

## History

After using this skill, append `## HH:MM - {Action Taken}` plus a one-line
summary to `History/{YYYY-MM-DD}.md` in this skill folder, noting whether a
retrospective check found a reusable improvement. Take the timestamp from the
shell (`Get-Date -Format "HH:mm"` on Windows, `date +%H:%M` elsewhere), never
an estimate.
