# mini-github-runner implementation

Status: In progress

Last verified: 2026-08-19 on `home`

## Goal

Run trusted GitHub Actions jobs on an isolated virtual machine hosted by `mini`, then install this completed skill on every fleet computer that supports agent skills.

## Decisions

- [x] Project name is `mini-github-runner`.
- [x] Coolify is out of scope.
- [x] Use KVM guest `github-runner-01` instead of installing the runner under `franz`.
- [x] Keep the guest off Tailscale and block access to the tailnet and home LAN.
- [x] Use repository-level runners because `HemSoft` is a GitHub personal account.
- [x] Track implementation and proof in this file until closeout.
- [ ] Choose the first `HemSoft/REPOSITORY` for registration and smoke testing.

## Live baseline

- [x] `ssh mini` succeeds from `home` through Tailscale SSH.
- [x] Host is Ubuntu 26.04 LTS on bare metal.
- [x] Host has AMD Ryzen 5 7640HS, 6 cores, 12 threads.
- [x] Host has 12 GiB RAM with about 10 GiB available at inspection time.
- [x] Root filesystem has 871 GiB free.
- [x] CPU virtualization flags and `kvm_amd` are present.
- [x] No existing GitHub runner, Coolify service, active Docker service, or KVM management command was detected.
- [x] Noninteractive sudo is unavailable. Privileged provisioning needs a visible password prompt.

## Milestone 1: Project scaffold

- [x] Create `mini-github-runner/SKILL.md`.
- [x] Create this `TODO.md` implementation ledger.
- [x] Enable history tracking.
- [x] Publish the initial project with the complete authorized skills worktree.
- [ ] Add tested provisioning and verification scripts only where they reduce repeated manual work.
- [x] Validate frontmatter, links, Markdown, and script syntax.

## Milestone 2: Prepare mini

- [ ] Open a visible `ssh mini` session for Franz to enter the sudo password.
- [ ] Install the smallest required KVM, libvirt, cloud-image, and guest-management packages.
- [ ] Enable and verify the libvirt service.
- [ ] Grant `franz` the minimum group access needed to manage the guest.
- [ ] Record package versions and service state.
- [ ] Preserve existing host firewall and Tailscale SSH behavior.

## Milestone 3: Create github-runner-01

- [ ] Download and verify a supported Ubuntu cloud image.
- [ ] Create guest storage with a 100 GiB maximum.
- [ ] Allocate 4 vCPUs and 4 to 6 GiB RAM.
- [ ] Create a dedicated guest administrator and SSH key path without copying private keys between machines.
- [ ] Boot the guest and prove console or SSH administration.
- [ ] Apply operating-system updates.
- [ ] Install only required build tools and Docker if the selected workflows need it.

## Milestone 4: Enforce network isolation

- [ ] Confirm the guest has outbound DNS and HTTPS.
- [ ] Block guest access to `100.64.0.0/10`.
- [ ] Block guest access to home LAN private subnets.
- [ ] Prove blocked access with recorded commands and results.
- [ ] Confirm the guest has no Tailscale client or credentials.

## Milestone 5: Register GitHub runner

- [ ] Confirm the exact target repository.
- [ ] Confirm GitHub authentication uses the `HemSoft` account for runner administration.
- [ ] Download the current official GitHub Actions runner release and verify its published checksum.
- [ ] Register `mini-github-runner-01` with explicit labels.
- [ ] Install and enable the runner service under a dedicated guest user.
- [ ] Confirm GitHub reports the runner online.
- [ ] Ensure no registration token remains in files, history, logs, or shell configuration.

## Milestone 6: End-to-end validation

- [ ] Add or select a harmless smoke workflow for the target repository.
- [ ] Prove the workflow ran on `mini-github-runner-01`.
- [ ] Record workflow URL, run ID, commit SHA, conclusion, and runner labels.
- [ ] Reboot the guest and prove the runner returns online automatically.
- [ ] Reboot recovery or host restart behavior is documented and tested when safe.
- [ ] Re-run network isolation checks after service installation.

## Milestone 7: Finish the skill

- [ ] Replace provisional instructions with commands proven on the live system.
- [ ] Add status, backup, update, unregister, and recovery procedures.
- [ ] Add a runner upgrade check for GitHub's supported-version policy.
- [ ] Add concise troubleshooting for offline, queued, token, disk, Docker, and network failures.
- [ ] Record final source SHA-256 hashes.

## Milestone 8: Fleet distribution

- [x] Define skill-capable targets as `home`, `laptop`, `air`, and `mini`.
- [x] Record that `iphone` cannot host an agent skill or accept SSH installation.
- [ ] Verify each target's live reachability and destination path.
- [ ] Preserve any existing destination copy before replacement.
- [ ] Install the completed skill on `home`.
- [ ] Install the completed skill on `laptop`.
- [ ] Install the completed skill on `air`.
- [ ] Install the completed skill on `mini`.
- [ ] Compare installed SHA-256 hashes with the source on every target.
- [ ] Run a native `Status` read on every target.

## Acceptance checks

- [ ] `mini-github-runner-01` is online in the selected GitHub repository.
- [ ] A current-head smoke workflow succeeds on that runner.
- [ ] The guest cannot reach the tailnet or home LAN.
- [ ] Runner service survives a guest reboot.
- [ ] No secrets exist in the project files or git diff.
- [ ] Skill documentation matches the live implementation.
- [ ] All four skill-capable fleet computers have matching verified copies.
- [x] Repository checks pass for the complete user-authorized worktree.
- [ ] Status changes from `In progress` to `Complete` only after every check above passes.

## Evidence log

### 2026-08-19

- `mini` alias connected from `home`; host reported Ubuntu 26.04 LTS and more than two weeks of uptime.
- Capacity inspection reported 12 CPUs, 12 GiB RAM, and 871 GiB free on `/`.
- `systemd-detect-virt` reported `none`; `svm` flags, `kvm`, and `kvm_amd` were present.
- No `virt-install`, `virsh`, `cloud-localds`, active libvirt service, runner process, or active Docker service was found.
- `sudo -n true` returned exit code 1, so provisioning requires an interactive password entry.
- GitHub API reported `HemSoft` with account type `User`.
- Repository validation passed Markdown lint across 153 files, PSScriptAnalyzer
  across 12 scripts, 18 Copilot processor Pester tests, JSON and PowerShell
  syntax checks, skill frontmatter checks, and `git diff --check`.
- Franz explicitly authorized committing and pushing every current skills
  repository change so `main` can return to a clean state.
- Commit `f71e7cb5` published the initial project and complete authorized
  25-file worktree to `origin/main`; repository hooks passed PowerShell and
  Markdown checks during the commit.

## Current blockers

1. Privileged package installation on `mini` requires Franz to enter the sudo password in a visible terminal.
2. GitHub runner registration requires the first exact `HemSoft/REPOSITORY` target.
