---
name: tailscale
description: "V1.0 - Commands: Status, Enroll, SSH, Diagnose. Enroll, verify, and troubleshoot the private Tailscale mesh and SSH access across Windows, macOS, and Linux hosts."
---

# Tailscale

Use this skill for the user's private Tailscale SSH workflow. Prefer live
verification over remembered state: query Tailscale status, SSH config, service
state, listeners, and firewall rules before declaring a path ready.

## First Reads

Read [current-setup.md](references/current-setup.md) for the verified device
names, IPs, SSH aliases, and the current post-restart recovery checklist.

## Safety Rules

- Use the private tailnet for SSH. Do not recommend router port forwarding for
  port 22.
- Do not use Tailscale Funnel for SSH. Funnel is public exposure; SSH should
  stay on the private tailnet.
- Keep firewall rules narrow. Prefer allowing the Mac Tailscale IP only when
  opening Windows `sshd`.
- Treat `.ssh` paths as sensitive. Never print private key contents. Redact
  `IdentityFile` values unless the user explicitly asks.
- Challenge weak-password remote login. Prefer public-key SSH and disable
  password auth after key auth is verified.

## Workflow

1. Load current context from `references/current-setup.md`.
2. Verify current Tailscale state:
   - Windows: run `C:\Program Files\Tailscale\tailscale.exe status --json`.
   - Mac: use `ssh air` if available, then run
     `/Applications/Tailscale.app/Contents/MacOS/Tailscale status`.
   - Linux: run `tailscale status --json`.
3. Verify SSH separately from Tailscale:
   - TCP port 22 reachable.
   - SSH banner returned.
   - Key authentication succeeds with a non-interactive command.
4. If resuming after Windows restart, complete Windows OpenSSH Server setup
   before testing Mac-to-Windows SSH.
5. Update this skill's reference file when stable hostnames, usernames, or
   recovery steps change.

## Enroll an Ubuntu Host

1. Resolve the host on the LAN before enrollment. Tailscale cannot discover a
   machine until its client joins the tailnet.
2. Install `curl` when the Ubuntu image does not include it:

   ```bash
   sudo apt-get update
   sudo apt-get install -y curl
   ```

3. Install Tailscale and enable private Tailscale SSH:

   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up --hostname=<alias> --ssh
   ```

4. Open the authentication URL and join the existing tailnet.
5. From an enrolled host, verify all five signals:

   | Signal | Verification |
   | --- | --- |
   | Control plane | `tailscale status --json` shows the expected Linux host |
   | Encrypted path | `tailscale ping <alias>` succeeds |
   | MagicDNS | `<alias>.<tailnet>.ts.net` resolves to the assigned Tailscale IP |
   | SSH | `ssh <alias>` succeeds with the expected account and hostname |
   | Taildrop | `tailscale file cp --targets` lists the host |

6. If Tailscale SSH requests an additional check, complete its web
   authentication. Do not replace that check with password authentication.

## Useful Checks

Windows Tailscale:

```powershell
& "C:\Program Files\Tailscale\tailscale.exe" status
& "C:\Program Files\Tailscale\tailscale.exe" ip -4
```

Windows OpenSSH Server:

```powershell
Get-Service sshd
Get-NetTCPConnection -LocalPort 22 -State Listen
Get-NetFirewallRule | Where-Object {
  $_.DisplayName -match 'OpenSSH|SSH|sshd' -or $_.Name -match 'OpenSSH|SSH|sshd'
}
```

Mac over Tailscale:

```powershell
ssh air 'hostname; /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4'
```

SSH alias verification:

```powershell
ssh -G air
ssh -o BatchMode=yes -o PreferredAuthentications=publickey air true
```
