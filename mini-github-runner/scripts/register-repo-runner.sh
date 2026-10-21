#!/usr/bin/env bash
# Register a repository-scoped runner inside github-runner-01.
# Usage (run in the guest as runner-admin):
#   <token on the first stdin line> | register-repo-runner.sh OWNER/REPO RUNNER_NAME LABELS
# Example: ... | register-repo-runner.sh hemsoft-dev/project-manager mini-github-runner-01-pm mini,project-manager
# The short-lived registration token is read from stdin into memory only. It is
# never an argument or a file: config.sh gets it through its
# ACTIONS_RUNNER_INPUT_TOKEN environment variable, which only the runner user
# and root can read.
set -euo pipefail

repo="${1:?OWNER/REPO}"
runner_name="${2:?runner name}"
labels="${3:?labels}"
[[ "$repo" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$ ]] || { echo "bad repository $repo" >&2; exit 2; }
case "${repo#*/}" in .|..) echo "bad repository $repo" >&2; exit 2 ;; esac
IFS= read -r token
[ -n "$token" ] || { echo "no token on stdin" >&2; exit 2; }

runner_version="2.336.0"
runner_sha256="04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d"
runner_archive="actions-runner-linux-x64-${runner_version}.tar.gz"
runner_url="https://github.com/actions/runner/releases/download/v${runner_version}/${runner_archive}"
install_dir="/opt/actions-runner/${repo#*/}"
runner_user="actions"

id "${runner_user}" >/dev/null
# The directory is keyed by the repository name alone (the existing layout),
# so refuse one that already belongs to a different OWNER/REPO.
if sudo test -f "${install_dir}/.runner"; then
  existing=$(sudo sed -n 's/.*"gitHubUrl": *"\([^"]*\)".*/\1/p' "${install_dir}/.runner" | tr -d '\r')
  if [ "${existing,,}" != "https://github.com/${repo,,}" ]; then
    echo "${install_dir} already belongs to ${existing:-another runner}" >&2
    exit 2
  fi
fi
sudo install -d -o "${runner_user}" -g "${runner_user}" -m 0750 "${install_dir}"
archive_path=$(mktemp)
trap 'rm -f "${archive_path}"' EXIT
curl -fsSL --retry 3 --retry-delay 2 -o "${archive_path}" "${runner_url}"
printf '%s  %s\n' "${runner_sha256}" "${archive_path}" | sha256sum --check --strict - >/dev/null
chmod 0644 "${archive_path}"
sudo -u "${runner_user}" tar -xzf "${archive_path}" -C "${install_dir}"
sudo "${install_dir}/bin/installdependencies.sh" >/dev/null

# runner-admin cannot enter the 0750 actions-owned directory, so every step
# that runs from it changes directory as the runner user or root.
ACTIONS_RUNNER_INPUT_TOKEN="${token}" sudo --preserve-env=ACTIONS_RUNNER_INPUT_TOKEN -u "${runner_user}" \
  bash -c 'cd "$1" && shift && exec ./config.sh "$@"' _ "${install_dir}" \
  --url "https://github.com/${repo}" --name "${runner_name}" --labels "${labels}" \
  --work _work --unattended --replace >/dev/null
if printf '%s\n' "${token}" | sudo grep -RIlF -f - "${install_dir}" >/dev/null 2>&1; then
  echo "Registration token unexpectedly remained under ${install_dir}." >&2
  exit 1
fi
unset token

sudo bash -c 'cd "$1" && ./svc.sh install "$2" && ./svc.sh start' _ "${install_dir}" "${runner_user}" >/dev/null
sudo systemctl is-active "$(sudo cat "${install_dir}/.service")"
echo "RUNNER_REGISTERED repo=${repo} name=${runner_name} version=${runner_version} dir=${install_dir}"
