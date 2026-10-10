---
name: mini-github-runner
description: "V1.0 - Commands: Status, Plan, Provision, Register, Verify, Distribute. Build and maintain the isolated GitHub Actions runner hosted on mini, with implementation state tracked in TODO.md."
---

# Mini GitHub runner

Build and operate an isolated GitHub Actions self-hosted runner on `mini`.

## Project contract

1. Read `TODO.md` before taking action.
2. Treat `TODO.md` as the implementation ledger until every acceptance check passes.
3. Update `TODO.md` after each material action with exact commands, results, and blockers.
4. Get history timestamps with `Get-Date -Format "HH:mm"`. Never estimate them.
5. Do not mark distribution complete until the installed files match the source hashes on every skill-capable fleet computer.

## Fixed architecture

- Host: `mini`, reached with the fleet SSH alias.
- Guest: KVM virtual machine `github-runner-01`.
- Isolation: the guest does not join Tailscale and cannot reach the tailnet or home LAN.
- Runtime: the GitHub runner and Docker engine run inside the guest, never as
  `franz` on the host.
- Scope: repository-level registrations in `hemsoft-dev`, authenticated as `HemSoft`.
- Secrets: never write registration tokens, credentials, or private keys into this skill, `TODO.md`, history, logs, or shell output.

## Live implementation

- Host libvirt URI: `qemu:///system` on `mini`.
- Guest: Ubuntu 24.04 LTS, 4 vCPUs, 5 GiB RAM, 100 GiB sparse qcow2.
- Guest administration: `runner-admin` through the private key and dedicated
  known-hosts file under `/home/franz/.ssh/` on mini.
- Network: libvirt `default` NAT with filter `github-runner-locked`. The guest
  may reach the libvirt gateway and public Internet, but not RFC1918,
  `100.64.0.0/10`, or IPv4 link-local destinations.
- Runner: v2.336.0 under `/opt/actions-runner/yahtzee`, systemd unit
  `actions.runner.HemSoft-yahtzee.mini-github-runner-01.service`, user
  `actions`, labels `mini` and `yahtzee` plus GitHub's default labels.
- GH AW runtime: Docker Engine 29.7.2, Docker Compose 5.5.0, GitHub CLI
  2.45.0, and ripgrep 14.1.0. The `actions` user belongs to the guest-local
  `docker` group. Node.js remains workflow-managed through `actions/setup-node`.
- Repository: `hemsoft-dev/yahtzee`. Its only self-hosted workflow is
  `.github/workflows/self-hosted-smoke.yml`, triggered only by
  `workflow_dispatch` with zero token permissions.

## Commands

### Status

Read `TODO.md`, inspect `mini`, the guest, GitHub runner registration, and relevant workflow runs. Report verified state separately from pending work.

Use these live checks:

```powershell
ssh mini 'virsh -c qemu:///system dominfo github-runner-01; virsh -c qemu:///system net-info default; virsh -c qemu:///system nwfilter-binding-list'
$env:GH_TOKEN = gh auth token --user HemSoft
gh api repos/hemsoft-dev/yahtzee/actions/runners --jq '.runners[] | select(.name=="mini-github-runner-01")'
gh run list --repo hemsoft-dev/yahtzee --workflow self-hosted-smoke.yml --limit 5
```

Resolve the current DHCP lease and use strict host-key checking for guest
commands:

```bash
ip=$(virsh -c qemu:///system domifaddr github-runner-01 --source lease |
  awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$HOME/.ssh/github-runner-01_known_hosts" \
  -i "$HOME/.ssh/github-runner-01_ed25519" runner-admin@"$ip"
```

### Plan

Refine `TODO.md` without changing infrastructure. Record decisions that affect runner scope, guest resources, isolation, or repositories.

### Provision

Complete the next unchecked host or guest provisioning item. Use the `fleet` skill for remote access. Stop for an interactive sudo prompt when required. Do not weaken SSH, Tailscale, or host firewall policy to avoid that prompt.

The tested first-build sequence is:

1. Run `scripts/Invoke-PrepareMiniHost.ps1` on home and enter mini's sudo
   password only in its visible terminal.
2. Stream `scripts/provision-runner-vm.sh` to `ssh mini` and run it with Bash.
3. Pin the guest host key in
   `/home/franz/.ssh/github-runner-01_known_hosts` before the first SSH login.
4. Run `scripts/verify-guest-isolation.sh` inside the guest before registering
   any repository.
5. When a trusted GH AW workflow is selected, stream
   `scripts/prepare-gh-aw-runtime.sh` into the guest as `runner-admin`. This
   creates the `actions` system account if needed, installs Docker from Docker's
   signed Ubuntu repository plus `gh` and ripgrep, and adds Docker group access.
   Before registration there is no runner service to restart. For a registered
   runner, it restarts the unit recorded in `.service`. A configured `.runner`
   without a service record, an empty record or a missing recorded unit fails
   preparation rather than reporting success.

### Register

Require an exact `OWNER/REPOSITORY`. Confirm the repository owner and authenticated GitHub account before requesting a short-lived registration token. Register a distinct runner service for each repository and discard the token after use.

For Yahtzee, request the token from home with the `HemSoft` GitHub CLI account
and stream it as the first stdin line to `scripts/register-yahtzee-runner.sh`.
The helper reads it into process memory, verifies the official runner archive,
checks that the raw token was not written under the installation directory,
unsets it, and starts the service. Never put the token in an argument, command
history, temporary file, TODO, or history entry.

### Verify

Prove the service is online, run a harmless repository workflow on the self-hosted label, confirm the expected runner handled it, and check that the guest cannot reach the tailnet or home LAN. Record workflow and runner evidence in `TODO.md`.

```powershell
$env:GH_TOKEN = gh auth token --user HemSoft
gh workflow run self-hosted-smoke.yml --repo hemsoft-dev/yahtzee --ref main
gh run list --repo hemsoft-dev/yahtzee --workflow self-hosted-smoke.yml --limit 1
```

After any network, runner, or VM change, rerun
`scripts/verify-guest-isolation.sh` inside the guest. A package delivery or an
online status alone is not verification.

### Distribute

Distribute only after implementation and validation are complete. Install the skill on `home`, `laptop`, `air`, and `mini` under each user's `.agents/skills/mini-github-runner/`. Use the `fleet` skill's approved transport and verify SHA-256 hashes plus a native read of `SKILL.md` and `TODO.md` on every destination. The iPhone is not a skill host.

## Safety rules

- Never run pull-request code from untrusted contributors on a persistent runner.
- Keep GitHub token permissions at the workflow minimum.
- Do not mount the host filesystem or host Docker socket into the guest.
- Treat membership in the guest's `docker` group as root-equivalent inside the
  guest. Keep the VM isolation boundary intact.
- Do not give the guest a route to `100.64.0.0/10` or local private subnets.
- Preserve unrelated changes in the shared skills repository.
- Do not claim completion from package delivery alone. Native installation and verification are required.

## Operations

### Monitoring

Use these GitHub pages:

- [Yahtzee self-hosted runners](https://github.com/hemsoft-dev/yahtzee/settings/actions/runners)
- [Manual smoke workflow](https://github.com/hemsoft-dev/yahtzee/actions/workflows/self-hosted-smoke.yml)
- [All Yahtzee Actions runs](https://github.com/hemsoft-dev/yahtzee/actions)

The runner page shows online, offline, and busy state plus labels. The workflow
page shows each manual smoke run and its job logs. GitHub does not provide
guest CPU, memory, or disk graphs for a self-hosted runner, so inspect those on
mini and inside the guest.

```powershell
$env:GH_TOKEN = gh auth token --user HemSoft
gh api repos/hemsoft-dev/yahtzee/actions/runners --jq `
  '.runners[] | {id,name,status,busy,labels:[.labels[].name]}'
gh run list --repo hemsoft-dev/yahtzee --workflow self-hosted-smoke.yml --limit 10
```

```bash
virsh -c qemu:///system dominfo github-runner-01
virsh -c qemu:///system domstats github-runner-01
```

Inside the guest, use `systemctl status`, `journalctl`, `free -h`, `df -h`, and
`uptime` for service and host-resource monitoring.

### Guest and runner lifecycle

Run these on mini:

```bash
virsh -c qemu:///system start github-runner-01
virsh -c qemu:///system reboot github-runner-01 --mode agent
virsh -c qemu:///system shutdown github-runner-01 --mode agent
virsh -c qemu:///system autostart github-runner-01
```

Run these inside the guest as `runner-admin`:

```bash
runner_service=$(sudo cat /opt/actions-runner/yahtzee/.service)
sudo systemctl status "$runner_service"
sudo systemctl restart "$runner_service"
sudo journalctl -u "$runner_service" -n 100 --no-pager
sudo -u actions /opt/actions-runner/yahtzee/bin/Runner.Listener --version
```

### Updates

The runner uses GitHub's default automatic update behavior. GitHub requires a
self-hosted runner to update within 30 days of a release and can require an
immediate critical-security update. Compare versions without changing state:

```bash
installed=$(sudo -u actions /opt/actions-runner/yahtzee/bin/Runner.Listener --version)
latest=$(curl -fsS https://api.github.com/repos/actions/runner/releases/latest |
  jq -r '.tag_name | ltrimstr("v")')
printf 'installed=%s latest=%s\n' "$installed" "$latest"
```

Apply guest OS updates separately:

```bash
sudo apt-get update
sudo apt-get dist-upgrade
sudo reboot
```

After the reboot, require online GitHub status, a passing isolation script, and
a successful manual smoke run.

### Backup

Stop the guest cleanly before a disk-consistent backup. Record the volume names
with `virsh domblklist github-runner-01`, then use `virsh vol-download --pool
default` to a destination with restricted permissions and enough space. Hash
the downloaded qcow2 and seed ISO with SHA-256. The disk contains the runner's
operational credentials, so never put a backup in the skills repository or a
public share. Restart the guest and verify the runner after the copy.

### Unregister

Unregister only when the user requests it. Stop and uninstall the guest service
first with `svc.sh`, then delete runner ID 21 or its currently resolved ID with
the authenticated GitHub API. Removing the VM, volumes, key, or backups is a
separate destructive action and needs an exact user request.

```bash
cd /opt/actions-runner/yahtzee
sudo ./svc.sh stop
sudo ./svc.sh uninstall
```

```powershell
$env:GH_TOKEN = gh auth token --user HemSoft
gh api --method DELETE repos/hemsoft-dev/yahtzee/actions/runners/21
```

### Troubleshooting

- Offline runner: check the domain, guest lease, systemd service, journal, and
  public HTTPS before re-registering. Do not request a token first.
- Queued job: compare every `runs-on` label with the GitHub runner labels and
  confirm `busy` is false. Yahtzee jobs must remain manual-only.
- Expired token: discard it and request a fresh registration token. Tokens are
  short-lived and should never be reused from files or history.
- Disk pressure: inspect `df -h /` and `_work`; remove only disposable build
  output after proving no job is running. Do not delete runner credentials.
- Docker failure: run `sudo -u actions -H docker version`, inspect
  `systemctl status docker`, and confirm the live runner process lists the
  guest-local Docker group. Never substitute mini's host Docker socket.
- Network failure: distinguish public DNS/HTTPS failure from an expected
  private-range block. Inspect the libvirt lease, filter binding, and filter
  XML; never attach Tailscale or weaken the private-range policy as a shortcut.
- Broken filter: use libvirt management from mini to apply a reviewed filter
  and cold-start the guest. Preserve the `192.168.122.1` gateway exception so
  DNS and administrative SSH replies continue to work.

Current references:

- [GitHub self-hosted runner documentation](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners)
- [GitHub secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [GH AW self-hosted runner requirements](https://github.github.com/gh-aw/reference/self-hosted-runners/)
- [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [libvirt network filter format](https://libvirt.org/formatnwfilter.html)

## Completion

The project is complete only when every acceptance item in `TODO.md` is checked, the smoke workflow passes, isolation tests pass, and all skill-capable fleet computers have matching skill hashes.

## History

After using this skill, append `## HH:MM - {Action Taken}` and a one-line summary to `History/{YYYY-MM-DD}.md` in
this skill folder. Take the time from the shell (`Get-Date -Format "HH:mm"`), never an estimate.
