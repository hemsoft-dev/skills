# VS Code Insiders

## Backup

```powershell
.\Backup-VSCodeInsiders.ps1
```

## Restore

```powershell
# Copy settings
$vscodeDir = "$env:APPDATA\Code - Insiders\User"
Copy-Item "settings.json" $vscodeDir -Force
Copy-Item "keybindings.json" $vscodeDir -Force -ErrorAction SilentlyContinue

# Install extensions
Get-Content "extensions.txt" | ForEach-Object {
    code-insiders --install-extension $_
}
```

## Files

| File | Description |
|------|-------------|
| `settings.json` | User settings |
| `keybindings.json` | Custom keyboard shortcuts |
| `extensions.txt` | List of installed extensions |
