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
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WRAPPER_SRC="$SCRIPT_DIR/opencode-bwrap"

if [[ ! -f "$WRAPPER_SRC" ]]; then
  echo "Error: wrapper not found at $WRAPPER_SRC" >&2
  echo "       Expected a file named 'opencode-bwrap' next to this installer." >&2
  exit 1
fi

mkdir -p "$HOME/.local/bin"
cp "$WRAPPER_SRC" "$HOME/.local/bin/opencode-bwrap"
chmod +x "$HOME/.local/bin/opencode-bwrap"

echo "Installed to $HOME/.local/bin/opencode-bwrap"
echo "Make sure $HOME/.local/bin is in your PATH."
echo
echo "IMPORTANT: the sandbox only applies when you launch it explicitly:"
echo "    cd ~/your-project && opencode-bwrap"
echo "Running plain 'opencode' is NOT sandboxed."