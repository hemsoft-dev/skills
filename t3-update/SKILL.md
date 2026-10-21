---
name: t3-update
description: "V1.2 - Commands: Update, Status. After a T3 Code nightly update on Home, re-applies the local Waiting patch (threads waiting on a background shell command show Waiting), brings the remote T3 servers on mini and air to the same version, and restarts local T3 only when it is stale or an update is pending."
disable-model-invocation: true
compatibility: Windows only (Home). Requires PowerShell 7 and the T3 Code Nightly desktop install under %LOCALAPPDATA%\Programs\t3code.
---

# T3 update

One script does the work. Don't rebuild its steps by hand.

## Commands

- **Update** (default): `pwsh -NoProfile -File "$HOME/.agents/skills/t3-update/scripts/t3-update.ps1"`
  Run it through the Bash tool with `timeout: 600000`. Add `-Force` only when Franz asks for a restart anyway.
- **Status**: the same command with `-Status`. It changes nothing, and it includes each remote's version and
  running threads.

Options: `-Remote mini` (or `air`) limits the remote step, `-NoRemote` skips it, and `-AllowBusy` updates a remote
even though threads are running there.

Invoking this skill is Franz's approval to restart T3, which interrupts running T3 agent sessions. When the
script says no restart is needed, nothing is touched. If this session runs inside a T3 thread, the restart ends
it; the worker task finishes on its own and writes `%LOCALAPPDATA%\t3-waiting-patch\update-result-<run>.json`.

## What the script guarantees

- It patches `server.asar` with `scripts/t3-waiting-patch.ps1` (same-length bytes, header SHA-256 updated, backup
  kept). Only the client copy of the rule changes, which drives the sidebar.
- It restarts only when T3 started before `server.asar` was last written, when a downloaded update is waiting in
  `%LOCALAPPDATA%\t3code-updater\pending`, or with `-Force`. If T3 isn't running, it starts it.
- The restart runs as the one-shot task "T3 Update Worker", outside T3's process tree. It closes T3 gracefully,
  forcing it after 30 s, waits for the updater's installer, patches, relaunches T3 through Explorer and verifies
  that T3 runs patched, current code.
- It re-installs or starts the "T3 Waiting Patch" watcher task when it's missing or stopped.
- Before any local restart, it brings each remote T3 CLI server to the local version (or the update waiting to
  install), using `scripts/remote-server.sh` over SSH. It covers mini (systemd user unit `t3code.service`, T3 home
  `~/.t3`) and air (launchd agent `com.t3code.server`, T3 home `~/.t3-server`). It installs `t3@<version>` with
  npm, installs that runtime into the service's T3 home, repoints the unit or plist (keeping a backup in
  `<home>/t3-update-backup`), restarts and checks the version in `/.well-known/t3/environment`, rolling back on
  failure. A remote with running threads is skipped. An unreachable machine is reported and doesn't fail the run.
- A T3 desktop client with an SSH-launched connection to a remote starts its own old `t3 serve` the moment the
  service goes down, and then the service can't start (`ServerAlreadyRunningError`). The remote script stops such
  servers on the same T3 home and restarts the service.

## Exit codes

| Code | Meaning | Next step |
| --- | --- | --- |
| 0 | Done; T3 runs patched, current code | Report the summary lines |
| 2 | This T3 build no longer contains the patched rule | See below |
| 3 | Restart failed or timed out | Read `%LOCALAPPDATA%\t3-waiting-patch\update-log.txt` and report |
| 4 | A remote update failed (rolled back if possible) | Report the remote lines; check `systemctl --user status t3code` or `launchctl print gui/$(id -u)/com.t3code.server` on that machine |
| 5 | A remote was skipped because threads are running there | Ask Franz; on approval re-run with `-Remote <name> -AllowBusy` |

For exit 2, check whether upstream now holds threads in Waiting for background commands
([discussion #15433](https://github.com/pingdotgg/t3code/discussions/15433)). If it does, retire the patch with
`t3-waiting-patch.ps1 -UninstallTask`. If not, extract `server.asar` (`npx @electron/asar extract`), find
`backgroundWorkKindHoldsCompletion` in the client `runtime-*.js` chunk, update `$Targets` in
`t3-waiting-patch.ps1`, and test on a copy (`-Asar <copy> -StateDir <dir>`, then `-Restore`) before patching the
install.

## History

After using this skill, append `## HH:MM - {Action Taken}` and a one-line summary to `History/{YYYY-MM-DD}.md` in
this skill folder, noting whether a retrospective check found a reusable improvement. Take the time from the shell
(`Get-Date -Format "HH:mm"`), never an estimate.
