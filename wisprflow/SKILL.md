---
name: wisprflow
description: "V1.0 - Commands: diagnose, restart, fix-shortcut, status. Troubleshooting guide for Wispr Flow voice dictation app on Windows. Use when Wispr Flow hotkey stops working, indicator disappears, or keyboard hook breaks after sleep/wake."
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the wisprflow directory (path contains 'wisprflow'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if wisprflow was used (check if any files in wisprflow directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in wisprflow directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
---

# Wispr Flow Troubleshooting

Voice dictation app (Electron-based) with a native keyboard hook helper process.

## Architecture

- **Main app**: `Wispr Flow.exe` — Electron app with multiple renderer processes (Hub Window, Status Window, Context Menu)
- **Helper**: `Wispr Flow Helper.exe` — Native binary at `resources\Release\` that owns the WH_KEYBOARD_LL keyboard hook
- **Config**: `%APPDATA%\Wispr Flow\config.json` (55KB, complex JSON)
- **Logs**: `%APPDATA%\Wispr Flow\logs\` — `accessibility.log` (hook events), `main.log` (app lifecycle)
- **Install**: `%LOCALAPPDATA%\WisprFlow\app-{version}\`
- **IPC**: Helper communicates key events to Electron main process via IPC

## Key Codes (VK codes used in config)

| Code | Key | Code | Key |
|------|-----|------|-----|
| 20 | CapsLock | 160 | LShift |
| 27 | Escape | 162 | LCtrl |
| 32 | Space | 163 | RCtrl |
| 91 | LWin | 164 | RAlt |

## Commands

### diagnose

Check Wispr Flow health:

```powershell
# 1. Check processes
Get-Process -Name "Wispr*" | Select-Object Id, ProcessName, StartTime

# 2. Check recent log activity
Get-Content "$env:APPDATA\Wispr Flow\logs\accessibility.log" -Tail 20

# 3. Check main.log for keyboard service
Get-Content "$env:APPDATA\Wispr Flow\logs\main.log" -Tail 30 | Select-String "Keyboard|key|shortcut|error"

# 4. Check current shortcut config
$raw = Get-Content "$env:APPDATA\Wispr Flow\config.json" -Raw
if ($raw -match '"shortcuts"\s*:\s*\{[^}]+\}') { $Matches[0] }
```

**Healthy indicators:**

- Helper process running
- `accessibility.log` shows "KeyboardService initialized!" and "Starting keyboard service"
- `main.log` shows "[Keyboard Service] Received first key event" shortly after start

**Unhealthy indicators:**

- "Removing stale keys from curKeysDown" with many keys — sleep/wake desync
- "Received release event for key that is not currently pressed" — hook state corrupted
- No key events logged after startup — hook is dead/broken

### restart

Full clean restart (kill all processes, relaunch):

```powershell
Get-Process -Name "Wispr*" | ForEach-Object { Stop-Process -Id $_.Id -Force }
Start-Sleep -Seconds 3
Start-Process "$env:LOCALAPPDATA\WisprFlow\Wispr Flow.exe"
Start-Sleep -Seconds 5
# Verify
Get-Process -Name "Wispr*" | Select-Object Id, ProcessName
Get-Content "$env:APPDATA\Wispr Flow\logs\accessibility.log" -Tail 5
```

**Important**: A respawned Helper (killed individually while main app stays alive) often has a DEAD hook. Always do a full kill-all restart.

### fix-shortcut

Edit the PTT shortcut directly in config.json (bypasses broken config UI):

```powershell
# Read config
$configPath = "$env:APPDATA\Wispr Flow\config.json"
$raw = Get-Content $configPath -Raw

# Change PTT shortcut from LCtrl+LWin to new combo
# Example: change to RCtrl (163)
$raw = $raw -replace '"162\+91":\s*"ptt"', '"163": "ptt"'

# Also update splitKeybinds array
# Find the ptt entry and replace shortcut array
$raw = $raw -replace '\{"shortcut":\s*\[162,91\],"value":"ptt"\}', '{"shortcut":[163],"value":"ptt"}'

# Write back
$raw | Set-Content $configPath -NoNewline

# Then do full restart (see restart command)
```

### status

Quick health check:

```powershell
$helper = Get-Process -Name "Wispr Flow Helper" -ErrorAction SilentlyContinue
$main = Get-Process -Name "Wispr Flow" -ErrorAction SilentlyContinue
Write-Host "Main processes: $($main.Count), Helper: $(if($helper){'Running'}else{'DEAD'})"
$lastLog = Get-Content "$env:APPDATA\Wispr Flow\logs\accessibility.log" -Tail 1
Write-Host "Last log: $lastLog"
```

## Known Issues & Root Causes

### 1. Sleep/Wake Keyboard Hook Desync (MOST COMMON)

**Symptoms**: Hotkey stops working after laptop sleep/wake. Indicator may disappear.

**Root cause**: The Helper's keyboard hook loses track of key states during sleep. On wake, it sees "release" events for keys it doesn't think are pressed, corrupting its internal state machine.

**Evidence in logs**:

```
[Info] - Removing stale keys from curKeysDown | staleKeys=175
[Info] - Received release event for key that is not currently pressed | key=162
```

**Fix**: Full restart (kill all Wispr processes, relaunch). A reboot always fixes this.

**Long-term mitigations**:

1. Scheduled task on wake event to restart Wispr Flow
2. AHK hotkey to restart Wispr Flow (Ctrl+Shift+W)
3. Report to Wispr support (they should handle wake events better)

### 2. Respawned Helper Has Dead Hook

**Symptoms**: After killing just the Helper (not the main app), it respawns but the keyboard hook doesn't receive any physical key events.

**Root cause**: The main Electron app respawns the Helper, but the new Helper's SetWindowsHookEx may fail silently or the hook doesn't process physical events (only injected/simulated events).

**Evidence**: `accessibility.log` shows initialization messages but ZERO key events from physical keypresses. Simulated keys (SendInput) may still work.

**Fix**: Kill ALL Wispr Flow processes and restart from scratch. Never kill just the Helper.

### 3. Windows Key (VK 91) Blocked by Shell

**Symptoms**: Shortcuts using LWin key don't fire. Other shortcuts (without Win) work fine.

**Root cause**: Windows 11 25H2 may process Win key at the shell/DWM level before it reaches user-mode WH_KEYBOARD_LL hooks. This can happen after certain Windows updates or policy changes.

**Fix**: Change shortcut to not use Win key. Edit config.json directly (see fix-shortcut command).

**Check if Win key is restricted**:

```powershell
# Check if Copilot/shell is eating Win key
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -ErrorAction SilentlyContinue
reg query "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableHotkeys 2>$null
```

### 4. Config UI Can't Capture Keys

**Symptoms**: In Wispr Flow settings, the shortcut recording dialog doesn't register ANY keyboard input. Mouse clicks (like middle-click) DO register.

**Root cause**: The config dialog relies on the Helper's IPC to receive key events. If the Helper's hook is broken (issue #2) or the IPC channel is stale, the dialog receives nothing. It's NOT a focus issue (mouse works proves the window is active).

**Fix**: Edit config.json directly (see fix-shortcut command). The config UI key capture is a known fragile path.

### 5. Third-Party Hook Interference

**Symptoms**: Hotkey stops working even with fresh restart.

**Common culprits** (check these processes):

- AutoHotkey — if it uses `#` (Win key) hotkeys
- Razer Synapse (RazerAppEngine) — keyboard macro hooks
- Logitech G Hub (lghub_agent) — key remapping hooks
- Corsair iCUE — keyboard profile hooks
- Elgato Stream Deck — hotkey registration
- M365Copilot.exe — may register Ctrl+Win combos
- PowerToys — keyboard manager remaps

**Diagnosis**: Kill suspected processes one by one and test.

## AHK Emergency Restart Hotkey

Add to `Documents\AutoHotkey.ahk`:

```autohotkey
; Wispr Flow Emergency Restart (Ctrl+Shift+W)
^+w:: {
    for proc in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Process WHERE Name LIKE 'Wispr%'")
        proc.Terminate()
    Sleep 2000
    Run A_AppData "\..\Local\WisprFlow\Wispr Flow.exe"
}
```

## Quick Verification: Is It Just the Hook?

If clicking the mic icon in the Wispr Flow bar works (dictation starts) but the keyboard shortcut doesn't — the issue is **isolated to the keyboard hook**. The app, audio pipeline, and dictation engine are all healthy. Focus troubleshooting on the Helper process and hook state.

## Diagnostic Checklist (Quick Reference)

1. ☐ Is Helper process running? (`Get-Process "Wispr Flow Helper"`)
2. ☐ Does accessibility.log show recent key events?
3. ☐ Does main.log show "Received first key event"?
4. ☐ Are there stale key warnings in accessibility.log?
5. ☐ Is the shortcut correct in config.json? (`"162+91": "ptt"`)
6. ☐ Are third-party keyboard hooks running? (AHK, Razer, Logitech, etc.)
7. ☐ Did this start after sleep/wake? → Full restart
8. ☐ Is the Win key specifically blocked? → Try non-Win shortcut
9. ☐ Can config dialog capture keys? → If no, edit config.json directly
10. ☐ Nuclear option: Full reboot always fixes hook issues
