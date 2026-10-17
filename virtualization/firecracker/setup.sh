#!/usr/bin/env bash
# setup.sh - Installs Firecracker, downloads a guest kernel and an Ubuntu rootfs,
# and prepares an SSH key so you can log into the microVM.
set -euo pipefail

ARCH="$(uname -m)"
WORKDIR="${HOME}/firecracker-demo"
ROOTFS_SIZE="${ROOTFS_SIZE:-2G}"     # see step 6: 1G is too small for Ubuntu 24.04
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

have_sudo() { sudo -n true 2>/dev/null; }
note()      { printf 'NOTE: %s\n' "$*"; }
die()       { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- 1. Check for KVM -------------------------------------------------------
if [ ! -e /dev/kvm ]; then
  die "/dev/kvm not found. Enable virtualization in BIOS/UEFI
(or enable nested virtualization if this machine is itself a VM)."
fi

# -e only proves the node exists; we also need to be able to open it read-write.
if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
  die "/dev/kvm exists but ${USER} cannot read/write it.
Fix with:  sudo usermod -aG kvm ${USER}   # then re-login
       and:  sudo setfacl -m u:${USER}:rw /dev/kvm   # until reboot"
fi

# --- 2. Install host dependencies ------------------------------------------
if have_sudo; then
  sudo apt-get update
  sudo apt-get install -y curl wget squashfs-tools e2fsprogs iproute2 \
    iptables jq openssh-client acl
else
  note "passwordless sudo unavailable; skipping apt-get install."
  note "install manually if something below is missing:"
  note "  sudo apt-get install -y curl wget squashfs-tools e2fsprogs iproute2 iptables jq openssh-client acl"
fi

# --- 3. Give your user access to /dev/kvm ----------------------------------
if have_sudo; then
  sudo usermod -aG kvm "${USER}" || true       # permanent (after re-login)
  sudo setfacl -m "u:${USER}:rw" /dev/kvm || true  # immediate (until reboot)
else
  note "no passwordless sudo; cannot adjust /dev/kvm permissions."
  note "if step 1 complained above, run:  sudo setfacl -m u:${USER}:rw /dev/kvm"
fi

# --- 4. Download and install the latest Firecracker release ----------------
release_url="https://github.com/firecracker-microvm/firecracker/releases"
latest_version="$(basename "$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${release_url}/latest")")"
echo "Latest Firecracker release: ${latest_version}"

if command -v firecracker >/dev/null 2>&1 \
   && [ "$(firecracker --version 2>&1 | grep -oP 'v[0-9.]+' | head -1)" = "${latest_version}" ]; then
  echo "firecracker ${latest_version} already installed; skipping."
else
  curl -fL "${release_url}/download/${latest_version}/firecracker-${latest_version}-${ARCH}.tgz" \
    | tar -xz
  if have_sudo; then
    sudo install -m 0755 \
      "release-${latest_version}-${ARCH}/firecracker-${latest_version}-${ARCH}" \
      /usr/local/bin/firecracker
  else
    note "no passwordless sudo; installing firecracker to ~/bin instead."
    mkdir -p "${HOME}/bin"
    install -m 0755 \
      "release-${latest_version}-${ARCH}/firecracker-${latest_version}-${ARCH}" \
      "${HOME}/bin/firecracker"
    export PATH="${HOME}/bin:${PATH}"
  fi
fi
firecracker --version | head -1

# --- 5. Download a guest kernel and Ubuntu rootfs from Firecracker CI ------
# The CI bucket is NOT published for every Firecracker release: artifacts stop
# at v1.15 today, so deriving the prefix from the binary version (v1.17) finds
# nothing. Walk the minor version down until we hit a prefix that actually has
# objects, then take the newest kernel/rootfs inside it.
s3_list() { curl -fsS "http://spec.ccfc.min.s3.amazonaws.com/?prefix=$1&list-type=2"; }

find_ci_prefix() {
  local want="$1" major="${1#v}" i ver
  major="${major%%.*}"                       # v1.17 -> 1
  for (( i = ${want##*.}; i >= 0; i-- )); do
    ver="v${major}.${i}"
    if s3_list "firecracker-ci/${ver}/${ARCH}/" | grep -q '<Key>'; then
      printf '%s\n' "${ver}"; return 0
    fi
  done
  return 1
}

WANT_CI="${latest_version%.*}"
CI_VERSION="$(find_ci_prefix "${WANT_CI}")" \
  || die "no published Firecracker CI artifacts found for ${ARCH} (checked ${WANT_CI} and older)"
if [ "${CI_VERSION}" != "${WANT_CI}" ]; then
  note "CI artifacts for ${WANT_CI} are not published; using ${CI_VERSION} instead."
fi

# Skip the -no-acpi and .config sidecars; we want the plain kernel image.
latest_kernel_key="$(s3_list "firecracker-ci/${CI_VERSION}/${ARCH}/vmlinux-" \
  | grep -oP "(?<=<Key>)(firecracker-ci/${CI_VERSION}/${ARCH}/vmlinux-[0-9]+\.[0-9]+\.[0-9]{1,3})(?=</Key>)" \
  | sort -V | tail -1)"
[ -n "${latest_kernel_key}" ] \
  || die "no guest kernel under firecracker-ci/${CI_VERSION}/${ARCH}/"

latest_ubuntu_key="$(s3_list "firecracker-ci/${CI_VERSION}/${ARCH}/ubuntu-" \
  | grep -oP "(?<=<Key>)(firecracker-ci/${CI_VERSION}/${ARCH}/ubuntu-[0-9]+\.[0-9]+\.squashfs)(?=</Key>)" \
  | sort -V | tail -1)"
[ -n "${latest_ubuntu_key}" ] \
  || die "no Ubuntu rootfs under firecracker-ci/${CI_VERSION}/${ARCH}/"

echo "Kernel: ${latest_kernel_key}"
echo "Rootfs: ${latest_ubuntu_key}"

fetch() {  # url dest
  if [ -s "$2" ]; then echo "  have $(basename "$2")"; return 0; fi
  echo "  downloading $(basename "$2") ..."
  curl -fL --retry 3 --progress-bar -o "$2.part" "$1" && mv "$2.part" "$2"
}
fetch "https://s3.amazonaws.com/spec.ccfc.min/${latest_kernel_key}" vmlinux
fetch "https://s3.amazonaws.com/spec.ccfc.min/${latest_ubuntu_key}" ubuntu.squashfs

# --- 6. Build an ext4 rootfs with your SSH key baked in --------------------
# The CI squashfs is 100% root-owned. Running unsquashfs/mkfs.ext4 as your own
# user stamps uid=1000 into every inode, which breaks sshd StrictModes and
# systemd inside the guest. Use fakeroot when we don't have real root.
[ -f vm_key ] || ssh-keygen -t ed25519 -f vm_key -N "" -q

if   [ "$(id -u)" -eq 0 ];                            then RUN_AS=(); USE_FAKEROOT=0
elif command -v fakeroot >/dev/null 2>&1;            then RUN_AS=(fakeroot --); USE_FAKEROOT=1
else die "building the rootfs without root requires fakeroot.
     Install it (sudo apt-get install fakeroot) or re-run setup.sh with sudo."
fi
[ "${USE_FAKEROOT}" -eq 1 ] && echo "building rootfs under fakeroot (preserves root:root ownership)"

# Rebuild from scratch each run so a stale tree can't leak into the image.
"${RUN_AS[@]+"${RUN_AS[@]}"}" bash -euo pipefail -c '
  cd "$1"
  rm -rf squashfs-root rootfs.ext4
  unsquashfs ubuntu.squashfs >/dev/null
  mkdir -p squashfs-root/root/.ssh
  cp vm_key.pub squashfs-root/root/.ssh/authorized_keys
  chmod 700 squashfs-root/root/.ssh
  chmod 600 squashfs-root/root/.ssh/authorized_keys
  chown -R 0:0 squashfs-root
  truncate -s "$2" rootfs.ext4
  mkfs.ext4 -q -d squashfs-root -F rootfs.ext4
  rm -rf squashfs-root
' _ "${WORKDIR}" "${ROOTFS_SIZE}"

echo "  rootfs.ext4: $(du -h rootfs.ext4 | cut -f1) used of ${ROOTFS_SIZE}"

echo
echo "Setup complete. Files are in: ${WORKDIR}"
echo "Log out and back in (or run 'newgrp kvm') so the kvm group applies permanently."
echo "Next: ./run-vm.sh in one terminal, then ./connect.sh in another."