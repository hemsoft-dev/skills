# PowerShell Profiles

## Backup

```powershell
.\Backup-PowerShellProfiles.ps1
```

## Restore

```powershell
# Ensure directory exists
$profileDir = Split-Path $PROFILE
if (-not (Test-Path $profileDir)) { New-Item $profileDir -ItemType Directory -Force }

# Copy profiles
Copy-Item "Microsoft.PowerShell_profile.ps1" $PROFILE.CurrentUserCurrentHost -Force
Copy-Item "profile.ps1" $PROFILE.CurrentUserAllHosts -Force

# Restore Oh-My-Posh themes (if present)
if (Test-Path "omp") {
    $ompDir = "$env:USERPROFILE\.config\omp"
    if (-not (Test-Path $ompDir)) { New-Item $ompDir -ItemType Directory -Force }
    Copy-Item "omp\*" $ompDir -Force
}
```

## Files

| File | Description |
|------|-------------|
| `Microsoft.PowerShell_profile.ps1` | Current user, current host profile |
| `profile.ps1` | Current user, all hosts profile |
| `omp/*.json` | Oh-My-Posh theme files |
