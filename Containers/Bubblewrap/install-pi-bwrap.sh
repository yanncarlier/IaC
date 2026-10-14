#!/usr/bin/env bash
set -euo pipefail

# 1. Make sure bubblewrap is installed
sudo apt install bubblewrap          # Debian/Ubuntu
# or: sudo dnf install bubblewrap    # Fedora
# or: sudo pacman -S bubblewrap      # Arch

# 2. Create the wrapper
# mkdir -p ~/.local/bin

# Overwrite the old one
cp pi-bwrap ~/.local/bin/pi-bwrap

chmod +x ~/.local/bin/pi-bwrap