#!/bin/bash
# =============================================================================
# 
# Run this INSIDE the LXD VM (as root or with sudo)
# Installs: OpenFang on Ubuntu 24.04 minimal
# =============================================================================

set -euo pipefail

echo "============================================="
echo " OpenFang VM — In-VM Setup Script"
echo "============================================="

export DEBIAN_FRONTEND=noninteractive

APP_USER="openfang"
USER_HOME="/home/${APP_USER}"

# ── 1. Update system ──────────────────────────────────────────────────────────
echo "[1/5] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Install required packages ───────────────────────────────────────────────
echo "[2/5] Installing required packages..."
apt-get install -y -qq \
  curl \
  wget \
  ca-certificates \
  gnupg \
  tar \
  gzip \
  unzip \
  sudo \
  openssh-server \
  iproute2 \
  procps

# Ensure SSH is enabled for remote access in case you want it
systemctl enable ssh
systemctl start ssh

# ── 2.1. Update system ──────────────────────────────────────────────────────────
echo "[1/9] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Install XFCE desktop (lightweight, great for automation) ───────────────
echo "[2/9] Installing XFCE desktop environment..."
apt-get install -y -qq \
  xfce4 \
  xfce4-terminal \
  xfce4-screenshooter \
  lightdm \
  lightdm-gtk-greeter \
  dbus-x11 \
  at-spi2-core

# Enable display manager
systemctl enable lightdm
systemctl restart lightdm



# ── 5. Install Google Chrome ──────────────────────────────────────────────────
echo "[5/9] Installing Google Chrome..."
apt-get install -y -qq wget curl gnupg ca-certificates

wget -qO /tmp/chrome.deb \
  "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

apt-get install -y -qq /tmp/chrome.deb || \
  apt-get install -y -f -qq && apt-get install -y -qq /tmp/chrome.deb

rm /tmp/chrome.deb

# ── 3. Create dedicated openfang user ─────────────────────────────────────────
echo "[3/5] Creating dedicated '${APP_USER}' user..."
if ! id "${APP_USER}" &>/dev/null; then
  useradd -m -s /bin/bash -G sudo "${APP_USER}"
  echo "${APP_USER}:${APP_USER}" | chpasswd
fi

mkdir -p "${USER_HOME}/.local/bin"
chown -R "${APP_USER}:${APP_USER}" "${USER_HOME}/.local"

# ── 4. Install OpenFang ───────────────────────────────────────────────────────
echo "[4/5] Installing OpenFang for ${APP_USER}..."

OPENFANG_RELEASE_TAG="v0.5.6"
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64|amd64) TARGET="x86_64-unknown-linux-gnu" ;;
  aarch64|arm64) TARGET="aarch64-unknown-linux-gnu" ;;
  *)
    echo "[!] Unsupported architecture: ${ARCH}"
    exit 1
    ;;
esac

DOWNLOAD_URL="https://github.com/RightNow-AI/openfang/releases/download/${OPENFANG_RELEASE_TAG}/openfang-${TARGET}.tar.gz"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "[*] Downloading OpenFang from ${DOWNLOAD_URL}..."
if ! curl -fL "${DOWNLOAD_URL}" -o "${TMPDIR}/openfang.tar.gz"; then
  echo "[!] Failed to download OpenFang from ${DOWNLOAD_URL}."
  echo "    The latest GitHub release does not currently publish Linux binaries."
  echo "    Please check https://github.com/RightNow-AI/openfang/releases or update RELEASE_TAG."
  exit 1
fi

tar -xzf "${TMPDIR}/openfang.tar.gz" -C "${TMPDIR}"
BIN_PATH="$(find "${TMPDIR}" -type f -name openfang -perm /111 | head -n 1 || true)"
if [[ -z "${BIN_PATH}" ]]; then
  BIN_PATH="$(find "${TMPDIR}" -type f -name openfang | head -n 1)"
fi
if [[ -z "${BIN_PATH}" ]]; then
  echo "[!] OpenFang binary not found in archive"
  exit 1
fi

INSTALL_DIR="${USER_HOME}/.openfang"
BIN_DIR="${INSTALL_DIR}/bin"
mkdir -p "${BIN_DIR}"
cp "${BIN_PATH}" "${BIN_DIR}/openfang"
chmod +x "${BIN_DIR}/openfang"
chown -R "${APP_USER}:${APP_USER}" "${INSTALL_DIR}"
ln -sf "${BIN_DIR}/openfang" /usr/local/bin/openfang

PROFILE="${USER_HOME}/.bashrc"
PROFILE2="${USER_HOME}/.profile"
for PROFILE_FILE in "${PROFILE}" "${PROFILE2}"; do
  if [[ ! -f "${PROFILE_FILE}" ]]; then
    touch "${PROFILE_FILE}"
    chown "${APP_USER}:${APP_USER}" "${PROFILE_FILE}"
  fi
  if ! grep -q 'export PATH="\$HOME/.openfang/bin:\$PATH"' "${PROFILE_FILE}" 2>/dev/null; then
    cat >> "${PROFILE_FILE}" <<'EOF'

# OpenFang
export PATH="$HOME/.openfang/bin:$PATH"
EOF
    chown "${APP_USER}:${APP_USER}" "${PROFILE_FILE}"
  fi
done

# ── 5. Verify installation ───────────────────────────────────────────────────
echo "[5/5] Verifying OpenFang installation..."
if runuser -l "${APP_USER}" -c 'command -v openfang >/dev/null'; then
  echo "OpenFang version: $(runuser -l "${APP_USER}" -c 'openfang --version' 2>/dev/null || echo 'installed')"
else
  echo "[!] OpenFang binary not found after install."
  exit 1
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================="
echo " OpenFang installation complete!"
echo "============================================="
echo ""
echo "Next steps:"
echo "  su - ${APP_USER}"
echo "  ~/.openfang/bin/openfang init"
echo "  ~/.openfang/bin/openfang start"
echo ""
echo "If the binary is not found, add:"
echo "  export PATH=\"${USER_HOME}/.openfang/bin:\${PATH}\""
echo ""
echo "To copy your SSH public key from your local machine to this VM, run on your local host:"
echo "  ssh-copy-id openfang@<VM_IP>"
echo ""
echo "If ssh-copy-id is unavailable, use this exact command from your local machine:"
echo "  cat ~/.ssh/id_rsa.pub | ssh openfang@<VM_IP> 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'"
echo ""
echo "Replace <VM_IP> with your VM IP address."
echo ""
