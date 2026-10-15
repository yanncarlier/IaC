#!/bin/bash
# =============================================================================
# 
# Run this INSIDE the LXD VM (as root or with sudo)
# Installs Hermes Agent on Ubuntu 24.04 minimal
# =============================================================================

set -euo pipefail

echo "============================================="
echo " Hermes Agent VM — In-VM Setup Script"
echo "============================================="

export DEBIAN_FRONTEND=noninteractive

# ── 1. Update system ──────────────────────────────────────────────────────────
echo "[1/6] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Install base packages ─────────────────────────────────────────────────
echo "[2/6] Installing base packages..."
apt-get install -y -qq \
  curl \
  wget \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  build-essential \
  tar \
  gzip \
  unzip \
  sudo \
  openssh-server \
  iproute2 \
  procps

# Ensure SSH is enabled for remote access during setup
systemctl enable ssh
systemctl start ssh

# ── 3. Install Node.js 20 ─────────────────────────────────────────────
echo "[3/6] Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y -qq nodejs

# ── 4. Install desktop environment ───────────────────────────────────────────
echo "[4/6] Installing XFCE desktop environment..."
apt-get install -y -qq \
  xfce4 \
  xfce4-terminal \
  xfce4-screenshooter \
  lightdm \
  lightdm-gtk-greeter \
  dbus-x11 \
  at-spi2-core

systemctl enable lightdm
systemctl restart lightdm

# ── 5. Install Google Chrome ──────────────────────────────────────────────────
echo "[5/6] Installing Google Chrome..."
apt-get install -y -qq wget curl gnupg ca-certificates

wget -qO /tmp/chrome.deb \
  "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

apt-get install -y -qq /tmp/chrome.deb || \
  (apt-get install -y -f -qq && apt-get install -y -qq /tmp/chrome.deb)

rm /tmp/chrome.deb

# ── 6. Install Chromium ──────────────────────────────────────────────────
echo "[6/6] Installing Chromium..."
apt-get install -y -qq chromium-browser

echo ""
echo "============================================="
echo " Hermes Agent base system setup complete!"
echo "============================================="
echo ""
echo "Next steps:"
echo "  Run hermes-03.1_vm_setup.sh to create the hermes user and install Hermes Agent"
echo ""