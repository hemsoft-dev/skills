#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_REGISTRATION_TOKEN:?Pass the short-lived token through the process environment.}"

runner_version="2.336.0"
runner_sha256="04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d"
runner_archive="actions-runner-linux-x64-${runner_version}.tar.gz"
runner_url="https://github.com/actions/runner/releases/download/v${runner_version}/${runner_archive}"
install_dir="/opt/actions-runner/yahtzee"
runner_user="actions"

if ! id "${runner_user}" >/dev/null 2>&1; then
  sudo useradd --system --create-home --home-dir /home/actions \
    --shell /bin/bash "${runner_user}"
fi

sudo install -d -o "${runner_user}" -g "${runner_user}" -m 0750 \
  "${install_dir}"

archive_path=$(mktemp)
trap 'rm -f "${archive_path}"' EXIT
curl -fL --retry 3 --retry-delay 2 -o "${archive_path}" "${runner_url}"
printf '%s  %s\n' "${runner_sha256}" "${archive_path}" | sha256sum --check --strict -
chmod 0644 "${archive_path}"

sudo -u "${runner_user}" tar -xzf "${archive_path}" -C "${install_dir}"
sudo "${install_dir}/bin/installdependencies.sh"

sudo -u "${runner_user}" "${install_dir}/config.sh" \
  --url https://github.com/hemsoft-dev/yahtzee \
  --token "${RUNNER_REGISTRATION_TOKEN}" \
  --name mini-github-runner-01 \
  --labels mini,yahtzee \
  --work _work \
  --unattended \
  --replace

if sudo grep -RIlF -- "${RUNNER_REGISTRATION_TOKEN}" "${install_dir}" \
  >/dev/null 2>&1; then
  echo "Registration token unexpectedly remained under ${install_dir}." >&2
  exit 1
fi
unset RUNNER_REGISTRATION_TOKEN

cd "${install_dir}"
sudo ./svc.sh install "${runner_user}"
sudo ./svc.sh start
sudo ./svc.sh status

echo "RUNNER_REGISTERED version=${runner_version} user=${runner_user}"
