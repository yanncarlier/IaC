#!/bin/bash
# =============================================================================
# 
# Run this INSIDE the LXD VM (as root or with sudo)
# Installs Hermes Agent on Ubuntu 24.04 minimal
# =============================================================================

set -euo pipefail

echo "============================================="
echo " Hermes Agent VM — User Setup and Installation"
echo "============================================="

export DEBIAN_FRONTEND=noninteractive

APP_USER="hermes"
USER_HOME="/home/${APP_USER}"

ensure_user() {
  if id "${APP_USER}" &>/dev/null; then
    return
  fi
  useradd -m -s /bin/bash -G sudo "${APP_USER}"
  echo "${APP_USER}:${APP_USER}" | chpasswd
}

# ── 1. Create dedicated user ───────────────────────────────────────────────────
echo "[1/3] Creating '${APP_USER}' user..."
ensure_user

# ── 2. Add hermes user to sudoers without password ────────────────────────────
echo "[2/3] Configuring sudo privileges for '${APP_USER}' user..."
echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/hermes-nopasswd
chmod 0440 /etc/sudoers.d/hermes-nopasswd

mkdir -p "${USER_HOME}/.local/bin"
chown -R "${APP_USER}:${APP_USER}" "${USER_HOME}/.local"

# ── 3. Install Hermes Agent ──────────────────────────────────────────────────────
echo "[3/3] Installing Hermes Agent under '${APP_USER}' with proper environment..."
# First install Python 3.12 at system level if needed
if ! command -v python3.12 &>/dev/null; then
  echo "Installing Python 3.12..."
  apt-get install -y -qq python3.12 python3.12-venv python3.12-dev
fi

# Then run the Hermes Agent installer as the hermes user with proper env
# Use 'script' to allocate a pseudo-TTY for the interactive wizard
su - "${APP_USER}" -c "script -q -c 'curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash' /dev/null"

echo ""
echo "============================================="
echo " Hermes Agent user setup and installation complete!"
echo "============================================="
echo ""
echo "Next steps:"
echo "  su - ${APP_USER}"
echo ""
echo ""
echo ""
echo "Tunnel the UI port when accessing from the host:"
echo "  ssh -L 3100:127.0.0.1:3100 ${APP_USER}@<VM_IP>"
echo ""
echo "============================================="
echo " Hermes Agent user setup and installation complete!"
echo "============================================="
echo ""
echo ""
echo " Try running manually: "
echo "cd /home/hermes/.hermes/hermes-agent && npx playwright install --with-deps chromium"
echo ""
echo ""