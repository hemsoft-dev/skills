# Directory Opus Configuration

## Backup Location

Configuration backups are stored as `.ocb` files (Opus Configuration Backup).

**Default config location:** `%APPDATA%\GPSoftware\Directory Opus`

## Backup (Automated)

```powershell
# Run from this directory (Directory Opus must be running)
.\Backup-DOpusConfig.ps1

# Custom backup name
.\Backup-DOpusConfig.ps1 -Name "my-backup"

# Include window positions (machine-specific)
.\Backup-DOpusConfig.ps1 -IncludeLocalState
```

The script runs silently using `dopusrt.exe` - no dialogs or user interaction required.

## Restore

1. Open Directory Opus
2. Go to **Settings → Backup & Restore**
3. Select **Restore configuration**
4. Browse to the `.ocb` file
5. Enable **Replace existing configuration completely**

## Key Settings Configured

- **Auto-size columns disabled** - Name column stays fixed width when changing folders
- Column layout preserved via folder format settings
- Custom toolbar configurations
- File type associations and context menus

## Files

| File | Description |
|------|-------------|
| `Backup-DOpusConfig.ps1` | PowerShell script for silent backup |
| `dopus-config.ocb` | Full configuration backup |
