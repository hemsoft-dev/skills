---
name: shortcuts
description: V1.5 - Manages AutoHotkey keyboard shortcuts and text expansion hotstrings for launching tools, utilities, and processes. Use when adding, editing, listing, or removing shortcuts.
---

# Shortcuts Manager

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Manage keyboard shortcuts via AutoHotkey v2.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Configuration

- **Script Location**: `C:\Users\User\Documents\AutoHotkey.ahk`
- **Startup Shortcut**: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\AutoHotkey.lnk` (points directly to .ahk file - Windows Explorer handles the file association)
- **AHK Version**: v2.0
- **Scripts Folder**: `~\.claude\skills\shortcuts\scripts\`

> **Important:** The startup shortcut must point directly to the `.ahk` file, NOT to the AutoHotkey executable with the script as an argument. Explorer handles the file association correctly and ensures proper environment inheritance.

> **Important:** All supporting scripts (PowerShell, batch files, etc.) used by shortcuts must be placed in this skill's `scripts/` subfolder—not in Documents or other locations. This keeps related files together and makes the skill portable.

## Current Shortcuts

### Direct Hotkeys (CTRL+SHIFT+key)

| Shortcut | Key | Action |
|----------|-----|--------|
| CTRL+SHIFT+/ | `^+/` | Insert date stamp (YYYY-MM-DD - ) |
| CTRL+SHIFT+E | `^+e` | Edit AutoHotkey.ahk in default editor |
| CTRL+SHIFT+R | `^+r` | Reload AHK script |
| CTRL+SHIFT+G | `^+g` | Activate/launch Claude |
| CTRL+SHIFT+N | `^+n` | Activate/launch Obsidian Notes |
| CTRL+SHIFT+T | `^+t` | Activate/launch Todoist |
| CTRL+SHIFT+X | `^+x` | Activate/launch X (Twitter) |
| CTRL+SHIFT+C | `^+c` | Activate/launch WezTerm |
| CTRL+SHIFT+V | `^+v` | Activate/launch VS Code Insiders |
| CTRL+SHIFT+S | `^+s` | Activate/launch VS Code Insiders with Skills repo |
| CTRL+ALT+P | `^!p` | Speak clipboard (TTS via edge-tts) |
| CTRL+ALT+LEFT | `^!Left` | Move to previous Windows Desktop |
| CTRL+ALT+RIGHT | `^!Right` | Move to next Windows Desktop |
| CTRL+ALT+NUMPAD-ENTER | `^!NumpadEnter` | Windows Desktop Overview (Task View) |
| CTRL+ALT+NUMPAD0-9 | `^!Numpad0` - `^!Numpad9` | Switch directly to Desktop 1-10 |

### Command Launcher (WIN+Space)

Press `WIN+Space` to open GUI prompt, type code, press Enter.

| Code | Action |
|------|--------|
| `100` | Run `cm` PowerShell script (`f:\github\HemSoft\cli-tools\scripts\cm.ps1`, copies output to clipboard) |
| `101` | Activate/launch VS Code Insiders |
| `102` | Activate/launch WezTerm |
| `103` | Paint (mspaint) |

### Text Expansion Hotstrings

Type the trigger text followed by a space, tab, or Enter to expand.

| Trigger | Expansion |
|---------|-----------|
| `agp` | Markdown template with Purpose, Variables, Codebase Structure, Instructions, Workflow, and Report sections |

## AHK v2 Reference

### Modifier Keys

- `^` = CTRL, `+` = SHIFT, `!` = ALT, `#` = WIN

### Patterns

**Simple launcher:**

```autohotkey
^+x:: {
    Run "app.exe"
}
```

**Activate or launch:**

```autohotkey
^+x:: {
    if WinExist("ahk_exe app.exe") {
        if WinGetMinMax("ahk_exe app.exe") = -1
            WinRestore
        WinActivate
    } else {
        Run "path\to\app.exe"
    }
}
```

**Run PowerShell silently (for commands that copy to clipboard):**

```autohotkey
case "100":
    Run('powershell.exe -WindowStyle Hidden -Command "cm"', , "Hide")
    ToolTip("Done!"), SetTimer(() => ToolTip(), -1500)
```

## Operations

- **Add**: Edit `ExecuteCommand()` switch or add hotkey block
- **Remove**: Delete the case/hotkey block
- **Reload**: `explorer.exe "C:\Users\User\Documents\AutoHotkey.ahk"` (or press CTRL+SHIFT+R while AHK is running)

## System Hotkey Overrides (Registry)

### Print Screen (Snagit vs Snipping Tool)

To allow Snagit to use the **Print Screen** key without interference from the built-in Windows Snipping Tool:

1. **Disable Snipping Tool Shortcut**:
    - Path: `HKCU:\Control Panel\Keyboard`
    - Value: `PrintScreenKeyForSnippingEnabled` (DWORD) = `0`
2. **Enable Snagit Takeover**:
    - Path: `HKCU:\Software\TechSmith\Snagit\25`
    - Value: `OpenSystemScreenShotsInSnagit` (DWORD) = `1`
    - Value: `AllowOverrideHotkeyAssignments` (DWORD) = `1`
3. **Force Snagit Hotkey (Print Screen)**:
    - Path: `HKCU:\Software\TechSmith\Snagit\25\Profiles\<Untitled>`
    - Value: `SnagKey` (DWORD) = `44` (Virtual Key Code for Print Screen)
4. **Set Snagit to Image Mode (Skip All-in-One)**:
    - Path: `HKCU:\Software\TechSmith\Snagit\25\Profiles\<Untitled>`
    - Value: `Mode` (DWORD) = `1` (0 = All-in-One, 1 = Image, 2 = Video)

**Note**: Conflicts may still occur if **OneDrive** has "Save screenshots I capture to OneDrive" enabled in its Sync and Backup settings.
