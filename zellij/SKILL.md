---
name: zellij
description: V1.0 - Diagnose and maintain this machine's Zellij session persistence, PowerShell launcher, and Codex CLI keyboard compatibility.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the zellij directory (path contains 'zellij'), verify that history logging occurred.

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
            Before stopping, if zellij was used (check if any files in zellij directory were modified), verify that the interaction was logged:

            1. Check if History/{YYYY-MM-DD}.md exists in zellij directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed

            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}

            If history entry exists:
            - Return {"decision": "approve"}

            Include a systemMessage with details about the history entry status.
---

# Zellij

Use this skill for Zellij persistence, Windows PowerShell launcher behavior, and
Codex CLI keyboard issues inside Zellij panes on this machine.

## Local Baseline

- Zellij version verified on 2026-06-15: `zellij 0.44.3`.
- Codex CLI version verified on 2026-06-15: `codex-cli 0.139.0`.
- Zellij config: `C:\Users\User\AppData\Roaming\Zellij\config\config.kdl`.
- Zellij cache: `C:\Users\User\AppData\Local\Zellij\cache`.
- Global PowerShell profile: `C:\Users\User\Documents\PowerShell\profile.ps1`.

## Session Persistence

The preferred user workflow is one stable `main` session.

PowerShell function `z` should be:

```powershell
function z {
    zellij attach --create main --force-run-commands @args
}
```

Important details:

- Use `--create`; without it, `z` fails when `main` is missing.
- Do not rely on `. $PROFILE` to reload this function. The alias lives in the
  all-host profile, so open a new terminal tab/window.
- `--force-run-commands` is intentionally in use because the user requested
  automatic command resurrection.

Zellij config should keep the persistence settings explicit:

```kdl
session_name "main"
attach_to_session true
session_serialization true
serialize_pane_viewport true
scrollback_lines_to_serialize 10000
serialization_interval 1
```

Run these checks after changes:

```powershell
zellij setup --check
zellij list-sessions
```

## Codex CLI Shift+Enter Inside Zellij

Do not enable Zellij's enhanced or Kitty keyboard protocol on this machine as a
quick fix. It breaks Zellij navigation shortcuts; the observed failure was
`Ctrl+P` appearing literally as `[112;5u`.

Keep this Zellij keyboard baseline unless deliberately testing in a disposable
session:

```kdl
support_kitty_keyboard_protocol false
explicitly_disable_kitty_keyboard_protocol true
enable_keyboard_enhancement false
```

Observed behavior:

- Codex CLI `Shift+Enter` works outside Zellij but not inside a Zellij pane.
- Zellij with enhanced keyboard protocol disabled can treat `Shift+Enter` like
  plain `Enter`.
- Public Codex reports identify `Ctrl+J` as the reliable newline fallback.
- Public Zellij reports confirm similar `Shift+Enter` collapse inside Zellij
  and separate keyboard breakage when Kitty keyboard protocol is enabled.

Applied local fix on 2026-06-15:

- Stable Windows Terminal settings:
  `C:\Users\User\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`.
- Preview Windows Terminal settings:
  `C:\Users\User\AppData\Local\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json`.
- First attempt used a separate custom action id and keybinding reference. If
  that does not work, use the direct keybinding command form instead.
- Raw newline `\n` did not work for the user in Codex CLI inside Zellij.
- CSI-u mapping `\u001b[13;2u` was rejected because it appeared literally as
  `[13;2u` in Codex CLI inside Zellij.
- Current cleanup maps `shift+enter` back to the direct newline `sendInput`
  form and removes the generated CSI-u action ids.
- Backup suffix from the applied change:
  `settings.json.backup.20260615-150233`.
- Backup suffix before CSI-u attempt:
  `settings.json.backup.20260615-153102`.

Preferred troubleshooting order:

1. Keep Zellij keyboard enhancement disabled.
2. In Codex CLI inside Zellij, test `Ctrl+J` for newline.
3. If the user wants `Shift+Enter` muscle memory, prefer a terminal-emulator
   mapping, not a Zellij global keyboard protocol change. Do not use the CSI-u
   Shift+Enter sequence because it is emitted literally in this setup:

   ```json
   {
     "keybindings": [
       {
         "command": {
           "action": "sendInput",
           "input": "\n"
         },
         "keys": "shift+enter"
       }
     ]
   }
   ```

4. Restart Zellij after any config change marked `Requires restart`.

## Source Pointers

- OpenAI Codex GitHub discussion #3024: `Ctrl+J` cited as the newline shortcut.
- OpenAI Codex issue #20580: `Shift+Enter` / `Alt+Enter` newline regression.
- Zellij issue #4159: Zellij treats `Shift+Enter` the same as `Enter`.
- Zellij issue #3592: Kitty keyboard protocol plus NumLock can break `Ctrl+P`.
- Zellij issue #3723: workaround for broken keybindings can be
  `support_kitty_keyboard_protocol false`.
- Zellij colliding keybindings tutorial: use non-colliding presets for app
  shortcut conflicts, but this does not solve modified Enter by itself.
- Microsoft Windows Terminal actions docs: `sendInput` can feed arbitrary text
  such as `\n` to the shell.
- Later verification showed the separate `actions` plus keybinding `id` pattern
  may not be enough in this setup; prefer the direct keybinding command object.
- CSI-u references encode Shift+Enter as `ESC [ 13 ; 2 u`.
