---
name: mini-github-runner
description: "V1.0 - Commands: Status, Plan, Provision, Register, Verify, Distribute. Build and maintain the isolated GitHub Actions runner hosted on mini, with implementation state tracked in TODO.md."
disable-model-invocation: true
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the mini-github-runner directory, verify that history logging occurred.

            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp obtained with Get-Date -Format "HH:mm", never guessed

            If history is missing or incomplete, state exactly what needs to be added.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping after mini-github-runner was used, verify all of the following:

            1. TODO.md reflects the current implementation state and evidence.
            2. History/{YYYY-MM-DD}.md contains an entry in the format "## HH:MM - {Action Taken}" using a timestamp obtained with Get-Date -Format "HH:mm".
            3. No completed checkbox relies on planned or assumed work.

            If any check fails, block completion and identify the missing update.
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
- Runtime: the GitHub runner and optional Docker engine run inside the guest, never as `franz` on the host.
- Scope: repository-level registrations under the personal `HemSoft` account.
- Secrets: never write registration tokens, credentials, or private keys into this skill, `TODO.md`, history, logs, or shell output.

## Commands

### Status

Read `TODO.md`, inspect `mini`, the guest, GitHub runner registration, and relevant workflow runs. Report verified state separately from pending work.

### Plan

Refine `TODO.md` without changing infrastructure. Record decisions that affect runner scope, guest resources, isolation, or repositories.

### Provision

Complete the next unchecked host or guest provisioning item. Use the `fleet` skill for remote access. Stop for an interactive sudo prompt when required. Do not weaken SSH, Tailscale, or host firewall policy to avoid that prompt.

### Register

Require an exact `OWNER/REPOSITORY`. Confirm the repository owner and authenticated GitHub account before requesting a short-lived registration token. Register a distinct runner service for each repository and discard the token after use.

### Verify

Prove the service is online, run a harmless repository workflow on the self-hosted label, confirm the expected runner handled it, and check that the guest cannot reach the tailnet or home LAN. Record workflow and runner evidence in `TODO.md`.

### Distribute

Distribute only after implementation and validation are complete. Install the skill on `home`, `laptop`, `air`, and `mini` under each user's `.agents/skills/mini-github-runner/`. Use the `fleet` skill's approved transport and verify SHA-256 hashes plus a native read of `SKILL.md` and `TODO.md` on every destination. The iPhone is not a skill host.

## Safety rules

- Never run pull-request code from untrusted contributors on a persistent runner.
- Keep GitHub token permissions at the workflow minimum.
- Do not mount the host filesystem or host Docker socket into the guest.
- Do not give the guest a route to `100.64.0.0/10` or local private subnets.
- Preserve unrelated changes in the shared skills repository.
- Do not claim completion from package delivery alone. Native installation and verification are required.

## Completion

The project is complete only when every acceptance item in `TODO.md` is checked, the smoke workflow passes, isolation tests pass, and all skill-capable fleet computers have matching skill hashes.
