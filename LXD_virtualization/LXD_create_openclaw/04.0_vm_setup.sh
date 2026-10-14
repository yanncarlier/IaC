#!/bin/bash
# =============================================================================
# 02.1_vm_setup.sh
# Run this INSIDE the LXD VM (as root or with sudo)
# Configures SSH server and UFW firewall for secure access
# =============================================================================

set -euo pipefail

APP_USER="openclaw"
VM_NAME="ocvm01"


echo "============================================="
echo " OpenClaw VM — SSH & Firewall Setup"
echo "============================================="

export DEBIAN_FRONTEND=noninteractive

# ── 1. Install and configure OpenSSH server ───────────────────────────────────
echo "[1/4] Installing and configuring OpenSSH server..."
apt-get update -qq
apt-get install -y -qq openssh-server

# Enable and start SSH service
systemctl enable ssh
systemctl start ssh

# Configure SSH for security (optional hardening)
# Allow password authentication for initial access
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Restart SSH to apply changes
systemctl restart ssh

echo "SSH server installed and started on port 22"

# ── 2. Install UFW firewall ───────────────────────────────────────────────────
echo "[2/4] Installing UFW firewall..."
apt-get install -y -qq ufw

# ── 3. Configure UFW to allow only IPv4 SSH ───────────────────────────────────
echo "[3/4] Configuring UFW to allow only IPv4 SSH on port 22..."

# Disable IPv6 in UFW to allow only IPv4 rules
sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH on port 22 (only IPv4 since IPv6 disabled)
ufw allow 22/tcp

# ── 4. Enable UFW ────────────────────────────────────────────────────────────
echo "[4/4] Enabling UFW firewall..."
ufw --force enable

echo "UFW enabled with SSH access allowed on IPv4 port 22"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================="
echo " SSH & Firewall setup complete!"
echo "============================================="
echo ""
echo " You can now connect via SSH:"
echo "  ssh ${APP_USER}@<VM_IP>"
echo "  (Password: ${APP_USER})"
echo ""
echo "  ssh -L 18789:127.0.0.1:18789 ${APP_USER}@<VM_IP>"
echo ""
echo " Firewall status: $(ufw status | grep -E '(Status|22)')"
echo ""