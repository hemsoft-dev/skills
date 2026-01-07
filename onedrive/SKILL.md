---
name: onedrive
description: V1.0 - Manages OneDrive folder locations, eliminates redundant sync folders, and ensures consistent syncing to a single primary location.
---

# OneDrive Manager

Expert in managing OneDrive installation, detecting redundant folders, and ensuring consistent syncing to your primary location.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Primary Configuration

**User's Primary Location**: `D:\OneDrive`

All OneDrive syncing should be directed to this location. Any other OneDrive folders are considered redundant.

## Core Functions

### 1. Detect OneDrive Locations
Find all OneDrive folders on the system:

```powershell
# Check registry for OneDrive paths
Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -Name "UserFolder" -ErrorAction SilentlyContinue | Select-Object UserFolder

# Check common locations
$commonPaths = @(
    "$env:USERPROFILE\OneDrive",
    "C:\Users\$env:USERNAME\OneDrive",
    "D:\OneDrive",
    "$env:OneDrive"
)
$commonPaths | Where-Object { Test-Path $_ } | ForEach-Object { Get-Item $_ | Select-Object FullName, LastWriteTime }

# Check environment variables
Get-ChildItem env: | Where-Object Name -like "*OneDrive*"
```

### 2. Verify Primary Location
Ensure `D:\OneDrive` is the active sync folder:

```powershell
# Check OneDrive process and its working directory
Get-Process OneDrive -ErrorAction SilentlyContinue | Select-Object Path, Id

# Verify registry points to D:\OneDrive
$oneDriveSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue
$oneDriveSettings | Select-Object UserFolder, DisplayName
```

### 3. Identify Redundant Folders
List any OneDrive folders that are NOT `D:\OneDrive`:

- Check for `C:\Users\{username}\OneDrive`
- Check for multiple OneDrive account folders
- Identify old/orphaned OneDrive folders (no recent activity)

**Report Format**:
```
✅ Active: D:\OneDrive (last synced: {datetime})
⚠️  Found: C:\Users\User\OneDrive (potential duplicate)
❌ Orphaned: {path} (last modified: {datetime})
```

### 4. Sync Health Check
Verify OneDrive is running and syncing properly:

```powershell
# Check OneDrive process status
$oneDrive = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($oneDrive) {
    Write-Host "✅ OneDrive is running (PID: $($oneDrive.Id))"
} else {
    Write-Host "❌ OneDrive is not running"
}

# Check for sync errors (look for icon overlay handlers)
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ShellIconOverlayIdentifiers\*" | 
    Where-Object { $_.'(default)' -like "*OneDrive*" }
```

### 5. Cleanup Guidance
When redundant folders are found:

1. **Verify D:\OneDrive is current**:
   - Check last modified dates
   - Confirm files are syncing
   
2. **Before removing redundant folders**:
   - Compare file counts: `(Get-ChildItem -Recurse -File).Count`
   - Check for unique files not in D:\OneDrive
   - Create backup if uncertain

3. **Unlink/Remove process**:
   ```powershell
   # Stop OneDrive
   Stop-Process -Name OneDrive -Force
   
   # Unlink account (if needed - use OneDrive settings UI)
   Start-Process "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" -ArgumentList "/unlink"
   
   # After verification, remove old folder
   # Remove-Item "C:\Users\User\OneDrive" -Recurse -Force
   ```

### 6. Set Primary Location
If OneDrive needs to be relocated to D:\OneDrive:

```powershell
# Stop OneDrive
Stop-Process -Name OneDrive -Force

# Start OneDrive setup to choose location
Start-Process "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" -ArgumentList "/reset"

# User will need to sign in and select D:\OneDrive as the folder location
```

## Sync Monitoring & Troubleshooting

### Common Issues with Large File Collections (1M+ files)

**Performance Optimization:**
- Enable **Files On-Demand** to reduce local storage footprint
- Monitor disk I/O during heavy sync operations
- Consider selective sync for rarely accessed folders
- Ensure adequate free disk space (minimum 50 GB recommended)

**Sync Status Indicators:**
- **Last Sync Time**: Check `HKCU:\Software\Microsoft\OneDrive\Accounts\*\LastUpdateTime`
- **Error Codes**: Check `HKCU:\Software\Microsoft\OneDrive\Accounts\*\LastError`
- **Files On-Demand**: `HKCU:\Software\Microsoft\OneDrive\FilesOnDemandEnabled`

### Monitoring Sync Backlog

For large collections, track:
1. **Cloud-only files**: Files not yet downloaded (ReparsePoint attribute)
2. **Local files**: Fully synced and available offline
3. **Sync percentage**: `(Local Files / Total Files) * 100`

### Troubleshooting Steps

1. **OneDrive Not Syncing**:
   ```powershell
   # Check process
   Get-Process OneDrive
   
   # Restart OneDrive
   Stop-Process -Name OneDrive -Force
   Start-Process "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
   ```

2. **Check for Errors**:
   ```powershell
   Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\*" -Name "LastError"
   ```
   Reference: [OneDrive Error Codes](https://support.microsoft.com/en-us/office/what-do-the-onedrive-error-codes-mean-f7a68338-e540-4ebf-ad5d-56c5633acded)

3. **Reset OneDrive** (last resort):
   ```powershell
   & "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" /reset
   Start-Sleep -Seconds 10
   Start-Process "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
   ```

### Performance Tips for 1M+ Files

- **Disk Space**: Keep at least 10% free (minimum 50 GB for large collections)
- **Files On-Demand**: Essential for managing storage with massive file counts
- **Network**: Ensure stable connection to avoid sync interruptions
- **Exclusions**: Exclude temp folders, build outputs, node_modules from sync
- **Monitoring**: Use `Get-OneDriveSyncStatus.ps1` regularly to track sync health

## Key Takeaways from Real-World Usage

### Deletion Syncing (Verified Jan 2026)
**Finding**: OneDrive syncs file deletions **extremely fast** - often appearing as instant
- **Why**: OneDrive uses Windows Push Notification Services (WNS) for real-time sync
- **Metadata changes** (rename, delete) happen **immediately** - no large data transfer required
- **Observation**: Deleting 580,000+ files synced to cloud in seconds, showing "Your files are synced" immediately
- **Reference**: [Microsoft Learn - How Sync Works](https://learn.microsoft.com/en-us/onedrive/sync-process)

### Understanding Sync States (Common Confusion)
Users often misunderstand OneDrive file states:
- **"Cloud-only" does NOT mean "not synced"** - it means the file IS in the cloud but not downloaded locally
- **ALL files in OneDrive folder are synced to the cloud** - regardless of local download status
- **Two states exist**:
  1. Synced + Downloaded locally (taking disk space)
  2. Synced + Cloud-only (placeholder, saves disk space)
- Files On-Demand can be "disabled" in settings but still work for some files (previous settings persist)

### Large File Collection Management (1M+ files)
**Tested with 1,049,215 files:**
- Initial state: ~1M files, ~94% locally downloaded, ~58K cloud-only
- **Major cleanup**: Removed 580K files from two large folders (Backup, Bitbucket)
- **Result**: Reduced to ~470K files, dramatic performance improvement
- **Key insight**: Development folders (Git repos, backups) should NOT be in OneDrive
  - Source control (Git) already handles versioning
  - Massive file counts slow sync unnecessarily
  - Better stored outside OneDrive on local drive

### Folder Analysis Efficiency
When analyzing large OneDrive folders:
- Recursive file counts are **slow** with 1M+ files (several minutes per folder)
- Use targeted analysis: scan top-level folders individually
- Identify largest folders first, then decide what to keep
- Use `-ErrorAction SilentlyContinue` to handle access denied errors

### Best Practices Confirmed
1. **One primary OneDrive location** - multiple sync folders cause confusion
2. **Files On-Demand is essential** for large collections (1M+ files)
3. **Regular cleanup** - analyze and remove unnecessary folders
4. **Exclude development folders** - Git repos, node_modules, build outputs
5. **Monitor disk space** - keep minimum 50GB free for large collections
6. **Restart OneDrive after major changes** - triggers re-scan and sync

## Safety Rules

1. **Never delete folders without user confirmation**
2. **Always verify D:\OneDrive has the latest files**
3. **Create backups before major changes**
4. **Check file counts and dates before cleanup**
5. **Monitor sync status after changes**
6. **Ensure adequate disk space before major sync operations**
7. **Deletions sync immediately** - once deleted locally, cloud deletion begins instantly

## PowerShell Scripts

Reusable scripts are located in `Scripts/` subfolder:

### Invoke-OneDriveAudit.ps1
Comprehensive audit of OneDrive status, locations, and configuration.

```powershell
~/.claude/skills/onedrive/Scripts/Invoke-OneDriveAudit.ps1 -PrimaryLocation "D:\OneDrive"
```

### Get-OneDriveSyncStatus.ps1
**NEW** - Monitor sync status, detect backlog, and analyze sync progress (optimized for 1M+ files).

```powershell
# Basic status check
~/.claude/skills/onedrive/Scripts/Get-OneDriveSyncStatus.ps1 -OneDrivePath "D:\OneDrive"

# Include backlog analysis (may take time with 1M+ files)
~/.claude/skills/onedrive/Scripts/Get-OneDriveSyncStatus.ps1 -OneDrivePath "D:\OneDrive" -IncludeBacklog

# Detailed registry information
~/.claude/skills/onedrive/Scripts/Get-OneDriveSyncStatus.ps1 -OneDrivePath "D:\OneDrive" -Detailed
```

### Test-OneDriveHealth.ps1
**NEW** - Comprehensive health check with automatic issue detection and optional auto-fix.

```powershell
# Run health check
~/.claude/skills/onedrive/Scripts/Test-OneDriveHealth.ps1 -PrimaryLocation "D:\OneDrive"

# Run health check and auto-fix issues
~/.claude/skills/onedrive/Scripts/Test-OneDriveHealth.ps1 -PrimaryLocation "D:\OneDrive" -FixIssues
```

### Remove-RedundantOneDrive.ps1
Safely removes redundant OneDrive folders with verification.

```powershell
~/.claude/skills/onedrive/Scripts/Remove-RedundantOneDrive.ps1 -Path "C:\Users\User\OneDrive" -PrimaryLocation "D:\OneDrive"
```

Add `-Force` to skip confirmation for empty folders.

### Start-OneDriveProcess.ps1
Starts OneDrive and verifies it's running.

```powershell
~/.claude/skills/onedrive/Scripts/Start-OneDriveProcess.ps1
```

### Get-OneDriveLocations.ps1
Returns all OneDrive folder locations found on the system.

```powershell
# Basic filesystem check
~/.claude/skills/onedrive/Scripts/Get-OneDriveLocations.ps1

# Include registry and environment variables
~/.claude/skills/onedrive/Scripts/Get-OneDriveLocations.ps1 -IncludeRegistry -IncludeEnvironment
```
