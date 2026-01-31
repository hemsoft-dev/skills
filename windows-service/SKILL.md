---
name: windows-service
description: V1.0 - Manages Windows Services including creation, registration, monitoring, and lifecycle control for background applications.
license: Apache-2.0
compatibility: Windows PowerShell 5.1+, requires admin privileges for service management
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the windows-service directory (path contains 'windows-service'), verify that history logging occurred.
            
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
            Before stopping, if windows-service skill was used (check if any files in windows-service directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in windows-service directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
---

# Windows Service Skill

Expert guidance for managing Windows Services on this PC. Handles service creation, configuration, lifecycle management, and troubleshooting.

## Services Managed

### HemSoft-Conductor-Server

**Purpose**: Monitoring and auto-restarting the hs-conductor backend services (backend server + Inngest dev server) to ensure continuous operation of scheduled tasks.

**Location**: `d:\github\HemSoft\hs-conductor`

**Configuration**:

- Task Name: `HemSoft-Conductor-Server`
- Task Type: Scheduled Task (runs at startup, continuous)
- Description: `Monitors and maintains hs-conductor backend services (Backend Server + Inngest)`
- Startup Type: Automatic (on Windows boot)
- Run As: Current user (for access to PATH, Bun, npm, etc.)

**What It Monitors**:

1. Backend server (port 2900) - runs via `bun run --watch src/index.ts`
2. Inngest dev server (port 2901) - runs via `npx inngest-cli@latest dev`

**Behavior**:

- Checks every 60 seconds if both services are running
- Auto-restarts any crashed process immediately (after 2 consecutive failures)
- Logs all events to `~/.claude/skills/logs/hs-conductor/`
- Triggers alerts on repeated failures via alerts skill
- Auto-restarts itself on failure (3 attempts, 1 min interval)

**Log Location**: `~/.claude/skills/logs/hs-conductor/`

**Script Location**: `~/.claude/skills/windows-service/scripts/hs-conductor-service-worker.ps1`

## Common Operations

### Check Task Status

```powershell
Get-ScheduledTask -TaskName "HemSoft-Conductor-Server" | Select TaskName, State, LastRunTime
```

### Start Task

```powershell
Start-ScheduledTask -TaskName "HemSoft-Conductor-Server"
```

### Stop Task

```powershell
Stop-ScheduledTask -TaskName "HemSoft-Conductor-Server"
```

### Restart Task (after code changes)

```powershell
# From repo root (requires admin)
.\update-service.ps1
```

### View Logs

```powershell
Get-Content "c:\Users\User\.claude\skills\logs\hs-conductor\$(Get-Date -Format 'yyyy-MM-dd').json" | ConvertFrom-Json | Format-Table -AutoSize
```

### Open Task Scheduler GUI

```powershell
taskschd.msc
```

## Installation

Use `setup-service.ps1` script to register the Scheduled Task. Must be run with administrator privileges.

## Updating After Code Changes

**TypeScript/JavaScript changes** (`src/**/*.ts`):

- ✅ Automatically picked up by Bun's `--watch` mode
- ✅ No restart needed

**Monitoring script changes** (`~/.claude/skills/windows-service/scripts/hs-conductor-service-worker.ps1`):

- ⚠️ Requires task restart
- Run `.\update-service.ps1` (as admin)

**Schedule file changes** (`data/schedules/*.json`):

- ✅ Automatically picked up on next scheduler tick (within 60 seconds)
- ✅ No restart needed

**Workload file changes** (`workloads/**/*.yaml`):

- ✅ Automatically picked up when workload is triggered
- ✅ No restart needed

## Troubleshooting

- **Service won't start**: Check event log and logs skill for details
- **Processes restarting frequently**: Check `~/.claude/skills/logs/hs-conductor/` for error patterns
- **Port conflicts**: Verify ports 2900, 2901 are not in use by other services
