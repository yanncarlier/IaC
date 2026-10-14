#!/usr/bin/env bash

set -e

os=ubuntu-minimal:24.04

vms=(
  "VM01"
  "VM02"
  "VM03"
)

for vm in "${vms[@]}"; do

  echo "→ Deleting $vm"
  if sudo lxc info "$vm" >/dev/null 2>&1; then
    echo "  exists → deleting"
    sudo lxc stop "$vm"  --force 2>/dev/null || true
    sudo lxc delete "$vm" --force
    sleep 5
  fi

  echo "→ Creating $vm"
  sudo lxc launch "$os" "$vm" --vm \
    -c limits.cpu=1 \
    -c limits.memory=1GiB \
    -d root,size=5GiB \
    -c boot.autostart=false
  sleep 15


  echo -n "  Waiting"
  until sudo lxc info "$vm" | grep -q '^Status: RUNNING'; do
    sleep 5
    echo -n .
  done
  echo " ready"

  # Replace <source_dir> with your actual local folder path
  sudo lxc file push -r "$vm"/ "$vm"/root/

  sudo lxc exec "$vm" -- apt update -qq
  sudo lxc exec "$vm" -- apt install -y python3 python3-pip git curl

  sudo lxc exec "$vm" -- bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  sudo lxc exec "$vm" -- bash -c '/root/.local/bin/uv --version'
  sleep 2
  # Install dependencies using UV and Activate virtual environment
  sudo lxc exec "$vm" -- bash -c "cd /root/$vm/ && /root/.local/bin/uv sync && source /root/$vm/.venv/bin/activate"
  
  

# source .venv/bin/activate
# uv pip install -r requirements.txt
# uv run main.py
  
done

echo "Done."