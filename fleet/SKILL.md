---
name: fleet
description: "V1.9 - Commands: Connect, Run, Send, Retrieve. Operate the private Tailscale fleet across laptop, home, air, mini, iphone, and ipad."
disable-model-invocation: true
---

# Fleet

Use the SSH aliases `laptop`, `home`, `air`, and `mini`. Use `iphone` and
`ipad` as the friendly names for the mobile Tailscale devices. Their MagicDNS
names are `iphone` and `ipad163`, respectively. Mobile devices are not SSH
targets. Verify an alias from its source computer before declaring that
direction ready.

## Default behavior

When the user invokes this skill without specifying a command, identify the
current machine, report the six fleet devices and their live Tailscale status,
then ask which machine and operation to use. Do not start interactive SSH or
transfer files without a specific destination and action.

## Machine map

| Alias | Platform | SSH account | Tailscale hostname | Tailscale IPv4 | User home |
| --- | --- | --- | --- | --- | --- |
| `laptop` | Windows | `User` | `desktop-7es73q4` | `100.117.202.124` | `C:\Users\User` |
| `home` | Windows | `User` | `desktop-phubt5b` | `100.101.122.39` | `C:\Users\User` |
| `air` | macOS | `home` | `franzs-macbook-air` | `100.69.182.27` | `/Users/home` |
| `mini` | Ubuntu 26.04 | `franz` | `mini` | `100.97.164.73` | `/home/franz` |
| `iphone` | iOS | N/A | `iphone` | `100.88.39.97` | N/A |
| `ipad` | iPadOS | N/A | `ipad163` | `100.64.238.123` | N/A |

Prefer aliases over IP addresses. Treat IP addresses and underlying hostnames
as diagnostics and fallbacks, not user-facing names.

## Connect and run commands

- Connect interactively with `ssh laptop`, `ssh home`, `ssh air`, or `ssh mini`.
- Test noninteractively with `ssh -o BatchMode=yes -o ConnectTimeout=10 <alias> "echo connected"`.
- Do not run SSH commands against `iphone` or `ipad`; they are Tailscale devices and Taildrop targets only.
- Invoke PowerShell explicitly for nontrivial commands on `laptop` or `home`.
- Use the normal remote shell on `air` or `mini`.
- `mini` uses Tailscale SSH. The tailnet's self-device SSH rule uses
  `accept`, so automation should not require an additional web check.
- Never disable SSH host-key checking. If a host-key mismatch appears, stop and report it.
- Use SSH for shells and remote commands only. Do not use FTP, SCP, or SFTP for file sharing.

## Tailscale CLI

Use Tailscale's native Taildrop commands for files. Resolve the CLI in this
order:

- Run `tailscale` if it is on `PATH`.
- On Windows, fall back to `C:\Program Files\Tailscale\tailscale.exe`.
- On air, fall back to `/Applications/Tailscale.app/Contents/MacOS/Tailscale`.

Taildrop target names differ from the friendly aliases:

| Friendly alias | Taildrop target |
| --- | --- |
| `laptop` | `desktop-7es73q4` |
| `home` | `desktop-phubt5b` |
| `air` | `franzs-macbook-air` |
| `mini` | `mini` |
| `iphone` | `iphone` |
| `ipad` | `ipad163` |

Confirm the current target list with `tailscale file cp --targets` when
diagnosing a delivery problem.

## Shared transfer convention

Every computer has the same tree beneath its user home. The mobile devices do
not participate in this shared directory convention.

```text
TailscaleShare/
├── Inbox/
│   ├── from-laptop/
│   ├── from-home/
│   ├── from-air/
│   └── from-mini/
└── Outbox/
    ├── to-laptop/
    ├── to-home/
    ├── to-air/
    └── to-mini/
```

Use these meanings consistently:

- `Inbox/from-<sender>/` is the delivery point on the receiving machine.
- `Outbox/to-<recipient>/` is the pickup point on the sending machine.
- Stage outbound files in `Outbox/to-<recipient>/` when practical, then send them with Taildrop.
- Prefix the Taildrop filename with `from-<sender>--` so the recipient can route it to the matching Inbox subfolder.
- The installed Windows and macOS desktop clients automatically receive Taildrop files in the user's `Downloads` directory.
- After receiving, move each `from-<sender>--<name>` file into `Inbox/from-<sender>/<name>`.

## Send and retrieve files

Determine the current machine and use its alias as `<sender>`. Convert the
recipient alias to its Taildrop target with the table above.

Send one file:

```text
tailscale file cp --name "from-<sender>--<filename>" "<local-file>" <recipient-taildrop-target>:
```

Desktop pickup locations:

```text
laptop: C:\Users\User\Downloads
home:   C:\Users\User\Downloads
air:    /Users/home/Downloads
mini:   /home/franz/Downloads
```

On `mini`, receive its CLI Taildrop inbox with
`tailscale file get --conflict=rename /home/franz/Downloads`. Do not run
`tailscale file get` routinely on the desktop clients.

`mini` is configured with Tailscale operator `franz`. After rebuilding
a Linux host, restore non-root Taildrop access once with:

```bash
sudo tailscale set --operator=$USER
```

Taildrop sends files, not directory trees. Archive a directory first, send the
archive, and keep or remove that archive according to the user's request.

## Transfer procedure

1. Resolve the source machine, destination machine, and exact source path.
2. Confirm the recipient appears in `tailscale file cp --targets`.
3. Stage the file in `Outbox/to-<recipient>/` when useful.
4. Send it with `tailscale file cp`, using the `from-<sender>--` filename prefix.
5. On the recipient, wait for the completed Taildrop file to appear in `Downloads`; the send command can return before the desktop client finishes placing it.
6. Move it to `Inbox/from-<sender>/`, removing only the routing prefix. Do not silently overwrite.
7. Verify the destination exists and compare byte size; use SHA-256 for important files.
8. Report the destination alias and native absolute path. Keep the source unless the user explicitly asks to move or delete it.

Use these native pickup paths when reporting completion:

- laptop: `C:\Users\User\TailscaleShare\Inbox\from-<sender>\`
- home: `C:\Users\User\TailscaleShare\Inbox\from-<sender>\`
- air: `/Users/home/TailscaleShare/Inbox/from-<sender>/`
- mini: `/home/franz/TailscaleShare/Inbox/from-<sender>/`

Taildrop is the file-sharing transport. Do not substitute FTP, SCP, SFTP,
public links, or email attachments unless the user explicitly asks. Do not
expose SSH beyond Tailscale or copy private SSH keys between machines.

## History

After using this skill, append an entry to `History/{YYYY-MM-DD}.md` in this
skill folder: `## HH:MM - {Action Taken}` plus a one-line summary. Take the
timestamp from the shell (`Get-Date -Format "HH:mm"` on Windows,
`date +%H:%M` elsewhere), never an estimate.
