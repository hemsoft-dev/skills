---
name: autohotkey
description: V1.2 - Expert in AutoHotkey v2 scripting for hotkeys, hotstrings (text expansion), automation, GUIs, and Windows integration. Use for creating, editing, or troubleshooting AHK scripts.
---

# AutoHotkey Expert

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert-level guidance for AutoHotkey v2 scripting.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Environment

- **Version**: AutoHotkey v2.0
- **Installation**: `C:\Program Files\AutoHotkey\v2\`
- **User Script**: `C:\Users\User\Documents\AutoHotkey.ahk`
- **Help File**: `C:\Program Files\AutoHotkey\v2\AutoHotkey.chm`
- **Window Spy**: `C:\Program Files\AutoHotkey\WindowSpy.ahk`

## v2 Syntax Essentials

### Script Header

```autohotkey
#Requires AutoHotkey v2.0
#SingleInstance Force
```

### Modifier Keys

| Symbol | Key |
|--------|-----|
| `^` | CTRL |
| `+` | SHIFT |
| `!` | ALT |
| `#` | WIN |

### Hotkey Syntax (v2)

```autohotkey
; Simple hotkey
^+x:: MsgBox("Hello")

; Multi-line hotkey (requires braces)
^+x:: {
    MsgBox("Line 1")
    Run("notepad.exe")
}
```

### Common Patterns

**Run Application:**

```autohotkey
^+n:: Run("notepad.exe")
```

**Activate or Launch:**

```autohotkey
^+t:: {
    if WinExist("ahk_exe app.exe") {
        WinActivate
    } else {
        Run("C:\Path\To\app.exe")
    }
}
```

**Send Text/Keys:**

```autohotkey
::btw::by the way  ; Hotstring
^+d:: Send(FormatTime(, "yyyy-MM-dd"))  ; Date stamp
```

### Hotstrings (Text Expansion)

Hotstrings automatically replace typed text with expanded content. Type the trigger text followed by a space, tab, or Enter to activate.

**Basic Syntax:**

```autohotkey
; Single-line hotstring
::btw::by the way

; Multi-line hotstring (using continuation section)
::agp::
(
# Purpose
qqq

## Variables
qqq

## Codebase Structure
qqq

## Instructions
qqq

## Workflow
qqq

## Report
qqq
)
```

**Hotstring Options:**

```autohotkey
:*:btw::by the way        ; * = immediate (no ending character needed)
:O:btw::by the way        ; O = omit ending character
:C:btw::by the way        ; C = case-sensitive
:R:btw::by the way        ; R = raw mode (no special character processing)
:B0:btw::by the way       ; B0 = no backspace (don't delete trigger text)
```

**Common Use Cases:**

```autohotkey
; Date expansion
::date:: Send(FormatTime(, "yyyy-MM-dd"))

; Email signature
::sig::
(
Best regards,
Your Name
)

; Code snippets
::tryc::
(
try {
    
} catch {
    
}
)
```

**Run PowerShell Hidden:**

```autohotkey
^+p:: Run('powershell.exe -WindowStyle Hidden -Command "Get-Date"',, "Hide")
```

**Tooltip with Auto-Hide:**

```autohotkey
ShowTooltip(msg, duration := 1500) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -duration)
}
```

**GUI Input Box:**

```autohotkey
#Space:: {
    ib := InputBox("Enter command:", "Launcher")
    if ib.Result = "OK"
        ExecuteCommand(ib.Value)
}
```

### Window Management

**Identify Windows (use Window Spy):**

```autohotkey
; By executable
WinExist("ahk_exe chrome.exe")
; By class
WinExist("ahk_class Notepad")
; By title (partial match)
WinExist("Document -")
```

**Window Operations:**

```autohotkey
WinActivate("ahk_exe app.exe")
WinMinimize("ahk_exe app.exe")
WinMaximize("ahk_exe app.exe")
WinRestore("ahk_exe app.exe")
WinClose("ahk_exe app.exe")
WinGetMinMax("ahk_exe app.exe")  ; Returns: -1=minimized, 0=normal, 1=maximized
```

### Clipboard Operations

```autohotkey
; Get clipboard
text := A_Clipboard

; Set clipboard
A_Clipboard := "New text"

; Wait for clipboard
ClipWait(2)  ; Wait up to 2 seconds
```

### File Operations

```autohotkey
; Read file
content := FileRead("C:\path\file.txt")

; Write file
FileAppend("text", "C:\path\file.txt")

; Check existence
if FileExist("C:\path\file.txt")
    MsgBox("File exists")
```

### Script Control

```autohotkey
Reload  ; Reload script
Edit    ; Open script in editor
ExitApp ; Terminate script
Suspend ; Toggle hotkeys
Pause   ; Pause script
```

## v1 to v2 Migration Notes

| v1 | v2 |
|----|-----|
| `MsgBox, Text` | `MsgBox("Text")` |
| `Run, app.exe` | `Run("app.exe")` |
| `IfWinExist` | `if WinExist()` |
| `%var%` | `var` (direct) |
| `Label:` | `FunctionName() {` |
| Commands | Functions with `()` |

## Debugging

```autohotkey
; Show variable value
MsgBox(myVar)

; Output to debugger
OutputDebug("Value: " . myVar)

; List all hotkeys
ListHotkeys

; Show key history
KeyHistory
```

## Best Practices

1. **Always use** `#Requires AutoHotkey v2.0` at top
2. **Use** `#SingleInstance Force` to prevent duplicates
3. **Prefer** `ahk_exe` over window titles (more reliable)
4. **Test hotkeys** with simple `MsgBox` first
5. **Use Window Spy** to identify windows accurately
6. **Backup scripts** before major changes

## Operations

| Action | Command |
|--------|---------|
| Edit Script | `notepad "$env:USERPROFILE\Documents\AutoHotkey.ahk"` |
| Validate Script (before reload!) | `$p = Start-Process "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList '/ErrorStdOut','/validate','"$env:USERPROFILE\Documents\AutoHotkey.ahk"' -Wait -PassThru -NoNewWindow; $p.ExitCode` (0 = OK; catches syntax + duplicate hotkeys; plain `&` won't set `$LASTEXITCODE` — GUI exe) |
| Reload Script | `Get-Process AutoHotkey64_UIA -EA SilentlyContinue \| Stop-Process -Force; Start-Process "C:\Program Files\AutoHotkey\v2\AutoHotkey64_UIA.exe" -ArgumentList "`"$env:USERPROFILE\Documents\AutoHotkey.ahk`""` — the script runs under the **UIA** exe; plain `Start-Process script.ahk` launches a normal-privilege instance that UIPI blocks from replacing the UIA one, so it dies silently and the old code keeps running. ALWAYS verify reload took: `Get-Process AutoHotkey* \| Select StartTime` must be newer than the script's LastWriteTime. (Manual alternative: Ctrl+Shift+R reloads in-place.) |
| Open Help | `Start-Process "C:\Program Files\AutoHotkey\v2\AutoHotkey.chm"` |
| Window Spy | `Start-Process "C:\Program Files\AutoHotkey\WindowSpy.ahk"` |

## Common Troubleshooting

- **Hotkey not working**: Check for conflicts, verify syntax, run as admin if needed
- **Window not found**: Use Window Spy to get exact `ahk_exe` or `ahk_class`
- **Script errors**: Check v1 vs v2 syntax (functions need parentheses in v2)
- **UAC issues**: Some apps require AHK to run elevated
