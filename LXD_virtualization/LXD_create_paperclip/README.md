# Paperclip LXD VM Setup

This directory contains scripts to create and configure an LXD VM for Paperclip using `ubuntu-minimal:24.04`.

## Included scripts

- `01.0_host_create_vm.sh`
  - creates the VM on the host
  - uses `ubuntu-minimal:24.04`
  - minimum specs: `1 CPU`, `1GiB RAM`, `5GiB disk`
  - stops the VM after launch so host config can be applied

- `02.0_host_config_and_start.sh`
  - applies boot-time config and starts the VM
  - pushes `03.0_vm_setup.sh` and `04.0_vm_setup.sh` into the VM
  - prints console and SPICE connection info

- `03.0_vm_setup.sh`
  - installs required packages inside the VM (Node 20, pnpm, desktop utilities, Chrome)
  - creates a `paperclip` user
  - installs Paperclip from the GitHub repository, runs `pnpm install`, and bootstraps the default config
  - exposes `npx paperclipai`/`pnpm` via the user environment

- `04.0_vm_setup.sh`
  - configures SSH and UFW firewall inside the VM
  - allows SSH access on IPv4 port `22` and the Paperclip UI on port `3100`

## Usage

1. Run on the host:
   ```bash
   ./01.0_host_create_vm.sh
   ```

2. Then run:
   ```bash
   ./02.0_host_config_and_start.sh
   ```

3. To enter the VM shell from the host:
   ```bash
   lxc exec pcvm01 -- bash
   ./03.0_vm_setup.sh
   ./04.0_vm_setup.sh
   ```

4. Inside the VM, use the Paperclip user:
   ```bash
   su - paperclip
   cd ~/paperclip
   pnpm install
   npx paperclipai onboard --yes
   pnpm dev
   ```

   The Paperclip server runs on `http://127.0.0.1:3100`. Tunnel the port when accessing from the host:
   ```bash
   ssh -L 3100:127.0.0.1:3100 paperclip@<VM_IP>
   ```

## Notes

- The scripts assume LXD is installed on the host.
- The VM user `paperclip` is created with password `paperclip` (change it after login).
- SSH access is configured for initial setup and testing.
