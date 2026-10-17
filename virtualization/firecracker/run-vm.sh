#!/usr/bin/env bash
# run-vm.sh - Sets up host networking and boots the Firecracker microVM.
# Keep this running in one terminal; use connect.sh from another.
#
# Networking needs root. Without passwordless sudo this still boots the VM, but
# with no NIC (loopback only) -- use the serial console in this terminal.
set -euo pipefail

WORKDIR="${HOME}/firecracker-demo"
cd "${WORKDIR}"

TAP_DEV="tap0"
TAP_IP="172.16.0.1"
MASK_SHORT="/30"
GUEST_MAC="06:00:AC:10:00:02"   # the guest derives its IP (172.16.0.2) from this MAC
API_SOCKET="/tmp/firecracker.socket"

note() { printf 'NOTE: %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for f in vmlinux rootfs.ext4; do
  [ -e "${WORKDIR}/${f}" ] || die "${WORKDIR}/${f} missing -- run ./setup.sh first"
done
[ -r /dev/kvm ] && [ -w /dev/kvm ] \
  || die "/dev/kvm not usable by ${USER} -- run ./setup.sh first"

# --- Host networking --------------------------------------------------------
# iptables/ip/sysctl all need root. If we can't have it, boot without a NIC
# rather than failing outright: the microVM itself is the interesting part.
NET_MODE="none"
NET_CREATED=0

cleanup() {
  if [ "${NET_CREATED}" -eq 1 ]; then
    echo "Cleaning up network..."
    [ -n "${HOST_IFACE:-}" ] && sudo iptables -t nat -D POSTROUTING -o "${HOST_IFACE}" -j MASQUERADE 2>/dev/null || true
    sudo iptables -D FORWARD -i "${TAP_DEV}" -o "${HOST_IFACE}" -j ACCEPT 2>/dev/null || true
    sudo iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    sudo ip link del "${TAP_DEV}" 2>/dev/null || true
  fi
  rm -f "${API_SOCKET}"
}
trap cleanup EXIT

if sudo -n true 2>/dev/null; then
  HOST_IFACE="$(ip -j route list default | jq -r '.[0].dev')"
  [ -n "${HOST_IFACE}" ] && [ "${HOST_IFACE}" != "null" ] \
    || die "no default route found; cannot set up NAT for the guest."
  echo "Host outbound interface: ${HOST_IFACE}"

  sudo ip link del "${TAP_DEV}" 2>/dev/null || true
  sudo ip tuntap add dev "${TAP_DEV}" mode tap
  sudo ip addr add "${TAP_IP}${MASK_SHORT}" dev "${TAP_DEV}"
  sudo ip link set dev "${TAP_DEV}" up

  sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
  sudo iptables -t nat -A POSTROUTING -o "${HOST_IFACE}" -j MASQUERADE
  sudo iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  sudo iptables -I FORWARD 1 -i "${TAP_DEV}" -o "${HOST_IFACE}" -j ACCEPT
  NET_MODE="tap"
  NET_CREATED=1
else
  note "passwordless sudo unavailable -- booting WITHOUT a network device."
  note "the guest will only have 'lo', so connect.sh (SSH) will not work."
  note "interact over the serial console in this terminal instead."
  note "for SSH, re-run with sudo available (e.g. 'sudo -v' first)."
fi

# --- VM configuration -------------------------------------------------------
NET_BLOCK=""
if [ "${NET_MODE}" = "tap" ]; then
  NET_BLOCK="  \"network-interfaces\": [
    {
      \"iface_id\": \"eth0\",
      \"guest_mac\": \"${GUEST_MAC}\",
      \"host_dev_name\": \"${TAP_DEV}\"
    }
  ],"
fi

cat > "${WORKDIR}/vm_config.json" <<EOF
{
  "boot-source": {
    "kernel_image_path": "${WORKDIR}/vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off root=/dev/vda rw"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "${WORKDIR}/rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
${NET_BLOCK}
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024
  }
}
EOF

# --- Boot -------------------------------------------------------------------
rm -f "${API_SOCKET}"
if [ "${NET_MODE}" = "tap" ]; then
  echo "Booting microVM with tap networking (type 'reboot' inside the guest to shut it down)..."
else
  echo "Booting microVM, serial console attached (type 'reboot' inside the guest to shut it down)..."
fi
# Not `exec`: the EXIT trap must still run so cleanup() tears down the tap.
firecracker --api-sock "${API_SOCKET}" --config-file "${WORKDIR}/vm_config.json"