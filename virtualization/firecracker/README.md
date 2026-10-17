



https://github.com/firecracker-microvm/firecracker/releases/  

## Installing and running a Firecracker microVM on Ubuntu 26

Firecracker needs KVM, so check that first:

```
ls -l /dev/kvm
```

### 1. Install Firecracker and build the VM image

```
chmod +x setup.sh && ./setup.sh
```

### 2. Boot the microVM

```
run-vm.sh 
```

### 3. Connect to the VM

```
connect.sh
```

### 4. Clean up

```
./cleanup.sh            # stop the VM, drop tap/NAT rules, remove the socket
./cleanup.sh --purge    # also delete ~/firecracker-demo (images, rootfs, ssh key)
```

`cleanup.sh` is idempotent and safe to run at any time, including twice in a
row or after a crash. It asks the Firecracker API for a graceful guest
shutdown first (so the rootfs isn't left dirty), then escalates to `SIGINT`
and finally `SIGKILL` for anything that won't exit. With `--purge` it removes
the whole workdir, so the next `setup.sh` re-downloads everything.

Usage

```
chmod +x run-vm.sh connect.sh

# Terminal 1
./run-vm.sh

# Terminal 2
./connect.sh

# either terminal, when you're done
./cleanup.sh
```

## Management commands

Firecracker is controlled at runtime through a JSON API on a Unix socket.
`run-vm.sh` uses `/tmp/firecracker.socket`:

```
S=/tmp/firecracker.socket
```

### Read state

```
# instance id / state / version
curl -s --unix-socket $S GET / | jq
# {"id":"anonymous-instance","state":"Running","vmm_version":"1.17.0","app_name":"Firecracker"}

# VMM version
curl -s --unix-socket $S GET /version
# {"firecracker_version":"1.17.0"}

# vcpus, memory, smt, huge pages
curl -s --unix-socket $S GET /machine-config | jq
# {"vcpu_count":2,"mem_size_mib":1024,"smt":false,"track_dirty_pages":false,"huge_pages":"None"}

# full config export (this is how you inspect drives / network interfaces)
curl -s --unix-socket $S GET /vm/config | jq
```

### Pause and resume

Pause is `PATCH /vm`, **not** an action:

```
curl -s --unix-socket $S -X PATCH http://localhost/vm \
  -H 'Content-Type: application/json' -d '{"state":"Paused"}'
curl -s --unix-socket $S -X PATCH http://localhost/vm \
  -H 'Content-Type: application/json' -d '{"state":"Resumed"}'
```

The guest keeps running while paused; its clock stops.

### Shut down

The only graceful stop available is `SendCtrlAltDel`, which asks the guest's
init to shut down:

```
curl -s --unix-socket $S -X PUT http://localhost/actions \
  -H 'Content-Type: application/json' -d '{"action_type":"SendCtrlAltDel"}'
```

From inside the guest, plain `reboot` or `poweroff` on the serial console does
the same thing. Force-stopping `firecracker` also works but leaves the rootfs
dirty, so run `fsck` on it before the next boot.

### Snapshots

Snapshot must be taken while the VM is `Paused`, and only after boot:

```
curl -s --unix-socket $S -X PATCH http://localhost/vm \
  -H 'Content-Type: application/json' -d '{"state":"Paused"}'

curl -s --unix-socket $S -X PUT http://localhost/snapshot/create \
  -H 'Content-Type: application/json' \
  -d '{"snapshot_path":"vm.snap","mem_file_path":"vm.mem"}'

# restore later, from a firecracker started WITHOUT --config-file.
# Loading puts the VM straight into "Paused", so resume it with PATCH /vm.
# InstanceStart is rejected here with "not supported after starting".
curl -s --unix-socket $S -X PUT http://localhost/snapshot/load \
  -H 'Content-Type: application/json' \
  -d '{"snapshot_path":"vm.snap","mem_backend":{"backend_type":"File","backend_path":"vm.mem"}}'
curl -s --unix-socket $S -X PATCH http://localhost/vm \
  -H 'Content-Type: application/json' -d '{"state":"Resumed"}'
```

A 1 GiB / 2 vCPU microVM produces a ~26 KB state file and a ~1 GB memory file,
so put `mem_file_path` on tmpfs or a large disk.

### Metrics

Metrics are written to a file or named pipe, not fetched with GET. The
endpoint must be configured before boot:

```
curl -s --unix-socket $S -X PUT http://localhost/metrics \
  -H 'Content-Type: application/json' -d '{"metrics_path":"metrics.json"}'

# ...later, dump the counters
curl -s --unix-socket $S -X PUT http://localhost/actions \
  -H 'Content-Type: application/json' -d '{"action_type":"FlushMetrics"}'

jq . metrics.json
```

Output is per-device counters (block_rootfs, balloon, net, virtio_mmio...).
`log_path` for `PUT /logger` works the same way and must be a real path --
an empty string fails with "Failed to open target file".

### Configuring without --config-file

`run-vm.sh` passes `--config-file`, which boots the microVM immediately. That
makes almost every resource read-only:

```
curl -s --unix-socket $S -X PUT http://localhost/balloon \
  -H 'Content-Type: application/json' -d '{"amount_mib":256,"deflate_on_oom":true}'
# {"fault_message":"The requested operation is not supported after starting the microVM."}
```

Same for `/logger`, `/metrics`, `/boot-source`, `/drives` and
`/network-interfaces`. To change them, start the VMM empty and drive it over
the API:

```
firecracker --api-sock $S         # note: no --config-file

curl -s --unix-socket $S -X PUT http://localhost/machine-config \
  -H 'Content-Type: application/json' \
  -d '{"vcpu_count":2,"mem_size_mib":1024,"smt":false}'

curl -s --unix-socket $S -X PUT http://localhost/boot-source \
  -H 'Content-Type: application/json' \
  -d '{"kernel_image_path":"'$HOME'/firecracker-demo/vmlinux","boot_args":"console=ttyS0 root=/dev/vda rw"}'

curl -s --unix-socket $S -X PUT http://localhost/drives/rootfs \
  -H 'Content-Type: application/json' \
  -d '{"drive_id":"rootfs","path_on_host":"'$HOME'/firecracker-demo/rootfs.ext4","is_root_device":true,"is_read_only":false}'

curl -s --unix-socket $S -X PUT http://localhost/actions \
  -H 'Content-Type: application/json' -d '{"action_type":"InstanceStart"}'
```

Until `InstanceStart` is sent, `GET /` reports `"state":"Not started"`.

## API gotchas (verified against v1.17.0)

- **`/actions` accepts only three values:** `FlushMetrics`, `InstanceStart`,
  `SendCtrlAltDel`. `PowerOff`, `Reboot`, `InstancePause`, `InstanceResume`
  and `InstanceStop` do not exist and return
  `unknown variant ... expected one of ...`. Pause/resume moved to
  `PATCH /vm`.
- **`PUT /machine-config` is a full replace, not a patch.** `vcpu_count` and
  `mem_size_mib` are both required; sending only `mem_size_mib` fails with
  `missing field 'vcpu_count'`.
- **Most resources have no GET.** `GET /drives/{id}`, `GET /boot-source`,
  `GET /logger` and `GET /metrics` all return
  `Invalid request method and/or path`. Use `GET /vm/config` instead.
- **The memory balloon is a no-op with the CI guest kernel.** `PUT /balloon`
  returns 204, but the Firecracker CI kernel has no `virtio_balloon` module, so
  the guest's memory never actually shrinks. You need a kernel built with it.
- Just after `InstanceStart` the GET endpoints can briefly answer with the
  instance-info object instead of the requested resource. Re-query if that
  looks surprising.
- **`PUT /snapshot/load` leaves the VM in `Paused`,** so resume it with
  `PATCH /vm {"state":"Resumed"}`. Sending `InstanceStart` instead fails with
  "not supported after starting the microVM".
- Without a TAP device (no root), the guest has only `lo`, so
  `connect.sh` cannot work. Use the serial console in the `run-vm.sh`
  terminal.

