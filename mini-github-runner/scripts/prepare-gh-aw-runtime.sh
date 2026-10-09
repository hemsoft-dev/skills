#!/usr/bin/env bash
set -euo pipefail

runner_user=${RUNNER_USER:-actions}
runner_service=${RUNNER_SERVICE:-}
validate_runner_service() {
  if [[ -n "${runner_service}" && ! "${runner_service}" =~ ^actions\.runner\.[A-Za-z0-9_.-]+\.service$ ]]; then
    echo "Invalid runner service name" >&2
    exit 1
  fi
}
validate_runner_service

if ! id "${runner_user}" >/dev/null 2>&1; then
  echo "Runner user does not exist: ${runner_user}" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings

key_tmp=$(mktemp)
trap 'rm -f "${key_tmp}"' EXIT
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "${key_tmp}"
sudo install -m 0644 "${key_tmp}" /etc/apt/keyrings/docker.asc

architecture=$(dpkg --print-architecture)
. /etc/os-release
codename=${UBUNTU_CODENAME:-${VERSION_CODENAME}}

printf '%s\n' \
  'Types: deb' \
  'URIs: https://download.docker.com/linux/ubuntu' \
  "Suites: ${codename}" \
  'Components: stable' \
  "Architectures: ${architecture}" \
  'Signed-By: /etc/apt/keyrings/docker.asc' |
  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  containerd.io \
  docker-buildx-plugin \
  docker-ce \
  docker-ce-cli \
  docker-compose-plugin \
  gh \
  ripgrep

sudo usermod -aG docker "${runner_user}"
sudo systemctl enable --now docker

# Provisioning runs before registration on a fresh guest, so .service may not
# exist yet. Registered runners retain their generated unit across owner moves.
runner_service_file="${RUNNER_DIRECTORY:-/opt/actions-runner/yahtzee}/.service"
if [[ -z "${runner_service}" ]] && sudo test -f "${runner_service_file}"; then
  runner_service=$(sudo cat "${runner_service_file}")
  validate_runner_service
fi
if [[ -n "${runner_service}" ]] && systemctl cat "${runner_service}" >/dev/null 2>&1; then
  sudo systemctl restart "${runner_service}"
fi

sudo -u "${runner_user}" -H docker version --format \
  'client={{.Client.Version}} server={{.Server.Version}}'
sudo -u "${runner_user}" -H docker compose version
sudo -u "${runner_user}" -H rg --version | head -1
sudo -u "${runner_user}" -H gh --version | head -1

