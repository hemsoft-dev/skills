; AutoHotkey Startup Script
; ===========================

; Ctrl+Shift+E - Edit this script
^+e::Edit

; Ctrl+Shift+R - Reload this script
^+r::Reload

; Ctrl+Shift+G - Activate or launch ChatGPT
^+g:: {
    if WinExist("ahk_exe ChatGPT.exe") {
        WinActivate
    } else {
        Run("shell:AppsFolder\chatgpt.com-DFCB3CE4_ch69rtgtz055j!App")
    }
}

; Ctrl+Shift+N - Activate or launch Obsidian (Notes)
^+n:: {
    if WinExist("ahk_exe Obsidian.exe") {
        WinActivate
    } else {
        Run("shell:AppsFolder\md.obsidian")
    }
}

; Ctrl+Shift+T - Activate or launch Todoist
^+t:: {
    if WinExist("ahk_exe Todoist.exe") {
        WinActivate
    } else {
        Run("shell:AppsFolder\app.todoist.com-F3949B29_5r3ptnqrybf3c!App")
    }
}
