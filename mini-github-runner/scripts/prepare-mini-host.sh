#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script through sudo." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  cloud-image-utils \
  libvirt-clients \
  libvirt-daemon-system \
  nftables \
  qemu-system-x86 \
  qemu-utils \
  virtinst

usermod -aG kvm,libvirt franz

systemctl enable --now libvirtd.service

if ! virsh net-info default >/dev/null 2>&1; then
  virsh net-define /usr/share/libvirt/networks/default.xml
fi

if [[ $(virsh net-info default | awk '/^Active:/ {print $2}') != "yes" ]]; then
  virsh net-start default
fi
virsh net-autostart default

install -d -o franz -g libvirt -m 0770 \
  /var/lib/libvirt/images/github-runner-01
touch /var/lib/libvirt/images/github-runner-01/.host-prepared
chown franz:libvirt /var/lib/libvirt/images/github-runner-01/.host-prepared

echo
echo "mini KVM host preparation completed."
virsh net-info default
systemctl --no-pager --full status libvirtd.service | sed -n '1,8p'
dpkg-query -W -f='${Package} ${Version}\n' \
  cloud-image-utils libvirt-clients libvirt-daemon-system nftables \
  qemu-system-x86 qemu-utils virtinst
