---
name: github-copilot-license-processor
description: "V1.5 - Commands: Process, Status, Install, SetMode. Polls Slack for Relias GitHub Copilot license requests, validates organization membership, safely assigns seats, and posts audit receipts."
compatibility: Requires PowerShell 7, GitHub CLI authentication, Slack bot access, and Windows Task Scheduler
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the
            github-copilot-license-processor directory, verify that
            History/{YYYY-MM-DD}.md contains an accurate timestamped entry.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            If github-copilot-license-processor was used, verify that today's
            History file contains an accurate timestamped summary and that a
            brief retrospective check was performed.
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

- The Slack token is stored outside the repository using Windows user-scoped
  DPAPI encryption.
- The scheduled task only runs while the current Windows user is logged on.

## Schedule

Task: `\HemSoft\GitHub Copilot License Processor`

- Every 5 minutes
- Monday-Friday
- 8:00 AM-6:00 PM Eastern Time

The Windows trigger repeats daily; the processor enforces the weekday and
business-hours restriction before calling Slack.
