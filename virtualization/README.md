

```
Hardware CPU virtualization
        └── KVM
              ├── QEMU              → general VMs / QEMU microvm
              ├── Firecracker       → minimal microVMs
              └── Kata Containers   → container API + a chosen VMM
                                        ├── QEMU
                                        ├── Cloud Hypervisor
                                        └── Firecracker
```





| Dimension               | QEMU / QEMU microvm                                          | Firecracker                                                  | Kata Containers                                              |
| :---------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| Isolation               | VM isolation; conventional QEMU has a large device-emulation surface | Strong VM isolation with a deliberately tiny VMM/device model | VM isolation per container/pod, with a dedicated guest kernel. northflank+1 |
| Startup                 | Seconds for a typical VM; QEMU `microvm` is optimized for faster startup | About 125 ms to application code; can create up to 150 microVMs/sec/host in published benchmarks. usenix+1 | Roughly 150–300 ms depending on the selected VMM and configuration. northflank+1 |
| Memory overhead         | Higher than Firecracker; depends heavily on guest OS and devices | Under 5 MiB VMM overhead per microVM in AWS’s benchmark configuration. [usenix](https://www.usenix.org/system/files/nsdi20-paper-agache.pdf) | Higher than raw Firecracker because each workload has its own guest kernel and VM context. [bigiron](https://www.bigiron.cc/guides/gvisor-vs-kata-vs-firecracker-the-isolation-layer-decision) |
| Hardware/device support | Broadest: many architectures, legacy devices, GPU/VFIO passthrough, graphics, USB, etc. | Intentionally limited: no graphics, USB, BIOS, ACPI, VFIO/passthrough, or device hotplug. northflank+1 | Depends on backend; QEMU backend gives the broadest compatibility, Firecracker backend is much more constrained. [github](https://github.com/kata-containers/kata-containers/blob/main/docs/design/virtualization.md) |
| Kubernetes integration  | You build the VM workflow yourself                           | You build the orchestration/control plane yourself           | Native container/Kubernetes workflow via CRI and RuntimeClass. northflank+1 |
| Operational complexity  | Moderate to high; mature but feature-rich                    | High if used raw: no built-in VM lifecycle, networking, storage, scheduling, or image management | Lower for Kubernetes teams; it integrates with existing container tooling. usenix+1 |
| Best for                | Desktop/lab VMs, cross-architecture testing, GPU/VFIO, legacy systems, maximum flexibility | Serverless/FaaS, CI sandboxes, AI-agent code execution, multi-tenant ephemeral workloads | Strong isolation for Kubernetes workloads while retaining container ergonomics. northflank+1 |