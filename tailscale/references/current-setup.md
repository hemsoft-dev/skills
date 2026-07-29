# Current Setup

Last verified: 2026-07-29 after enrolling and verifying Ubuntu host `mini`.

## Devices

### Windows desktop

- Windows host name: `DESKTOP-PHUBT5B`.
- Tailscale DNS: `desktop-phubt5b.tail3280fc.ts.net`.
- Tailscale IPv4: `100.101.122.39`.
- LAN IPv4: `192.168.1.17` on `Ethernet 2`.
- Windows account for SSH: `User`.
- Tailscale service: installed and running.
- Tailscale adapter: `Tailscale`, status `Up`.
- Tailscale CLI path: `C:\Program Files\Tailscale\tailscale.exe`.

### MacBook Air

- Local hostname: `Franzs-MacBook-Air.local`.
- Tailscale display name from Windows status: `Franz's MacBook Air`.
- Tailscale DNS: `franzs-macbook-air.tail3280fc.ts.net`.
- Tailscale IPv4: `100.69.182.27`.
- LAN IPv4 observed before Tailscale switch: `192.168.1.178`.
- macOS SSH account short name: `home`.
- Tailscale CLI path: `/Applications/Tailscale.app/Contents/MacOS/Tailscale`.

### Relias Windows laptop

- Tailscale host name: `relias`.
- Tailscale DNS: `relias.tail3280fc.ts.net`.
- Tailscale IPv4: `100.78.214.125`.
- Windows SSH account for inbound login: `relias`.
- Live TCP/22 test from the Windows desktop succeeded over interface
  `Tailscale` on 2026-06-29.
- Public key reported by the Relias setup for outbound SSH:
  `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFq/AYI7WxQ17Nt0MUWj4EdBSL3nteaPNXXpO2XzxuTc fhemmerrelias@github.com`.

### Ubuntu mini

- Ubuntu version: `26.04`.
- Local and Tailscale hostname: `mini`.
- Tailscale DNS: `mini.tail3280fc.ts.net`.
- Tailscale IPv4: `100.97.164.73`.
- LAN IPv4 observed during enrollment: `192.168.1.105`.
- LAN MAC observed during enrollment: `38-05-25-34-A5-B4`.
- SSH account: `franz`.
- User home: `/home/franz`.
- Tailscale version verified after enrollment: `1.98.10`.
- Tailscale SSH is enabled.
- Tailscale operator: `franz`, allowing non-root `tailscale file get`.

### Other tailnet host

- Existing Linux laptop: `franz-laptop.tail3280fc.ts.net`, `100.90.152.8`.

## Home-to-Mini SSH

The Windows desktop alias is:

```sshconfig
Host mini
    HostName mini.tail3280fc.ts.net
    User franz
    UserKnownHostsFile ~/.ssh/known_hosts_tailnet ~/.ssh/known_hosts
```

Verified from `home` on 2026-07-29:

```text
ssh mini
connected user=franz host=mini ip=100.97.164.73 tailscaled=active
```

Additional proof:

- `tailscale status --json` reported Linux host `mini` online.
- `tailscale ping mini` reached `100.97.164.73` directly through
  `192.168.1.105:41641` in 3 ms.
- MagicDNS resolved `mini.tail3280fc.ts.net` to `100.97.164.73`.
- `tailscale file cp --targets` listed `mini`.
- Home-to-mini Taildrop passed with a 77-byte smoke file and matching SHA-256
  `3e2b44aca6274d3674b6cb9aec0a5c062d4eb411e193120767e98301a1487ec9`.
- The accepted ED25519 host-key fingerprint is
  `SHA256:BbNqFA+udBFauI0URPmI7CW+cge9xVZl+LijFAXPpZQ`.

The MacBook Air has a `mini` alias with the same destination and account.
Alias expansion is verified there, but its first Tailscale SSH web check is
still pending. The Windows laptop was offline during rollout and does not yet
have the alias.

`mini` has no outbound private SSH key. Outbound SSH from `mini` to the Windows
or macOS hosts is intentionally unprovisioned until key authorization and the
narrow Windows firewall update are explicitly completed.

## Windows-to-Mac SSH

The local Windows SSH alias `air` was updated to use Tailscale:

```sshconfig
Host air
    HostName franzs-macbook-air.tail3280fc.ts.net
    User home
    IdentitiesOnly yes
    IdentityFile <redacted>
```

The Windows desktop SSH alias `relias` was added on 2026-06-29:

```sshconfig
Host relias
    HostName relias.tail3280fc.ts.net
    User relias
    IdentityFile <redacted>
    IdentitiesOnly yes
```

Verified command:

```powershell
ssh -o BatchMode=yes -o PreferredAuthentications=publickey air `
  'hostname; /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4; echo ok'
```

Verified output included:

```text
Franzs-MacBook-Air.local
100.69.182.27
ok
```

The accepted key fingerprint for `air` was:

```text
SHA256:kS9noLZQKw1COZmc4nM/unUXVb1O2SLGekh9Nc1exTg
```

The Mac account name problem was fixed: the user initially thought the Mac
username was `franz`, but `whoami` on the Mac returned `home`.

### Lid-Closed Caveat

When the MacBook Air lid was closed on 2026-06-15, `ssh air` timed out and
Windows Tailscale reported the Mac peer `franzs-macbook-air.tail3280fc.ts.net`
as `Online=false` with Tailscale IP `100.69.182.27`. Tailscale and SSH both
need the Mac awake; the tailnet does not make a sleeping Mac reachable.

Before the lid was closed, the Mac was on AC power and had:

```text
AC Power:
 sleep 0
 womp 1
 tcpkeepalive 1
 powernap 1
```

Those settings prevent idle sleep on AC and allow network wake behavior, but
they did not keep the Mac reachable after lid-close sleep in this setup.

## Mac-to-Windows SSH

Mac-to-Windows SSH is reachable over Tailscale. Windows `sshd` is running,
automatic, and restricted by firewall to the MacBook Air and Relias laptop
Tailscale IPs.

The user ran this in elevated PowerShell:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

Observed output:

```text
Path          :
Online        : True
RestartNeeded : True
```

Then this failed because the service did not exist yet:

```powershell
Set-Service sshd -StartupType Automatic
```

Failure:

```text
Set-Service : Service sshd was not found on computer '.'.
```

Diagnosis: Windows staged OpenSSH Server and needs a reboot before `sshd`
materializes.

## Post-Restart Windows OpenSSH State

Final post-restart state verified on 2026-06-29:

- `sshd` exists.
- `sshd` is `Running` and `Automatic`.
- Port 22 is listening on `0.0.0.0` and `::`.
- `OpenSSH-Server-In-TCP` remote addresses are restricted to `100.69.182.27`
  and `100.78.214.125`.
- Mac `ssh -o BatchMode=yes -o ConnectTimeout=8 home whoami` succeeded and
  returned `User`.
- Windows SSH banner from Mac: `SSH-2.0-OpenSSH_for_Windows_9.5`.
- The Relias laptop public key is authorized on the Windows desktop via
  `C:\ProgramData\ssh\administrators_authorized_keys`; direct Relias-to-home
  auth still needs to be tested from the Relias laptop.

If this needs to be recreated after a future reinstall, use elevated PowerShell:

```powershell
Get-Service sshd

Set-Service sshd -StartupType Automatic
Start-Service sshd

New-NetFirewallRule `
  -Name OpenSSH-Server-In-Tailscale-Air `
  -DisplayName "OpenSSH Server (sshd) - Tailscale Air" `
  -Enabled True `
  -Direction Inbound `
  -Protocol TCP `
  -Action Allow `
  -LocalPort 22 `
  -RemoteAddress 100.69.182.27
```

Then verify from Windows:

```powershell
Get-Service sshd
Get-NetTCPConnection -LocalPort 22 -State Listen
```

Then from the Mac:

```bash
ssh User@desktop-phubt5b.tail3280fc.ts.net
```

Mac alias now exists:

```sshconfig
Host desktop
  HostName desktop-phubt5b.tail3280fc.ts.net
  User User
```

Mac aliases added on 2026-06-29:

```sshconfig
Host home
  HostName desktop-phubt5b.tail3280fc.ts.net
  User User
  IdentityFile <redacted>
  IdentitiesOnly yes

Host relias
  HostName relias.tail3280fc.ts.net
  User relias
  IdentityFile <redacted>
  IdentitiesOnly yes
```

Verified from the Mac:

```text
ssh -G desktop
host desktop
user User
hostname desktop-phubt5b.tail3280fc.ts.net
port 22
```

Use `ssh desktop` interactively from the Mac. It should prompt for the Windows
account password until Mac-to-Windows key auth is configured.

Home-side key auth has been configured by running this in elevated PowerShell
on the Windows desktop:

```powershell
powershell -ExecutionPolicy Bypass -File D:\tmp\finish-home-inbound-ssh.ps1
```

To finish key auth for `ssh relias` from the Windows desktop and MacBook Air,
run this on the Relias laptop:

```powershell
mkdir C:\tmp -Force
& "C:\Program Files\Tailscale\tailscale.exe" file get --conflict=overwrite C:\tmp
powershell -ExecutionPolicy Bypass -File C:\tmp\configure-relias-inbound-ssh.ps1
```

`D:\tmp\configure-relias-inbound-ssh.ps1` was sent to the Relias laptop with
`tailscale file cp D:\tmp\configure-relias-inbound-ssh.ps1 relias:` on
2026-06-29.

The Relias laptop's outbound key has already been added to the MacBook Air
user's `~/.ssh/authorized_keys`, so `ssh air` from Relias should work once its
local alias points at `home@franzs-macbook-air.tail3280fc.ts.net`.

If `Get-Service sshd` still says not found after restart, rerun the capability
install in elevated PowerShell and inspect the exact `State` or error:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
```

If updating firewall filters in an existing rule, this Windows build supports
pipeline/InputObject style, not `-AssociatedNetFirewallRule`:

```powershell
$rule = Get-NetFirewallRule -Name OpenSSH-Server-In-TCP
$rule | Get-NetFirewallPortFilter |
  Set-NetFirewallPortFilter -Protocol TCP -LocalPort 22
$rule | Get-NetFirewallAddressFilter |
  Set-NetFirewallAddressFilter -RemoteAddress 100.69.182.27
```

The patched helper script is:

```powershell
powershell -ExecutionPolicy Bypass -File D:\tmp\finish-windows-ssh-tailscale.ps1
```

## Security Notes

- Windows currently has Tailscale Funnel enabled for desktop HTTPS according to
  `tailscale status`, but do not use Funnel for SSH.
- Keep SSH private to the tailnet.
- If possible, restrict Windows firewall ingress to the Mac's Tailscale IP
  `100.69.182.27`.
- For Mac Remote Login, prefer key-only SSH. The Mac readable config had only
  default commented lines for password auth:

```text
#PasswordAuthentication yes
#KbdInteractiveAuthentication yes
#PubkeyAuthentication yes
```

Recommended Mac hardening after key access is confirmed:

```bash
sudo mkdir -p /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/99-key-only.conf >/dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
EOF

sudo /usr/sbin/sshd -t
sudo launchctl kickstart -k system/com.openssh.sshd
```
