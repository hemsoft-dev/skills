# Git Configuration

## Backup

```powershell
# Backup config and public keys only (safe)
.\Backup-GitConfig.ps1

# Include private keys (use with caution!)
.\Backup-GitConfig.ps1 -IncludePrivateKeys
```

## Restore

```powershell
# Copy .gitconfig
Copy-Item ".gitconfig" "$env:USERPROFILE\.gitconfig"

# Copy SSH files
Copy-Item "ssh\*" "$env:USERPROFILE\.ssh\" -Force
```

## Files

| File | Description |
|------|-------------|
| `.gitconfig` | Global git configuration |
| `ssh/config` | SSH host configurations |
| `ssh/*.pub` | Public keys |
| `ssh/known_hosts` | Known SSH hosts |
