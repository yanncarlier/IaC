#!/bin/bash
# =============================================================================
# 04.0_opencLaw_backup.sh
# Run OUTSIDE the VM
# Backup OpenClaw
# =============================================================================
set -euo pipefail

VM_NAME="openclaw"
USER_HOME="root"
OPENCLAW_DIR="${USER_HOME}/.openclaw"

lxc exec ${VM_NAME} -- bash -c "openclaw gateway stop"
lxc exec ${VM_NAME} -- bash -c "tar -czf /root/${VM_NAME}-backup-\$(date '+%Y%m%d-%H%M').tar.gz -C /root/.openclaw ."
lxc exec ${VM_NAME} -- bash -c "openclaw gateway start"

# Get only the most recent backup file, strip any whitespace
BACKUP_FILE=$(lxc exec ${VM_NAME} -- bash -c "ls -t /root/${VM_NAME}-backup-*.tar.gz 2>/dev/null | head -1" | tr -d '[:space:]')

echo "Pulling: ${VM_NAME}${BACKUP_FILE}"
lxc file pull "${VM_NAME}${BACKUP_FILE}" .