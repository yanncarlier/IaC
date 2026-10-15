# OpenFang LXD VM Setup

This directory contains scripts to create and configure an LXD VM for OpenFang using `ubuntu-minimal:24.04`.

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
  - installs required packages inside the VM
  - creates an `openfang` user
  - installs OpenFang from GitHub release `v0.5.6` using the Linux tarball
  - exposes `openfang` on the system `PATH` via `/usr/local/bin/openfang`

- `04.0_vm_setup.sh`
  - configures SSH and UFW firewall inside the VM
  - allows secure SSH access over IPv4 port `22`

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
   lxc exec ofvm01 -- bash
   ./03.0_vm_setup.sh
   ./04.0_vm_setup.sh
   ```

4. Inside the VM, use the OpenFang user:
   ```bash
   su - openfang
   ~/.openfang/bin/openfang init
   ~/.openfang/bin/openfang start
   ```

## Notes

- The script assumes LXD is installed on the host.
- The VM user `openfang` is created with password `openfang`.
- SSH access is configured for initial setup and testing.
