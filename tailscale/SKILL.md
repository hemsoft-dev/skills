---
name: tailscale
description: Resume, verify, and troubleshoot this machine's Tailscale private mesh and SSH setup between Windows desktop, MacBook Air, and other tailnet hosts. Use when the user asks about Tailscale, secure tunnels over the internet, SSH over Tailscale, MagicDNS names, Windows OpenSSH Server setup after restart, Mac Remote Login over tailnet, or continuing the desktop/Mac tunnel setup.
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
3. Verify SSH separately from Tailscale:
   - TCP port 22 reachable.
   - SSH banner returned.
   - Key authentication succeeds with a non-interactive command.
4. If resuming after Windows restart, complete Windows OpenSSH Server setup
   before testing Mac-to-Windows SSH.
5. Update this skill's reference file when stable hostnames, usernames, or
   recovery steps change.

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
