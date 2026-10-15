#!/bin/bash
# =============================================================================
# 
# Run this on your UBUNTU HOST (not inside the VM)
# 
#
# SPICE note: LXD automatically creates a SPICE unix socket — do NOT add
# a -spice flag via raw.qemu or QEMU will fail with a duplicate -spice error.
# Connect with:
#   lxc console ${STATUS} --type=vga
#   remote-viewer spice+unix:///var/snap/lxd/common/lxd/logs/${STATUS}/qemu.spice
# =============================================================================

set -euo pipefail

VM_NAME="ocvm01"
VM_USER="root" # User to run the scripts inside the VM

echo "============================================="
echo " OpenClaw LXD VM 02.0_host_config_and_start.sh "
echo "============================================="

# ── 1. Confirm VM exists and is stopped ───────────────────────────────────────
STATUS=$(lxc list "${VM_NAME}" --format csv --columns s 2>/dev/null | head -1)
if [[ -z "${STATUS}" ]]; then
  echo "[!] VM '${VM_NAME}' not found. Run 01_host_create_vm.sh first."
  exit 1
fi
if [[ "${STATUS}" != "STOPPED" ]]; then
  echo "[!] VM '${VM_NAME}' is not stopped (status: ${STATUS})."
  echo "    Running: lxc stop ${VM_NAME}"
  # ── Stop VM cleanly so step can apply boot-time config ───────────────────
  echo "[*] Stopping VM cleanly for config phase..."
  lxc stop "${VM_NAME}"
  # exit 1
fi

# ── 2. Apply boot-time config ─────────────────────────────────────────────────
# NOTE: Do NOT inject -spice via raw.qemu.
#       LXD already adds its own SPICE unix socket in qemu.conf automatically.
#       Adding a second -spice flag causes QEMU to exit with status 1.
echo "[*] Applying boot-time VM config..."
lxc config set "${VM_NAME}" boot.autostart true
lxc config set "${VM_NAME}" boot.autostart.delay 5

# ── 3. Start VM ───────────────────────────────────────────────────────────────
echo "[*] Starting VM..."
lxc start "${VM_NAME}"
echo "[*] Waiting for VM to boot (30s)..."
sleep 30

# ── 4. Push in-VM setup script ────────────────────────────────────────────────
echo "[*] Pushing in-VM setup script..."
lxc file push 03.0_vm_setup.sh "${VM_NAME}/${VM_USER}/03.0_vm_setup.sh"
lxc file push 04.0_vm_setup.sh "${VM_NAME}/${VM_USER}/04.0_vm_setup.sh"
lxc file push 05.0_openclaw_configure.sh "${VM_NAME}/${VM_USER}/05.0_openclaw_configure.sh"
lxc file push 06.0_inject_computer_use_tools.sh "${VM_NAME}/${VM_USER}/06.0_inject_computer_use_tools.sh"

lxc exec "${VM_NAME}" -- chmod +x /${VM_USER}/03.0_vm_setup.sh
lxc exec "${VM_NAME}" -- chmod +x /${VM_USER}/04.0_vm_setup.sh
lxc exec "${VM_NAME}" -- chmod +x /${VM_USER}/05.0_openclaw_configure.sh

# ── 5. Print connection info ──────────────────────────────────────────────────
SPICE_SOCK="/var/snap/lxd/common/lxd/logs/${VM_NAME}/qemu.spice"

echo ""
echo "============================================="
echo " VM is running. Connect via:"
echo "============================================="
echo ""
echo "  VGA console (simplest):"
echo "    lxc console ${VM_NAME} --type=vga"
echo ""
echo "  SPICE unix socket:"
echo "    remote-viewer spice+unix://${SPICE_SOCK}"
echo "    (install: sudo apt install virt-viewer)"
echo ""
echo "  Shell:"
echo "    lxc exec ${VM_NAME} -- bash"
echo ""