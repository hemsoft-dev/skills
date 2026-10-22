#!/usr/bin/env bash
# Register a repository-scoped runner inside github-runner-01.
# Usage (run in the guest as runner-admin):
#   <token on the first stdin line> | register-repo-runner.sh OWNER/REPO RUNNER_NAME LABELS
# Example: ... | register-repo-runner.sh hemsoft-dev/project-manager mini-github-runner-01-pm mini,project-manager
# Each repository runner runs as its own Unix account (actions-<repo>), so a
# job from one repository (Yahtzee is public) cannot read another runner's
# processes or files. The short-lived registration token is read from stdin
# into memory only. It is never an argument or a file: config.sh gets it
# through its ACTIONS_RUNNER_INPUT_TOKEN environment variable, which only that
# account and root can read. Root never executes a file the runner account
# could have changed: the archive is unpacked and its dependency installer run
# while the tree is root-owned, and the systemd unit is written here instead
# of by the archive's svc.sh.
set -euo pipefail

repo="${1:?OWNER/REPO}"
runner_name="${2:?runner name}"
labels="${3:?labels}"
[[ "$repo" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$ ]] || { echo "bad repository $repo" >&2; exit 2; }
case "${repo#*/}" in .|..) echo "bad repository $repo" >&2; exit 2 ;; esac
# The name becomes part of a systemd unit name and a path, so restrict it to
# characters both accept, and keep the unit name within systemd's 255 bytes.
[[ "$runner_name" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$ ]] || { echo "bad runner name $runner_name" >&2; exit 2; }
IFS= read -r token
[ -n "$token" ] || { echo "no token on stdin" >&2; exit 2; }

runner_version="2.336.0"
runner_sha256="04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d"
runner_archive="actions-runner-linux-x64-${runner_version}.tar.gz"
runner_url="https://github.com/actions/runner/releases/download/v${runner_version}/${runner_archive}"
owner="${repo%%/*}"
name="${repo#*/}"
install_dir="/opt/actions-runner/${name}"
runner_user=$(printf 'actions-%s' "${name,,}" | tr -c 'a-z0-9-' '-' | cut -c1-32)
unit="actions.runner.${owner}-${name}.${runner_name}.service"
[ "${#unit}" -le 255 ] || { echo "unit name too long: ${unit}" >&2; exit 2; }
# Root-owned records the runner account cannot change: which repository owns
# each account, and which unit each runner directory has.
records=/etc/actions-runner

# Refuse an already configured directory before touching it: config.sh
# rejects a configured installation even with --replace, and the directory is
# keyed by the repository name alone, so it may belong to another OWNER/REPO.
# To re-register, stop and disable the unit and run config.sh remove first.
if sudo test -e "${install_dir}/.runner"; then
  existing=$(sudo sed -n 's/.*"gitHubUrl": *"\([^"]*\)".*/\1/p' "${install_dir}/.runner" | tr -d '\r')
  echo "${install_dir} is already configured for ${existing:-an unknown repository}; remove that runner first" >&2
  exit 2
fi
# Any existing tree may have been written by a runner account; root runs the
# archive's installer from this directory, so it must be created fresh.
if sudo test -e "${install_dir}"; then
  echo "${install_dir} already exists; unregister removes it, so remove it before registering" >&2
  exit 2
fi
# Dots and hyphens make owner, repo and runner name ambiguous inside a unit
# name; refuse one that another runner already uses.
if sudo test -e "/etc/systemd/system/${unit}" || sudo grep -qxF -- "${unit}" "${records}"/units/* 2>/dev/null; then
  echo "unit ${unit} is already in use" >&2
  exit 2
fi
# The account name is derived and truncated, so two repositories could map to
# the same one. Root records the repository each account was created for, in
# a directory the account cannot write, and an account owned by another
# repository (or with no record) is refused.
sudo install -d -o root -g root -m 0755 "${records}" "${records}/accounts" "${records}/units"
marker="${records}/accounts/${runner_user}"
if id "${runner_user}" >/dev/null 2>&1; then
  owned_by=$(sudo cat "${marker}" 2>/dev/null || true)
  if [ "${owned_by,,}" != "${repo,,}" ]; then
    echo "account ${runner_user} belongs to ${owned_by:-an unknown owner}, not ${repo}; choose another layout" >&2
    exit 2
  fi
else
  sudo useradd --system --create-home --home-dir "/home/${runner_user}" --shell /usr/sbin/nologin "${runner_user}"
  printf '%s\n' "${repo}" | sudo tee "${marker}" >/dev/null
  sudo chmod 0644 "${marker}"
fi

# The verified archive is cached in a root-owned directory, so a retry after
# an expired registration token (it lasts an hour) does not download it again.
cache=/var/cache/actions-runner
archive_path="${cache}/${runner_archive}"
# If registration fails before the runner is configured (expired token, name
# in use, GitHub unreachable), remove the tree this run created, so a retry is
# not refused by the fresh-directory check.
created=0
cleanup() {
  if [ "${created}" = 1 ] && ! sudo test -e "${install_dir}/.runner"; then
    sudo rm -rf --one-file-system "${install_dir}"
    sudo rm -f "/etc/systemd/system/${unit}" "${records}/units/${name}"
  fi
}
trap cleanup EXIT
sudo install -d -o root -g root -m 0755 "${cache}"
if ! printf '%s  %s\n' "${runner_sha256}" "${archive_path}" | sha256sum --check --strict --status - 2>/dev/null; then
  download=$(mktemp)
  curl -fsSL --retry 3 --retry-delay 2 -o "${download}" "${runner_url}"
  printf '%s  %s\n' "${runner_sha256}" "${download}" | sha256sum --check --strict - >/dev/null
  sudo install -o root -g root -m 0644 "${download}" "${archive_path}"
  rm -f "${download}"
fi
# Unpack and install dependencies while only root can write the tree.
sudo install -d -o root -g root -m 0755 /opt/actions-runner
sudo install -d -o root -g root -m 0755 "${install_dir}"
created=1
sudo tar -xzf "${archive_path}" -C "${install_dir}" --no-same-owner
sudo "${install_dir}/bin/installdependencies.sh" >/dev/null
sudo install -m 0755 "${install_dir}/bin/runsvc.sh" "${install_dir}/runsvc.sh"
# From here root only runs systemctl and fixed commands, never the tree's files.
sudo chown -R "${runner_user}:${runner_user}" "${install_dir}"
sudo chmod 0750 "${install_dir}"

# Write the unit and root's records before configuring: once config.sh has
# created .runner the EXIT trap keeps the tree, and the Unregister procedure
# needs these records to clean up a registration that fails after that point.
sudo tee "/etc/systemd/system/${unit}" >/dev/null <<UNIT
[Unit]
Description=GitHub Actions Runner (${repo} ${runner_name})
After=network-online.target

[Service]
ExecStart=${install_dir}/runsvc.sh
User=${runner_user}
WorkingDirectory=${install_dir}
# mixed: SIGTERM to the listener, then the whole cgroup is killed, so no job
# process outlives the service.
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=5min

[Install]
WantedBy=multi-user.target
UNIT
printf '%s\n' "${unit}" | sudo tee "${install_dir}/.service" "${records}/units/${name}" >/dev/null

ACTIONS_RUNNER_INPUT_TOKEN="${token}" sudo --preserve-env=ACTIONS_RUNNER_INPUT_TOKEN -u "${runner_user}" \
  bash -c 'cd "$1" && shift && exec ./config.sh "$@"' _ "${install_dir}" \
  --url "https://github.com/${repo}" --name "${runner_name}" --labels "${labels}" \
  --work _work --unattended >/dev/null
if printf '%s\n' "${token}" | sudo grep -RIlF -f - "${install_dir}" >/dev/null 2>&1; then
  echo "Registration token unexpectedly remained under ${install_dir}." >&2
  exit 1
fi
unset token

sudo systemctl daemon-reload
sudo systemctl enable --now "${unit}" >/dev/null 2>&1
sudo systemctl is-active "${unit}"
echo "RUNNER_REGISTERED repo=${repo} name=${runner_name} version=${runner_version} dir=${install_dir} user=${runner_user} unit=${unit}"
