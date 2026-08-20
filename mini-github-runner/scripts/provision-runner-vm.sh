#!/usr/bin/env bash
set -euo pipefail

vm_name="github-runner-01"
admin_user="runner-admin"
image_name="noble-server-cloudimg-amd64.img"
image_url="https://cloud-images.ubuntu.com/noble/current"
cache_dir="${HOME}/.cache/mini-github-runner"
key_path="${HOME}/.ssh/github-runner-01_ed25519"
disk_volume="${vm_name}.qcow2"
seed_volume="${vm_name}-seed.iso"
filter_name="github-runner-locked"

if virsh -c qemu:///system dominfo "${vm_name}" >/dev/null 2>&1; then
  echo "${vm_name} already exists; refusing to replace it." >&2
  exit 1
fi

mkdir -p "${cache_dir}" "${HOME}/.ssh"
chmod 0700 "${HOME}/.ssh"

if [[ ! -f "${key_path}" ]]; then
  ssh-keygen -q -t ed25519 -N '' -C "${admin_user}@${vm_name}" -f "${key_path}"
fi
chmod 0600 "${key_path}"
chmod 0644 "${key_path}.pub"

curl -fL --retry 3 --retry-delay 2 \
  -o "${cache_dir}/SHA256SUMS" "${image_url}/SHA256SUMS"
if ! (
  cd "${cache_dir}"
  grep " \*${image_name}$" SHA256SUMS | sha256sum --check --strict -
) >/dev/null 2>&1; then
  curl -fL --retry 3 --retry-delay 2 \
    -o "${cache_dir}/${image_name}" "${image_url}/${image_name}"
fi
(
  cd "${cache_dir}"
  grep " \*${image_name}$" SHA256SUMS | sha256sum --check --strict -
)

public_key=$(<"${key_path}.pub")
cat >"${cache_dir}/user-data" <<EOF
#cloud-config
hostname: ${vm_name}
manage_etc_hosts: true
ssh_pwauth: false
disable_root: true
users:
  - name: ${admin_user}
    gecos: GitHub runner administrator
    groups: [adm, sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - ${public_key}
package_update: true
package_upgrade: true
packages:
  - ca-certificates
  - curl
  - git
  - jq
  - qemu-guest-agent
runcmd:
  - [systemctl, enable, --now, qemu-guest-agent]
EOF

cat >"${cache_dir}/meta-data" <<EOF
instance-id: ${vm_name}-v1
local-hostname: ${vm_name}
EOF

cloud-localds "${cache_dir}/${seed_volume}" \
  "${cache_dir}/user-data" "${cache_dir}/meta-data"

cat >"${cache_dir}/${filter_name}.xml" <<'EOF'
<filter name='github-runner-locked' chain='root'>
  <rule action='accept' direction='out' priority='100'>
    <ip dstipaddr='192.168.122.1'/>
  </rule>
  <rule action='drop' direction='out' priority='200'>
    <ip dstipaddr='10.0.0.0' dstipmask='255.0.0.0'/>
  </rule>
  <rule action='drop' direction='out' priority='200'>
    <ip dstipaddr='100.64.0.0' dstipmask='255.192.0.0'/>
  </rule>
  <rule action='drop' direction='out' priority='200'>
    <ip dstipaddr='169.254.0.0' dstipmask='255.255.0.0'/>
  </rule>
  <rule action='drop' direction='out' priority='200'>
    <ip dstipaddr='172.16.0.0' dstipmask='255.240.0.0'/>
  </rule>
  <rule action='drop' direction='out' priority='200'>
    <ip dstipaddr='192.168.0.0' dstipmask='255.255.0.0'/>
  </rule>
  <rule action='accept' direction='inout' priority='1000'>
    <all/>
  </rule>
</filter>
EOF

if virsh -c qemu:///system nwfilter-dumpxml "${filter_name}" >/dev/null 2>&1; then
  virsh -c qemu:///system nwfilter-undefine "${filter_name}"
fi
virsh -c qemu:///system nwfilter-define "${cache_dir}/${filter_name}.xml"

if ! virsh -c qemu:///system pool-info default >/dev/null 2>&1; then
  virsh -c qemu:///system pool-define-as default dir \
    --target /var/lib/libvirt/images
fi
if [[ $(virsh -c qemu:///system pool-info default | awk '/^State:/ {print $2}') != "running" ]]; then
  virsh -c qemu:///system pool-start default
fi
virsh -c qemu:///system pool-autostart default
virsh -c qemu:///system pool-refresh default

for volume in "${disk_volume}" "${seed_volume}"; do
  if virsh -c qemu:///system vol-info --pool default "${volume}" >/dev/null 2>&1; then
    virsh -c qemu:///system vol-delete --pool default "${volume}"
  fi
done

virsh -c qemu:///system vol-create-as default "${disk_volume}" 100G \
  --allocation 0 --format qcow2
virsh -c qemu:///system vol-upload --pool default "${disk_volume}" \
  "${cache_dir}/${image_name}"
virsh -c qemu:///system vol-resize --pool default "${disk_volume}" 100G

seed_size=$(stat -c %s "${cache_dir}/${seed_volume}")
virsh -c qemu:///system vol-create-as default "${seed_volume}" "${seed_size}" \
  --allocation "${seed_size}" --format raw
virsh -c qemu:///system vol-upload --pool default "${seed_volume}" \
  "${cache_dir}/${seed_volume}"

virt-install --connect qemu:///system \
  --name "${vm_name}" \
  --memory 5120 \
  --vcpus 4 \
  --cpu host-passthrough \
  --osinfo ubuntu24.04 \
  --import \
  --disk "vol=default/${disk_volume},bus=virtio" \
  --disk "vol=default/${seed_volume},device=cdrom" \
  --network "network=default,model=virtio,filterref.filter=${filter_name}" \
  --graphics none \
  --console pty,target.type=serial \
  --noautoconsole

virsh -c qemu:///system autostart "${vm_name}"

echo "${vm_name} created and started."
virsh -c qemu:///system dominfo "${vm_name}"
virsh -c qemu:///system domiflist "${vm_name}"
