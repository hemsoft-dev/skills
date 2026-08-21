# mini-github-runner implementation

Status: Complete

Last verified: 2026-08-19 at 22:03 on `home`

## Goal

Run trusted GitHub Actions jobs on an isolated virtual machine hosted by `mini`, then install this completed skill on every fleet computer that supports agent skills.

## Decisions

- [x] Project name is `mini-github-runner`.
- [x] Coolify is out of scope.
- [x] Use KVM guest `github-runner-01` instead of installing the runner under `franz`.
- [x] Keep the guest off Tailscale and block access to the tailnet and home LAN.
- [x] Use repository-level runners because `HemSoft` is a GitHub personal account.
- [x] Track implementation and proof in this file until closeout.
- [x] Use `HemSoft/yahtzee` as the first repository for registration and smoke testing.
- [x] Treat Yahtzee as a public-repository exception with a manual-only smoke
  workflow that never runs pull-request or other untrusted code.

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
- [x] Add tested provisioning and verification scripts only where they reduce repeated manual work.
- [x] Validate frontmatter, links, Markdown, and script syntax.

## Milestone 2: Prepare mini

- [x] Open a visible `ssh mini` session for Franz to enter the sudo password.
- [x] Install the smallest required KVM, libvirt, cloud-image, and guest-management packages.
- [x] Enable and verify the libvirt service.
- [x] Grant `franz` the minimum group access needed to manage the guest.
- [x] Record package versions and service state.
- [x] Preserve existing host firewall and Tailscale SSH behavior.

## Milestone 3: Create github-runner-01

- [x] Download and verify a supported Ubuntu cloud image.
- [x] Create guest storage with a 100 GiB maximum.
- [x] Allocate 4 vCPUs and 4 to 6 GiB RAM.
- [x] Create a dedicated guest administrator and SSH key path without copying private keys between machines.
- [x] Boot the guest and prove console or SSH administration.
- [x] Apply operating-system updates.
- [x] Install only required build tools and Docker if the selected workflows need it.

## Milestone 4: Enforce network isolation

- [x] Confirm the guest has outbound DNS and HTTPS.
- [x] Block guest access to `100.64.0.0/10`.
- [x] Block guest access to home LAN private subnets.
- [x] Prove blocked access with recorded commands and results.
- [x] Confirm the guest has no Tailscale client or credentials.

## Milestone 5: Register GitHub runner

- [x] Confirm the exact target repository as `HemSoft/yahtzee`.
- [x] Confirm GitHub authentication uses the `HemSoft` account with repository
  administration permission.
- [x] Verify public-repository Actions and fork-approval settings before runner registration.
- [x] Download the current official GitHub Actions runner release and verify its published checksum.
- [x] Register `mini-github-runner-01` with explicit labels.
- [x] Install and enable the runner service under a dedicated guest user.
- [x] Confirm GitHub reports the runner online.
- [x] Ensure no registration token remains in files, history, logs, or shell configuration.

## Milestone 6: End-to-end validation

- [x] Add a harmless `workflow_dispatch`-only smoke workflow for `HemSoft/yahtzee`.
- [x] Prove no Yahtzee workflow routes `pull_request` or other untrusted events to the self-hosted runner.
- [x] Prove the workflow ran on `mini-github-runner-01`.
- [x] Record workflow URL, run ID, commit SHA, conclusion, and runner labels.
- [x] Reboot the guest and prove the runner returns online automatically.
- [x] Reboot recovery or host restart behavior is documented and tested when safe.
- [x] Re-run network isolation checks after service installation.

## Milestone 7: Finish the skill

- [x] Replace provisional instructions with commands proven on the live system.
- [x] Add status, backup, update, unregister, and recovery procedures.
- [x] Add a runner upgrade check for GitHub's supported-version policy.
- [x] Add concise troubleshooting for offline, queued, token, disk, Docker, and network failures.
- [x] Record final source SHA-256 hashes.

## Milestone 8: Fleet distribution

- [x] Define skill-capable targets as `home`, `laptop`, `air`, and `mini`.
- [x] Record that `iphone` cannot host an agent skill or accept SSH installation.
- [x] Verify each target's live reachability and destination path.
- [x] Preserve any existing destination copy before replacement.
- [x] Install the completed skill on `home`.
- [x] Install the completed skill on `laptop`.
- [x] Install the completed skill on `air`.
- [x] Install the completed skill on `mini`.
- [x] Compare installed SHA-256 hashes with the source on every target.
- [x] Run a native `Status` read on every target.

## Milestone 9: Prepare the GH AW runtime

- [x] Confirm the Yahtzee runner is online, idle, and isolated before changing
  the guest.
- [x] Install Docker Engine and Compose from Docker's signed Ubuntu repository.
- [x] Install guest-local `gh` and ripgrep for GH AW and SFL workflow steps.
- [x] Add only the guest `actions` account to the guest-local Docker group.
- [x] Restart the runner service and prove its live process has Docker access.
- [x] Run `hello-world` as `actions` and reach GitHub plus GHCR over HTTPS.
- [x] Re-run the full guest isolation test after Docker modifies guest networking.
- [x] Run a fresh current-head Yahtzee smoke workflow after provisioning.
- [x] Add and idempotently verify the durable GH AW runtime provisioning script.
- [x] Update skill documentation and source hashes for the live runtime.
- [x] Redistribute and verify the updated skill on every skill-capable computer.

## Acceptance checks

- [x] `mini-github-runner-01` is online in the selected GitHub repository.
- [x] A current-head smoke workflow succeeds on that runner.
- [x] The guest cannot reach the tailnet or home LAN.
- [x] Runner service survives a guest reboot.
- [x] No secrets exist in the project files or git diff.
- [x] Skill documentation matches the live implementation.
- [x] All four skill-capable fleet computers have matching verified copies.
- [x] Repository checks pass for the complete user-authorized worktree.
- [x] Status changes from `In progress` to `Complete` only after every check above passes.

## Evidence log

### 2026-08-20

- Rechecked the live runner for an SFL subscription-auth feasibility review.
  `github-runner-01` was running with 4 vCPUs and 5 GiB RAM, its libvirt NAT
  network and `github-runner-locked` binding were active, and GitHub reported
  `mini-github-runner-01` online and idle for `HemSoft/yahtzee`.
- The guest runner service was active with 4.2 GiB memory available and 93 GiB
  disk free. The `actions` account had no Codex executable and no
  `~/.codex/auth.json`; the host's login is not shared into the isolated guest.
- Mini's host account had Codex CLI 0.146.0 logged in through ChatGPT. A bounded
  noninteractive read-only probe returned exactly `SUBSCRIPTION_OK` in five
  seconds using model `gpt-5.6-luna`, proving that the ChatGPT subscription can
  drive `codex exec` on Linux.
- Stock `gh-aw` remains incompatible with that login path: its Codex harness
  requires `CODEX_API_KEY` or `OPENAI_API_KEY` and assigns a transient
  `CODEX_HOME`. Merely changing `runs-on` to mini does not reuse the persistent
  ChatGPT login.
- A viable SFL experiment therefore needs a distinct repository runner service,
  a dedicated guest user with device-authenticated Codex, and a manual-only
  direct `codex exec` probe before any reviewer or consumer deployment. This is
  proposed work, not completed runner scope.

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
- Selected public repository `HemSoft/yahtzee` as the first runner target.
  The `HemSoft` GitHub token reported full administration permission.
- Cleaned and published Yahtzee commit
  `37234de8cf10021342d57d07e698f593f1763068` after rebasing onto three newer
  remote refactor commits. Local and remote `main` matched at `0 0` divergence.
- Yahtzee verification passed 117 game-engine tests, the desktop production
  build, UI and game-engine typechecks, and `run.ps1` syntax. GitHub reported
  zero configured check runs on the published commit.
- Yahtzee retains pre-existing check debt outside the cleanup commit: root
  lint lacks ESLint, root typecheck lacks `tsconfig.json`, desktop and web
  lack Vite `ImportMeta.env` typing, and mobile typecheck cannot resolve
  `process` or `@yahtzee/ui`.
- Corrected the proposed direct dependency from incompatible
  `expo-asset@55.0.10` to Expo SDK 52-compatible `~11.0.5`. Expo still reports
  older pre-existing compatibility drift in React, Async Storage, safe-area
  context, and React types.
- Re-verified `mini` before provisioning. Its physical LAN is
  `192.168.1.0/24` through gateway `192.168.1.1`; the isolation policy must
  block that subnet as well as `100.64.0.0/10` and other private ranges.
- Resolved current package candidates from Ubuntu 26.04: libvirt 12.0.0,
  QEMU 10.2.1, virt-install 5.1.0, cloud-image-utils 0.33, and nftables 1.1.6.
- Current GitHub documentation still warns against persistent self-hosted
  runners for public repositories. The Yahtzee exception remains restricted
  to an explicit `workflow_dispatch` job with minimum token permissions.
- Added `scripts/prepare-mini-host.sh` for the one privileged host bootstrap.
  It installs the current KVM/libvirt toolchain, grants only `kvm` and
  `libvirt` group access, enables libvirt, and starts the default NAT network.
- Franz entered the sudo password only in a visible `ssh -tt mini` terminal.
  The host bootstrap completed without writing or returning the password.
- Installed cloud-image-utils 0.33, libvirt 12.0.0-1ubuntu5.3, nftables 1.1.6,
  QEMU 10.2.1, and virt-install 5.1.0. `libvirtd.service` is enabled and active;
  the `default` NAT network is active, persistent, and set to autostart.
- A new SSH session reports `franz` in only the added `libvirt` and `kvm`
  management groups and confirms read/write access to `/dev/kvm`. Tailscale
  still reports `mini` online, and the existing inactive nftables service was
  not enabled or altered during host preparation.
- The first guest provisioning pass downloaded the 595.5 MiB Ubuntu 24.04
  cloud image and passed its published SHA-256 checksum, then stopped before
  disk allocation because Ubuntu had not defined a `default` libvirt storage
  pool. No VM or volume was created. The provisioning script now defines and
  autostarts the directory pool at `/var/lib/libvirt/images` and reuses a
  previously verified image.
- A second no-volume retry exposed libvirt's refusal to redefine an existing
  named network filter without its UUID. Because the VM does not yet exist,
  the script now removes only its own unattached `github-runner-locked`
  definition before defining the current policy.
- Live `virsh` inspection showed that version 12 provides
  `nwfilter-dumpxml`, not `nwfilter-info`; the filter existence probe now uses
  the supported command.
- Guest creation reached storage allocation, then `virt-install` 5.1 rejected
  the unsupported shorthand `filter=` network option. Live option discovery
  reported `filterref.filter=`. No domain exists; the script now rebuilds only
  its two named partial volumes, resizes the uploaded qcow2 header to 100 GiB,
  and uses the supported network-filter key.
- Created running domain `github-runner-01` with UUID
  `638b734d-fec7-40f8-a44f-5bd13406316a`, 4 vCPUs, 5 GiB RAM, a 100 GiB
  maximum qcow2 disk, AppArmor enforcement, and libvirt autostart. DHCP leased
  `192.168.122.221` to MAC `52:54:00:c4:5e:b3`.
- Generated a dedicated host-local Ed25519 administrator key at
  `/home/franz/.ssh/github-runner-01_ed25519`, pinned the guest host key in a
  separate known-hosts file, and completed cloud-init through strict SSH host
  checking. The private key never left mini.
- Ubuntu 24.04 cloud-init and package upgrades completed. The guest reports
  kernel 6.8.0-137, 4.8 GiB RAM, and 94 GiB free on its 96 GiB root filesystem.
- Pre-test policy review found that generic outbound web allowances needed
  earlier destination drops to meet the LAN requirement. The filter now drops
  RFC1918, `100.64.0.0/10`, and link-local IPv4 before allowing public HTTP or
  HTTPS, and limits guest DNS to libvirt's `192.168.122.1` resolver.
- The first bounded isolation test exposed rule ordering, not guest failure:
  private-destination drops also caught replies for mini's inbound SSH session.
  The VM retained its lease and filter binding. Established and related replies
  now pass before private-range drops, while new guest-initiated connections
  still reach the drop rules.
- The nftables-backed filter did not classify the new SSH reply as established
  soon enough to pass that rule. Administration now has one explicit exception:
  TCP replies from guest source port 22 may reach only libvirt host
  `192.168.122.1`; this does not permit guest-initiated private connections.
- The live binding remained present on `vnet0`, but direction-specific SSH
  rules still timed out. Both administrative SSH directions now match exact
  host address and port tuples with `direction='inout'`, avoiding backend
  direction interpretation while keeping the exception limited to the host.
- A cold start with one allow-all rule restored SSH immediately and proved the
  guest, lease, and libvirt binding were healthy. The final policy now does
  only what the project requires: allow the `192.168.122.1` libvirt gateway,
  drop guest traffic to RFC1918, Tailscale CGNAT, and link-local IPv4, then
  permit public Internet traffic. The provisional port allowlist was removed
  because it was unnecessary and brittle under the live backend.
- With the final filter active after a cold start, guest DNS resolved
  `api.github.com` and HTTPS returned GitHub's response. Control connections
  from mini succeeded to LAN gateway `192.168.1.1:80` and Tailscale SSH on
  home, laptop, and air; every matching guest connection timed out as blocked.
  Additional `10.0.0.1:443` and `172.16.0.1:443` probes were blocked.
- Guest inspection found no Tailscale command, package, or state directory.
  Docker was deliberately omitted because the manual Yahtzee smoke job does
  not need it. Git, curl, jq, CA certificates, and qemu-guest-agent are present.
- Yahtzee Actions remains enabled with read-only default workflow permissions
  and no permission to approve pull-request reviews. Changed the public-fork
  policy from first-time contributors to `all_external_contributors`, so every
  outside contributor requires approval if a future PR workflow is added.
- GitHub's current official runner release API reported v2.336.0, published
  2026-07-20. Its release notes publish Linux x64 SHA-256
  `04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d`.
  Added a registration script that verifies that checksum and runs the service
  as dedicated non-sudo user `actions`.
- The first registration attempt verified the 215 MiB archive, then stopped
  before extraction because `mktemp` made it unreadable by `actions`. GitHub
  still reported no registered runner. The public archive now changes to mode
  0644 only after checksum verification; a fresh token will be used on retry.
- A fresh token registered runner ID 21 as `mini-github-runner-01` with labels
  `self-hosted`, `Linux`, `X64`, `mini`, and `yahtzee`. GitHub reports it
  online and idle. The enabled systemd service runs v2.336.0 as non-sudo user
  `actions`; Docker is absent. The raw token scan passed before the process
  discarded the token, and no `.token` or `.pat` file exists under the install.
- Published Yahtzee commit
  `25446a700d935f4e415d3004abbc798094bdfe1c` with an actionlint configuration
  and one zero-permission `workflow_dispatch` workflow. `rg` found no
  `pull_request`, `pull_request_target`, push, schedule, or workflow-run trigger.
- Smoke run 32319363029 succeeded on job 96278270464 in three seconds and its
  log identified `mini-github-runner-01`, Linux, and X64.
  [Run 32319363029](https://github.com/HemSoft/yahtzee/actions/runs/32319363029)
- A clean guest reboot changed boot ID from
  `f5b18670-e4e3-4df6-9399-e35da23c5c63` to
  `328c6b5a-d28d-4d47-9714-886e762c5c93` and runner PID from 1975 to 735.
  The service returned enabled and active, GitHub returned online, isolation
  passed again, and post-reboot run 32319465237 succeeded on the same commit.
  [Run 32319465237](https://github.com/HemSoft/yahtzee/actions/runs/32319465237)
- The domain and default libvirt network are both configured for host-boot
  autostart. A full mini reboot was not needed and would disrupt unrelated host
  uptime; the safe guest reboot verified the runner's service recovery path.
- Added proven lifecycle, update, backup, unregister, and recovery commands to
  `SKILL.md`. PSScriptAnalyzer passed all 13 repository scripts, Markdown lint
  passed all 153 Markdown files, Bash syntax passed all four project scripts,
  `git diff --check` passed, and the credential-pattern scan found no secret.
- Live alias checks resolved laptop to `desktop-7es73q4`, air to
  `franzs-macbook-air`, and mini to `mini.tail3280fc.ts.net`. All three SSH
  checks succeeded; none had an existing `mini-github-runner` destination.
  Taildrop listed all three current targets.
- Created Taildrop archive SHA-256
  `0202099D73BAE79AB05756887D60AD567DD1E646F866C3CB8E9B94040B93A714`
  and installed it natively on laptop, air, and mini. Home remained the source
  installation. No destination copy existed, so no first-install backup was
  needed. All eight project files matched the source SHA-256 hashes on every
  target, and each machine natively read `SKILL.md` plus `Status: In progress`
  from `TODO.md`.
- Added `MANIFEST.sha256` for every project file except the manifest itself.
  This closes the source set that will be committed, checked by GitHub, and
  redistributed once more before the project status changes to complete.
- Skills commit `e9d613bbafa7f1333f892580e93be378fcbc15ed` passed Code
  Quality run 32319949897 and Quality Check run 32319949937.
- Redistributed that checked source to laptop, air, and mini. Each destination
  preserved one timestamped first-install backup, all nine source files matched
  across the four computers, and laptop, air, and mini each passed the manifest
  with native tools. These verified results satisfy every acceptance check and
  authorize this ledger's status change to `Complete`.
- Prepared a maintenance update that moves the skills workflows from
  `actions/checkout@v4` and `actions/setup-node@v4` to their current v7 majors,
  moves Markdown jobs from Node 20 to Node 24, and adds durable GitHub UI plus
  CLI monitoring instructions to `SKILL.md`.
- Published skills commit `3cc0d5f55d2bdf8c471c778c5a21efb1b4f825fa`.
  Code Quality run 32320950908, Copilot Setup Steps run 32320950897, and
  Quality Check run 32320950902 all succeeded with checkout v7, setup-node v7,
  and Node 24. Their logs contain no deprecated Node 20 action warning, forced
  Node 24 compatibility warning, or stale checkout/setup-node v4 reference.
- Provisioned the GH AW host runtime inside `github-runner-01` from Docker's
  signed Ubuntu repository. Installed Docker Engine 29.7.2, Compose 5.5.0,
  GitHub CLI 2.45.0, and ripgrep 14.1.0 without granting `actions` sudo.
- Added `actions` only to the guest-local Docker group and restarted the runner
  service. The live runner PID listed supplementary group 987, matching the
  mode 0660 `root:docker` socket, and `docker version` reported client and
  server 29.7.2 when executed as `actions`.
- `docker run --rm hello-world` succeeded as `actions`; GitHub API returned
  HTTP 200 and the unauthenticated GHCR v2 endpoint returned expected HTTP 401.
- Post-Docker isolation verification returned `ISOLATION_OK`: public DNS and
  HTTPS worked, LAN and all three tested tailnet SSH endpoints remained
  blocked, Tailscale remained absent, and `vnet2` retained
  `github-runner-locked`.
- Fresh smoke run 32323195241 succeeded on job 96289203353 in three seconds at
  commit `25446a700d935f4e415d3004abbc798094bdfe1c`.
  [Run 32323195241](https://github.com/HemSoft/yahtzee/actions/runs/32323195241)
- Added `scripts/prepare-gh-aw-runtime.sh` and ran it again against the already
  provisioned guest. Apt reported every selected package current, the service
  restart succeeded, and all four runtime version probes passed, proving the
  helper is idempotent on the live VM.
- The first cross-platform manifest check exposed CRLF path endings when Linux
  read the Windows-generated manifest. No source verification was claimed from
  that attempt. Rewrote `MANIFEST.sha256` with LF endings and then passed every
  listed hash natively on laptop, air, and mini.
- Laptop, air, and mini preserved timestamped pre-update skill backups, received
  the Docker-aware skill, and natively read `Status: In progress` after every
  source hash matched. This evidence authorizes the final status change and one
  final distribution of the closed source set.

## Current blockers

None. The GH AW host runtime, durable provisioning helper, documentation, and
fleet distribution are complete. Yahtzee workflow implementation now continues
in `D:\github\HemSoft\yahtzee\TODO.md`.
