---
name: mini-github-runner
description: "V1.1 - Commands: Status, Plan, Provision, Register, Verify, Distribute. Build and maintain the isolated GitHub Actions runner hosted on mini, with implementation state tracked in TODO.md."
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
- Runners (v2.336.0, one repository-scoped registration each, never
  org-wide). New registrations run as their own account, `actions-<repo>`;
  both live runners predate that and still run as `actions` (migration of the
  project-manager runner is pending in `TODO.md`):
  - `mini-github-runner-01` under `/opt/actions-runner/yahtzee`, unit
    `actions.runner.HemSoft-yahtzee.mini-github-runner-01.service`, labels
    `mini` and `yahtzee`.
  - `mini-github-runner-01-pm` for `hemsoft-dev/project-manager` under
    `/opt/actions-runner/project-manager`, unit
    `actions.runner.hemsoft-dev-project-manager.mini-github-runner-01-pm.service`,
    labels `mini` and `project-manager`. Its CI runs here because hosted
    minutes for private hemsoft-dev repos are blocked by the org's $0 Actions
    budget (Chief approval, 2026-10-21).
- Guest build tools: `gcc` and `libc6-dev` (for Go `-race`), from the Ubuntu
  repository; cloud-init and `scripts/prepare-gh-aw-runtime.sh` both install
  them, so a rebuilt guest has them.
- GH AW runtime: Docker Engine 29.7.2, Docker Compose 5.5.0, GitHub CLI
  2.45.0, and ripgrep 14.1.0. The `actions` user belongs to the guest-local
  `docker` group. Node.js remains workflow-managed through `actions/setup-node`.
- Repositories: `hemsoft-dev/yahtzee`, whose only self-hosted workflow is
  `.github/workflows/self-hosted-smoke.yml` (`workflow_dispatch`, zero token
  permissions), and `hemsoft-dev/project-manager`, whose `ci.yml` runs on
  `[self-hosted, mini, project-manager]` with `contents: read`. Yahtzee is
  public and stays the restricted public-repository exception (manual-only
  workflow, fork approval required, see `TODO.md`); project-manager is
  private, and only its own pull requests and pushes run on its runner.

## Commands

### Status

Read `TODO.md`, inspect `mini`, the guest, GitHub runner registration, and relevant workflow runs. Report verified state separately from pending work.

Use these live checks:

```powershell
ssh mini 'virsh -c qemu:///system dominfo github-runner-01; virsh -c qemu:///system net-info default; virsh -c qemu:///system nwfilter-binding-list'
$env:GH_TOKEN = gh auth token --user HemSoft
gh api repos/hemsoft-dev/yahtzee/actions/runners --jq '.runners[] | select(.name=="mini-github-runner-01")'
gh run list --repo hemsoft-dev/yahtzee --workflow self-hosted-smoke.yml --limit 5
gh api repos/hemsoft-dev/project-manager/actions/runners --jq '.runners[] | select(.name=="mini-github-runner-01-pm")'
gh run list --repo hemsoft-dev/project-manager --workflow ci.yml --limit 5
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

For any repository, request the token with the `HemSoft` GitHub CLI account
(`gh api -X POST repos/OWNER/REPO/actions/runners/registration-token --jq .token`)
and stream it as the first stdin line into the guest, where
`scripts/register-repo-runner.sh OWNER/REPO RUNNER_NAME LABELS` reads it into
memory, verifies the official runner archive, creates the runner's own account
`actions-<repo>` when missing, registers under `/opt/actions-runner/<repo>`,
checks that the raw token was not written there, and writes and starts the
systemd unit itself (root never runs the archive's `svc.sh` or any file the
runner account could have changed). It hands the token to `config.sh` through
`ACTIONS_RUNNER_INPUT_TOKEN` (readable only by the runner user and root), never
argv. It rejects `.`/`..` repository names and refuses any existing runner
directory before unpacking, so root only runs installers in a tree it just
created. To re-register, run the full [Unregister](#unregister) procedure
first: it removes the GitHub registration, the unit and its record, and the
runner directory. For example, from mini:

```bash
set -euo pipefail
ip=$(virsh -c qemu:///system domifaddr github-runner-01 --source lease |
  awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')
[ -n "$ip" ] || { echo "no DHCP lease for github-runner-01" >&2; exit 1; }
helper="$HOME/.agents/skills/mini-github-runner/scripts/register-repo-runner.sh"
test -s "$helper" || { echo "missing $helper" >&2; exit 1; }
{ gh api -X POST repos/hemsoft-dev/project-manager/actions/runners/registration-token --jq .token &&
  cat "$helper"; } |
  ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$HOME/.ssh/github-runner-01_known_hosts" \
    -i "$HOME/.ssh/github-runner-01_ed25519" runner-admin@"$ip" \
    'IFS= read -r t; s=$(cat); [ -n "$t" ] && [ -n "$s" ] || { echo "token or helper missing" >&2; exit 2; }
     printf "%s\n" "$t" | bash -c "$s" _ hemsoft-dev/project-manager mini-github-runner-01-pm mini,project-manager'
```

The helper path is the installed skill copy, so the example works from any
directory; both sides refuse an empty token or script instead of running an
empty program.

Root records which repository owns each account in
`/etc/actions-runner/accounts/<account>` and each runner's unit in
`/etc/actions-runner/units/<repo>`, outside anything a runner account can
write; the helper refuses an existing account owned by another repository, so
truncated or normalized names cannot share a UID. It registers without
`--replace`, so a runner name already in use in the repository fails instead
of silently taking over that runner. Runner names are limited to letters,
digits, `.`, `_` and `-` (up to 64 characters).

A runner that needs the GH AW Docker runtime gets it after registration, for
its own account and unit:

```bash
# From mini: stream the installed script into the guest; it runs there, for
# the account and unit the helper recorded (never a hand-typed account name).
set -euo pipefail
ip=$(virsh -c qemu:///system domifaddr github-runner-01 --source lease |
  awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')
[ -n "$ip" ] || { echo "no DHCP lease for github-runner-01" >&2; exit 1; }
script="$HOME/.agents/skills/mini-github-runner/scripts/prepare-gh-aw-runtime.sh"
test -s "$script" || { echo "missing $script" >&2; exit 1; }
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$HOME/.ssh/github-runner-01_known_hosts" \
  -i "$HOME/.ssh/github-runner-01_ed25519" runner-admin@"$ip" \
  'd=/opt/actions-runner/<repo>; u=$(sudo stat -c %U "$d"); s=$(sudo cat "/etc/actions-runner/units/${d##*/}")
   RUNNER_USER="$u" RUNNER_DIRECTORY="$d" RUNNER_SERVICE="$s" bash -s' < "$script"
```

It adds that account to the guest-local `docker` group and restarts the
recorded unit. project-manager's CI does not use Docker and skips this step.

`scripts/register-yahtzee-runner.sh` is the original single-repository helper;
it takes the token from `RUNNER_REGISTRATION_TOKEN` in its own process
environment. Never put the token in an argument, command history, temporary
file, TODO, or history entry. Rerun `scripts/verify-guest-isolation.sh` after
every registration.

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

For project-manager, which has no manual smoke workflow, rerun its most recent
CI run (read-only, `contents: read`) and confirm the job ran on the expected
runner:

```powershell
$env:GH_TOKEN = gh auth token --user HemSoft
$run = gh run list --repo hemsoft-dev/project-manager --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run rerun $run --repo hemsoft-dev/project-manager
gh run watch $run --repo hemsoft-dev/project-manager --exit-status
gh api "repos/hemsoft-dev/project-manager/actions/runs/$run/jobs" --jq '.jobs[] | {name, runner_name, conclusion}'
```

Require `runner_name` to be `mini-github-runner-01-pm` and `conclusion` to be
`success`.

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
- [project-manager self-hosted runners](https://github.com/hemsoft-dev/project-manager/settings/actions/runners)
- [project-manager CI runs](https://github.com/hemsoft-dev/project-manager/actions/workflows/ci.yml)

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

### Select the runner

Every per-runner command below acts on one selected runner. Set these first,
inside the guest as `runner-admin` and on the GitHub side, for the runner the
user named:

| Runner | Repository | Directory |
| --- | --- | --- |
| `mini-github-runner-01` | `hemsoft-dev/yahtzee` | `/opt/actions-runner/yahtzee` |
| `mini-github-runner-01-pm` | `hemsoft-dev/project-manager` | `/opt/actions-runner/project-manager` |

```bash
set -euo pipefail
runner_dir=/opt/actions-runner/project-manager # or /opt/actions-runner/yahtzee
runner_user=$(sudo stat -c %U "$runner_dir")
# Prefer root's record; the .service file sits in a directory the runner
# account can write, so whatever is read must be a plain unit basename.
record="/etc/actions-runner/units/$(basename "$runner_dir")"
if sudo test -f "$record"; then runner_service=$(sudo cat "$record")
else runner_service=$(sudo cat "$runner_dir/.service"); fi
[[ "$runner_service" =~ ^actions\.runner\.[A-Za-z0-9_.-]+\.service$ ]] ||
  { echo "refusing unit name: $runner_service" >&2; exit 1; }
```

```powershell
$repo = 'hemsoft-dev/project-manager'; $name = 'mini-github-runner-01-pm'
$env:GH_TOKEN = gh auth token --user HemSoft
$id = gh api "repos/$repo/actions/runners" --jq ".runners[] | select(.name==`"$name`") | .id"
```

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
sudo systemctl status "$runner_service"
sudo systemctl restart "$runner_service"
sudo journalctl -u "$runner_service" -n 100 --no-pager
sudo -u "$runner_user" "$runner_dir/bin/Runner.Listener" --version
```

### Updates

The runner uses GitHub's default automatic update behavior. GitHub requires a
self-hosted runner to update within 30 days of a release and can require an
immediate critical-security update. Compare versions without changing state:

```bash
installed=$(sudo -u "$runner_user" "$runner_dir/bin/Runner.Listener" --version)
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

Unregister only when the user requests it, and only the selected runner, with
the selection block above (validated `$runner_service`) already run in the
same shell. Removing the VM, volumes, key, or backups is a separate
destructive action and needs an exact user request.

`config.sh remove` deletes both the GitHub registration and the local
configuration, then the runner directory is removed so a later registration
starts from a fresh, root-created tree. From mini, stream the removal token and
the guest steps the same way as registration (the guest side validates the
recorded unit name before any root operation):

```bash
set -euo pipefail
ip=$(virsh -c qemu:///system domifaddr github-runner-01 --source lease |
  awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')
[ -n "$ip" ] || { echo "no DHCP lease for github-runner-01" >&2; exit 1; }
repo=hemsoft-dev/project-manager; runner_dir=/opt/actions-runner/project-manager
guest=$(cat <<'GUEST'
set -euo pipefail
IFS= read -r t; [ -n "$t" ] || exit 2
runner_dir=$1
runner_user=$(sudo stat -c %U "$runner_dir")
record="/etc/actions-runner/units/$(basename "$runner_dir")"
if sudo test -f "$record"; then runner_service=$(sudo cat "$record")
else runner_service=$(sudo cat "$runner_dir/.service"); fi
[[ "$runner_service" =~ ^actions\.runner\.[A-Za-z0-9_.-]+\.service$ ]] ||
  { echo "refusing unit name: $runner_service" >&2; exit 1; }
sudo systemctl disable --now "$runner_service"
# Other runners on the same account (both live runners still use actions)
# could read the token from config.sh's environment: stop them meanwhile.
# Only active ones are stopped, and only those are started again afterwards.
others=""
for u in $(grep -lx "User=$runner_user" /etc/systemd/system/actions.runner.*.service 2>/dev/null |
  xargs -r -n1 basename | grep -vxF "$runner_service" || true); do
  if systemctl is-active --quiet "$u"; then sudo systemctl stop "$u"; others="$others $u"; fi
done
# Older units use KillMode=process, so job processes can outlive a stop. No
# process of this account may run while the token is in its environment.
sudo pkill -KILL -u "$runner_user" || true
for _ in 1 2 3 4 5; do pgrep -u "$runner_user" >/dev/null || break; sleep 1; done
if pgrep -u "$runner_user" >/dev/null; then
  echo "processes of $runner_user are still running; not exporting the token" >&2
  for u in $others; do sudo systemctl start "$u"; done
  exit 1
fi
ACTIONS_RUNNER_INPUT_TOKEN="$t" sudo --preserve-env=ACTIONS_RUNNER_INPUT_TOKEN -u "$runner_user" \
  bash -c 'cd "$1" && exec ./config.sh remove --unattended' _ "$runner_dir"
unset t
for u in $others; do sudo systemctl start "$u"; done
sudo rm -f "/etc/systemd/system/$runner_service" "$record"
sudo systemctl daemon-reload
sudo rm -rf --one-file-system "$runner_dir"
GUEST
)
{ gh api -X POST "repos/$repo/actions/runners/remove-token" --jq .token &&
  printf '%s\n' "$guest"; } |
  ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$HOME/.ssh/github-runner-01_known_hosts" \
    -i "$HOME/.ssh/github-runner-01_ed25519" runner-admin@"$ip" \
    "IFS= read -r t; s=\$(cat); [ -n \"\$t\" ] && [ -n \"\$s\" ] || exit 2; printf '%s\\n' \"\$t\" | bash -c \"\$s\" _ $runner_dir"
```

If `config.sh remove` cannot reach GitHub, delete the resolved ID instead
(never a hard-coded one), then finish the guest steps after the `config.sh`
line:

```powershell
if (-not $id) { throw "runner $name not found in $repo" }
gh api --method DELETE "repos/$repo/actions/runners/$id"
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
- Docker failure: run `sudo -u "$runner_user" -H docker version`, inspect
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
