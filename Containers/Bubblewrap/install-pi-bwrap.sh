#!/usr/bin/env bash
set -euo pipefail

# 1. Make sure bubblewrap is installed
if ! command -v bwrap >/dev/null 2>&1; then
  echo "bubblewrap not found, installing..."
  if command -v apt >/dev/null 2>&1; then
    sudo apt install -y bubblewrap          # Debian/Ubuntu
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y bubblewrap          # Fedora
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm bubblewrap   # Arch
  else
    echo "Could not detect a package manager. Please install bubblewrap manually." >&2
    exit 1
  fi
fi

# 2. Install the wrapper (overwrites any old copy)
mkdir -p "$HOME/.local/bin"
cp "$(dirname "$0")/pi-bwrap" "$HOME/.local/bin/pi-bwrap"
chmod +x "$HOME/.local/bin/pi-bwrap"

echo "Installed to $HOME/.local/bin/pi-bwrap"
echo "Make sure $HOME/.local/bin is in your PATH."