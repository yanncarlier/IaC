# Hermes Agent LXD VM Setup

This directory contains scripts to create and configure an LXD VM for Hermes Agent using `ubuntu-minimal:24.04`.

## Included scripts

- `hermes-01.0_host_create_vm.sh`
  - creates the VM on the host
  - uses `ubuntu-minimal:24.04`
  - recommended specs: `2 CPU`, `2GiB RAM`, `15GiB disk`
  - stops the VM after launch so host config can be applied

- `hermes-02.0_host_config_and_start.sh`
  - applies boot-time config and starts the VM
  - pushes `hermes-03.0_vm_setup.sh` and `hermes-04.0_vm_setup.sh` into the VM
  - prints console and SPICE connection info

- `hermes-03.0_vm_setup.sh`
  - installs required packages inside the VM (Node 20, desktop utilities, Chrome, and Chromium)
  
- `hermes-03.1_vm_setup.sh`
  - creates a `hermes` user
  - adds the user to sudoers without password requirement
  - installs Hermes Agent under the hermes user with proper environment setup

- `hermes-04.0_vm_setup.sh`
  - configures SSH and UFW firewall inside the VM
  - allows SSH access on IPv4 port `22` and the Hermes Agent UI on port `3100`

## Usage

1. Run on the host:
   ```bash
   ./hermes-01.0_host_create_vm.sh
   ```

2. Then run:
   ```bash
   ./hermes-02.0_host_config_and_start.sh
   ```

3. To enter the VM shell from the host:
   ```bash
   lxc exec hermesvm01 -- bash
   ./hermes-03.0_vm_setup.sh
   ./hermes-03.1_vm_setup.sh
   ./hermes-04.0_vm_setup.sh
   ```

4. Inside the VM, you can either:
   
   Run the automated setup scripts:
   ```bash
   ./hermes-03.1_vm_setup.sh
   ```
   
   Or manually install as the Hermes user:
   ```bash
   su - hermes
   curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
   cd ~/hermes-agent
   pnpm dev
   ```

   The Hermes Agent server runs on `http://127.0.0.1:3100`. Tunnel the port when accessing from the host:
   ```bash
   ssh -L 3100:127.0.0.1:3100 hermes@<VM_IP>
   ```

## Notes

- The scripts assume LXD is installed on the host.
- The VM user `hermes` is created with password `hermes` (change it after login).
- SSH access is configured for initial setup and testing.
- Increased resource allocation compared to Paperclip (2 CPUs, 2GB RAM) for better Hermes Agent performance.