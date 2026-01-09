---
name: backup
description: V1.0 - Backs up user profile folders, dev caches, and configurations to F:\OneDrive\User-Backup with incremental and full backup options.
---

# Backup

Back up important user data from `C:\Users\franz` to `F:\OneDrive\User-Backup`.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Backup Target

**Destination**: `F:\OneDrive\User-Backup`

## Quick Commands

### Full Backup (default folders)

```powershell
& "$env:USERPROFILE\.claude\skills\backup\scripts\Backup-UserProfile.ps1"
```

### Backup Specific Folders

```powershell
& "$env:USERPROFILE\.claude\skills\backup\scripts\Backup-UserProfile.ps1" -Folders ".claude",".ssh",".gitconfig"
```

### List What Would Be Backed Up (dry run)

```powershell
& "$env:USERPROFILE\.claude\skills\backup\scripts\Backup-UserProfile.ps1" -WhatIf
```

### Restore

```powershell
& "$env:USERPROFILE\.claude\skills\backup\scripts\Restore-UserProfile.ps1" -BackupDate "2025-12-25"
```

## Default Backup Targets

| Category | Folders |
|----------|---------|
| **Dev Config** | `.claude`, `.ssh`, `.gitconfig`, `.npmrc`, `.cargo` |
| **IDE Settings** | `.vscode`, `.vscode-insiders`, `AppData\Roaming\Code - Insiders\User` |
| **Shell Config** | `Documents\PowerShell`, `.config` |
| **Important Data** | `Documents`, `Desktop`, `Pictures` |

## Exclusions (not backed up by default)

- `.cache` (re-downloadable)
- `.nuget`, `npm-cache`, `pip` (package caches)
- `.ollama`, `.lmstudio` (large models)
- `AppData\Local\Temp`
- `node_modules`, `bin`, `obj` folders
