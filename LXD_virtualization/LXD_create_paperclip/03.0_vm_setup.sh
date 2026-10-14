#!/bin/bash
# =============================================================================
# 
# Run this INSIDE the LXD VM (as root or with sudo)
# Installs Paperclip on Ubuntu 24.04 minimal
# =============================================================================

set -euo pipefail

echo "============================================="
echo " Paperclip VM — In-VM Setup Script"
echo "============================================="

export DEBIAN_FRONTEND=noninteractive

APP_USER="paperclip"
USER_HOME="/home/${APP_USER}"
REPO_URL="https://github.com/paperclipai/paperclip.git"
REPO_DIR="${USER_HOME}/paperclip"

COREPACK_PNPM_VERSION="9.15.0"

ensure_user() {
  if id "${APP_USER}" &>/dev/null; then
    return
  fi
  useradd -m -s /bin/bash -G sudo "${APP_USER}"
  echo "${APP_USER}:${APP_USER}" | chpasswd
}

run_as_user() {
  runuser -l "${APP_USER}" -c "$1"
}

# ── 1. Update system ──────────────────────────────────────────────────────────
echo "[1/7] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Install base packages ─────────────────────────────────────────────────
echo "[2/7] Installing base packages..."
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

# ── 3. Install Node.js 20 and pnpm ─────────────────────────────────────────────
echo "[3/7] Installing Node.js 20 and pnpm ${COREPACK_PNPM_VERSION}..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y -qq nodejs

corepack enable
corepack prepare pnpm@"${COREPACK_PNPM_VERSION}" --activate

# ── 4. Install desktop environment ───────────────────────────────────────────
echo "[4/7] Installing XFCE desktop environment..."
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
echo "[5/7] Installing Google Chrome..."
apt-get install -y -qq wget curl gnupg ca-certificates

wget -qO /tmp/chrome.deb \
  "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

apt-get install -y -qq /tmp/chrome.deb || \
  (apt-get install -y -f -qq && apt-get install -y -qq /tmp/chrome.deb)

rm /tmp/chrome.deb

# ── 6. Create dedicated user ───────────────────────────────────────────────────
echo "[6/7] Creating '${APP_USER}' user..."
ensure_user

mkdir -p "${USER_HOME}/.local/bin"
chown -R "${APP_USER}:${APP_USER}" "${USER_HOME}/.local"

# ── 7. Install Paperclip ──────────────────────────────────────────────────────
echo "[7/7] Installing Paperclip..."
if [[ -d "${REPO_DIR}/.git" ]]; then
  echo "[*] Updating existing Paperclip checkout..."
  run_as_user "cd ~/paperclip && git pull --ff-only"
else
  run_as_user "git clone ${REPO_URL} ~/paperclip"
fi

run_as_user "cd ~/paperclip && pnpm install"
run_as_user "cd ~/paperclip && npx paperclipai onboard --yes"

echo ""
echo "============================================="
echo " Paperclip installation complete!"
echo "============================================="
echo ""
echo "Next steps:"
echo "  su - ${APP_USER}"
echo "  cd ~/paperclip"
echo "  pnpm dev"
echo ""
echo "Tunnel the UI port when accessing from the host:"
echo "  ssh -L 3100:127.0.0.1:3100 ${APP_USER}@<VM_IP>"
echo ""
