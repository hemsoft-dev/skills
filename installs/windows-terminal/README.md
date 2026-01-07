# Windows Terminal

## Backup

```powershell
.\Backup-WindowsTerminal.ps1
```

## Restore

```powershell
$wtDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
Copy-Item "settings.json" $wtDir -Force
```

## Files

| File | Description |
|------|-------------|
| `settings.json` | Windows Terminal settings (profiles, colors, fonts, etc.) |
