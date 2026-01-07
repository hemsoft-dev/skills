---
name: steam
description: V1.0 - Expert in Steam game locations, mod installation, library management, and common game paths on Windows.
---

# Steam

Manage Steam installations, find game folders, and install mods on Windows.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Steam Installation Paths

### Registry Lookup (Authoritative)
```powershell
(Get-ItemProperty -Path "HKCU:\Software\Valve\Steam").SteamPath
```
Default: `C:\Program Files (x86)\Steam`

### Game Installation Path
```
{SteamPath}\steamapps\common\{GameName}
```

### Library Folders Config
```
{SteamPath}\steamapps\libraryfolders.vdf
```
Parse this file for additional Steam library locations on other drives.

## Common Game Folder Names

| Game | Folder Name |
|------|-------------|
| 7 Days to Die | `7 Days To Die` |
| Valheim | `Valheim` |
| Factorio | `Factorio` |
| Satisfactory | `Satisfactory` |
| Terraria | `Terraria` |
| Rimworld | `RimWorld` |
| Stardew Valley | `Stardew Valley` |

## Mod Installation

### Standard Mods Folder
Most Unity-based games use:
```
{GamePath}\Mods\{ModName}\
```

### 7 Days to Die Mods
```
C:\Program Files (x86)\Steam\steamapps\common\7 Days To Die\Mods\
```
Structure:
```
Mods\
└── {ModName}\
    ├── ModInfo.xml
    └── (mod files)
```

### BepInEx Mods (Many Unity Games)
```
{GamePath}\BepInEx\plugins\{ModName}\
```

## Useful Commands

### Find Game Path
```powershell
$steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam").SteamPath -replace '/', '\'
$gamePath = Join-Path $steamPath "steamapps\common\{GameName}"
if (Test-Path $gamePath) { explorer $gamePath }
```

### List All Installed Games
```powershell
$steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam").SteamPath -replace '/', '\'
Get-ChildItem (Join-Path $steamPath "steamapps\common") -Directory | Select-Object Name
```

### Open Game Folder in Explorer
```powershell
explorer "C:\Program Files (x86)\Steam\steamapps\common\{GameName}"
```

## Save Data Locations

| Location | Path |
|----------|------|
| Steam Cloud | `{SteamPath}\userdata\{SteamID}\{AppID}\` |
| AppData Local | `%LOCALAPPDATA%\{GameName}\` |
| AppData Roaming | `%APPDATA%\{GameName}\` |
| Documents | `%USERPROFILE%\Documents\My Games\{GameName}\` |

## Steam App IDs (Common)

| Game | App ID |
|------|--------|
| 7 Days to Die | 251570 |
| Valheim | 892970 |
| Factorio | 427520 |
| Satisfactory | 526870 |
| Terraria | 105600 |
| RimWorld | 294100 |
| Stardew Valley | 413150 |
