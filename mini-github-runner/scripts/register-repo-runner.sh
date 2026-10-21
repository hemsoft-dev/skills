#!/usr/bin/env bash
# Register a repository-scoped runner inside github-runner-01.
# Usage (run in the guest as runner-admin):
#   <token on the first stdin line> | register-repo-runner.sh OWNER/REPO RUNNER_NAME LABELS
# Example: ... | register-repo-runner.sh hemsoft-dev/project-manager mini-github-runner-01-pm mini,project-manager
# The short-lived registration token is read from stdin into memory only. It is
# never an argument, an environment variable of a child, or a file.
set -euo pipefail

repo="${1:?OWNER/REPO}"
runner_name="${2:?runner name}"
labels="${3:?labels}"
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "bad repository $repo" >&2; exit 2; }
IFS= read -r token
[ -n "$token" ] || { echo "no token on stdin" >&2; exit 2; }

runner_version="2.336.0"
runner_sha256="04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d"
runner_archive="actions-runner-linux-x64-${runner_version}.tar.gz"
runner_url="https://github.com/actions/runner/releases/download/v${runner_version}/${runner_archive}"
install_dir="/opt/actions-runner/${repo#*/}"
runner_user="actions"

id "${runner_user}" >/dev/null
sudo install -d -o "${runner_user}" -g "${runner_user}" -m 0750 "${install_dir}"
archive_path=$(mktemp)
trap 'rm -f "${archive_path}"' EXIT
curl -fsSL --retry 3 --retry-delay 2 -o "${archive_path}" "${runner_url}"
printf '%s  %s\n' "${runner_sha256}" "${archive_path}" | sha256sum --check --strict - >/dev/null
chmod 0644 "${archive_path}"
sudo -u "${runner_user}" tar -xzf "${archive_path}" -C "${install_dir}"
sudo "${install_dir}/bin/installdependencies.sh" >/dev/null

cd "${install_dir}"
sudo -u "${runner_user}" ./config.sh --url "https://github.com/${repo}" \
  --token "${token}" --name "${runner_name}" --labels "${labels}" \
  --work _work --unattended --replace >/dev/null
if sudo grep -RIlF -- "${token}" "${install_dir}" >/dev/null 2>&1; then
  echo "Registration token unexpectedly remained under ${install_dir}." >&2
  exit 1
fi
unset token

sudo ./svc.sh install "${runner_user}" >/dev/null
sudo ./svc.sh start >/dev/null
sudo systemctl is-active "$(sudo cat .service)"
echo "RUNNER_REGISTERED repo=${repo} name=${runner_name} version=${runner_version} dir=${install_dir}"
