#!/usr/bin/env bash
# cleanup.sh - Tears down whatever run-vm.sh / setup.sh left behind:
# running microVMs, the API socket, the host tap device and NAT rules, and
# (with --purge) the downloaded images and workdir.
#
# Safe to run at any time -- everything it does is idempotent.
#
# Usage:
#   ./cleanup.sh            stop VMs, drop networking, remove the socket
#   ./cleanup.sh --purge    also delete ${WORKDIR} (images, rootfs, ssh key)
set -euo pipefail

WORKDIR="${HOME}/firecracker-demo"
TAP_DEV="tap0"
API_SOCKET="/tmp/firecracker.socket"
GUEST_IP="172.16.0.2"

PURGE=0
case "${1:-}" in
  --purge)   PURGE=1 ;;
  -h|--help) sed -n '2,10p' "$0" | sed 's/^#\{1,\} \{0,1\}//'; exit 0 ;;
  "")        ;;
  *)         echo "ERROR: unknown option '$1' (try --help)" >&2; exit 1 ;;
esac

have_sudo() { sudo -n true 2>/dev/null; }
note()      { printf 'NOTE: %s\n' "$*"; }
ok()        { printf '  removed %s\n' "$*"; }

# --- 1. Stop running microVMs ------------------------------------------------
# Try a graceful guest shutdown first so the rootfs isn't left dirty, then
# fall back to signals for anything that doesn't answer.
SHUTDOWN_CMD=(
  ssh -i "${WORKDIR}/vm_key" -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=2
)

echo "Stopping microVMs..."

# Graceful, in-guest shutdown (only reachable when TAP networking is up).
if [ -f "${WORKDIR}/vm_key" ] && ping -c1 -W1 "${GUEST_IP}" >/dev/null 2>&1; then
  "${SHUTDOWN_CMD[@]}" "root@${GUEST_IP}" 'sync; poweroff' >/dev/null 2>&1 \
    && echo "  asked the guest to power off"
fi

# Match on the executable name, not a substring of the command line, so we never
# hit a shell that merely mentions firecracker (including this script itself).
# Matches both run-vm.sh's VMM and any hand-rolled `firecracker --api-sock`.
mapfile -t FC_PIDS < <(
  pgrep -x firecracker 2>/dev/null | while read -r p; do
    # Only ours: this socket, or this workdir, or a bare instance with no
    # args pointing elsewhere. Skip anything referencing someone else's path.
    if tr '\0' ' ' < "/proc/${p}/cmdline" 2>/dev/null \
       | grep -qE -- "--api-sock(=| )${API_SOCKET}( |$)|${WORKDIR}"; then
      echo "$p"
    fi
  done | sort -u
)

if [ "${#FC_PIDS[@]}" -gt 0 ]; then
  printf '  signalling %d firecracker process(es): %s\n' \
    "${#FC_PIDS[@]}" "${FC_PIDS[*]}"
  # Ask the API for a graceful guest shutdown first when the socket is live --
  # that syncs the guest filesystem. SIGINT is the fallback; SIGKILL last.
  if [ -S "${API_SOCKET}" ]; then
    curl -s -m 5 --unix-socket "${API_SOCKET}" -X PUT http://localhost/actions \
      -H 'Content-Type: application/json' \
      -d '{"action_type":"SendCtrlAltDel"}' >/dev/null 2>&1 \
      && echo "  requested guest shutdown via the API"
  fi
  kill -INT "${FC_PIDS[@]}" 2>/dev/null || true
  for _ in $(seq 1 15); do
    sleep 1
    still=()
    for p in "${FC_PIDS[@]}"; do kill -0 "$p" 2>/dev/null && still+=("$p"); done
    [ "${#still[@]}" -eq 0 ] && break
  done
  still=()
  for p in "${FC_PIDS[@]}"; do kill -0 "$p" 2>/dev/null && still+=("$p"); done
  if [ "${#still[@]}" -gt 0 ]; then
    echo "  escalating to SIGKILL: ${still[*]}"
    kill -KILL "${still[@]}" 2>/dev/null || true
    sleep 1
  fi
  ok "running microVMs"
else
  echo "  none running"
fi

# A dead firecracker leaves the socket file behind; -f keeps this idempotent.
if [ -e "${API_SOCKET}" ] || [ -S "${API_SOCKET}" ]; then
  rm -f "${API_SOCKET}" && ok "${API_SOCKET}"
fi

# --- 2. Host networking ------------------------------------------------------
# Must mirror what run-vm.sh added. Every step tolerates being absent so this
# is safe to run after a crash, or twice in a row.
echo "Cleaning up host networking..."

if ! have_sudo; then
  note "passwordless sudo unavailable -- cannot touch iptables or the tap device."
  note "if a stale tap is in the way, run this script with sudo available:"
  note "  sudo $0"
else
  # Only remove NAT/FORWARD rules if they actually reference our tap.
  HOST_IFACE="$(ip -j route list default 2>/dev/null | jq -r '.[0].dev // empty')"
  [ -n "${HOST_IFACE}" ] || HOST_IFACE=""

  if ip link show "${TAP_DEV}" >/dev/null 2>&1; then
    sudo iptables -t nat -D POSTROUTING -o "${HOST_IFACE}" -j MASQUERADE 2>/dev/null || true
    sudo iptables -D FORWARD -i "${TAP_DEV}" -o "${HOST_IFACE}" -j ACCEPT 2>/dev/null || true
    sudo iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    sudo ip link del "${TAP_DEV}" 2>/dev/null || true
    ip link show "${TAP_DEV}" >/dev/null 2>&1 || ok "${TAP_DEV}"
  else
    echo "  no ${TAP_DEV} device"
  fi

  # ip_forward is a global host setting, not ours to revert blindly -- report it.
  if [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 0)" = "1" ]; then
    note "net.ipv4.ip_forward is still 1 (host-wide). To disable:"
    note "  sudo sysctl -w net.ipv4.ip_forward=0"
  fi
fi

# --- 3. Optionally purge the workdir ----------------------------------------
# Skipped unless --purge: this deletes the ~600 MB of images and the ssh key.
if [ "${PURGE}" -eq 1 ]; then
  echo "Purging ${WORKDIR}..."
  if [ -d "${WORKDIR}" ]; then
    du -sh "${WORKDIR}" 2>/dev/null | sed 's/^/  freeing /'
    rm -rf "${WORKDIR}" && ok "${WORKDIR}"
  else
    echo "  ${WORKDIR} does not exist"
  fi
  # setup.sh leaves these behind too when re-run.
  rm -rf "${WORKDIR}.tmp" 2>/dev/null || true
else
  echo
  echo "Leaving ${WORKDIR} in place (images, rootfs, ssh key)."
  echo "Run './cleanup.sh --purge' to delete it as well."
fi

echo
echo "Cleanup complete."