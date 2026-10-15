**Bubblewrap + namespaces (optionally + seccomp / Landlock)** is the lightest real isolation stack available on Linux. It's what Flatpak, Claude Code (on Linux), and many AI-agent sandboxes use under the hood.

Here's a clear breakdown of each piece and how they fit together.

### 1. Linux Namespaces (the foundation)

Namespaces give a process its own private view of system resources. The important ones for sandboxing:

| Namespace                    | What it isolates               | Effect                                                       |
| ---------------------------- | ------------------------------ | ------------------------------------------------------------ |
| **Mount** (`CLONE_NEWNS`)    | Filesystem mounts              | Sandbox can have a completely different root and only see the directories you explicitly give it |
| **User** (`CLONE_NEWUSER`)   | UIDs/GIDs                      | Root inside the sandbox is just your normal user outside → no real privilege escalation |
| **PID** (`CLONE_NEWPID`)     | Process IDs                    | Sandbox cannot see or kill host processes                    |
| **Network** (`CLONE_NEWNET`) | Network stack                  | Can be fully isolated (only loopback) or shared              |
| **IPC**                      | SysV shared memory, semaphores | Prevents communication with host processes                   |
| **UTS**                      | Hostname                       | Cosmetic isolation                                           |

These are pure kernel features — almost zero overhead.

### 2. seccomp-bpf (system-call filter) — optional

- Filters which **syscalls** a process is allowed to make.
- Runs at the kernel entry point (very early).
- Can allow, deny with `EPERM`, kill the process, or notify a supervisor.
- Great for shrinking the kernel attack surface (block `ptrace`, `kexec`, `bpf`, `mount`, `userfaultfd`, etc.).

Limitation: it cannot understand paths (it only sees numbers and register values). So it pairs well with filesystem-level restrictions.

> Note: `pi-bwrap` below does **not** load a seccomp filter. bubblewrap can load one via `--seccomp FD` if you want to add it.

### 3. Landlock (filesystem + limited network LSM) — optional

Landlock is a modern **Linux Security Module** designed for unprivileged self-sandboxing.

Key properties:
- Any process can restrict *itself* (no root required).
- Restrictions are **one-way** — once applied they cannot be removed and are inherited by children.
- Works by file descriptor (inode), not path strings → immune to classic TOCTOU races and symlink tricks.
- You declare which access rights you want to *handle*, then add allow rules for specific directory trees.
- Newer kernels also support network port rules.

Typical flow:
1. Create a ruleset (say which rights you care about: read, write, execute, create, etc.).
2. Add rules for the directories the process is allowed to touch.
3. Call `landlock_restrict_self()` → from that moment on the process (and children) can only access the allowed hierarchies.

It is stackable with SELinux/AppArmor and works inside containers/namespaces.

> Note: bubblewrap itself has no Landlock support, and `pi-bwrap` does not use it. Landlock would have to be applied by a separate helper.

### 4. bubblewrap (`bwrap`) — the convenient glue

`bwrap` is a small, unprivileged tool that makes the above easy to use from the command line or scripts. It was written by Alexander Larsson (Red Hat) as the backend for Flatpak.

What it does:
- Creates a new mount namespace with an empty tmpfs root.
- Lets you precisely build the filesystem the sandboxed process will see (`--ro-bind`, `--bind`, `--tmpfs`, etc.).
- Optionally creates user, PID, network, IPC, UTS namespaces.
- Can load a seccomp filter.
- Drops capabilities and sets `NO_NEW_PRIVS`.
- Runs a tiny init process inside the PID namespace so child processes are reaped correctly.

It does **not** use a daemon and does not require root (when unprivileged user namespaces are enabled).

### Practical Example (minimal AI agent sandbox)

Note: comments cannot follow a trailing `\` in bash, so they go on their own lines here.

```bash
# --unshare-all : all namespaces
# --share-net   : keep network (needed for LLM APIs)
# --bind "$PWD" : only the current project is writable
bwrap \
  --unshare-all \
  --share-net \
  --ro-bind /usr /usr \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --ro-bind /bin /bin \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --ro-bind /etc/ssl /etc/ssl \
  --dev /dev \
  --proc /proc \
  --tmpfs /tmp \
  --tmpfs /home \
  --bind "$PWD" "$PWD" \
  --chdir "$PWD" \
  --die-with-parent \
  your-ai-agent "$@"
```

You can go further by adding a seccomp filter and Landlock rules on top.

### Strengths for local AI isolation

- Extremely light (startup in tens of milliseconds, almost no memory overhead).
- No daemon, no images, no root required.
- Excellent for wrapping coding agents (Claude Code, Codex, OpenCode, Grok CLI, etc.) so they only see the current project.
- Kernel-enforced → the agent cannot simply ignore the restrictions.

### Limitations

- Still shares the host kernel (a kernel exploit can escape).
- You must carefully choose what to bind-mount (missing a library = broken tool).
- Network isolation is all-or-nothing unless you add a proxy.
- Anything the sandbox can read can be sent out over the network (see the pi-bwrap notes below).
- Not as strong as a microVM (Firecracker / libkrun) when the code is truly adversarial.

### When to use this stack

| Use case                                | Recommendation                                    |
| --------------------------------------- | ------------------------------------------------- |
| Local coding agents on your own machine | **bubblewrap** (or tools built on it) is ideal    |
| Maximum density / lowest overhead       | This stack                                        |
| Untrusted / multi-tenant / hostile code | Prefer microVM (libkrun, Firecracker) or full KVM |
| Long-running services                   | Rootless Podman is usually more convenient        |

### pi-bwrap

A ready-to-use bubblewrap wrapper for Pi (the Earendil coding agent).

#### Install

```bash
chmod +x install-pi-bwrap.sh
./install-pi-bwrap.sh
```

The installer installs `bubblewrap` if missing and copies `pi-bwrap` to `~/.local/bin/`. Make sure `~/.local/bin` is in your `PATH`.

#### Usage

```bash
cd ~/your-project
pi-bwrap                  # normal interactive session
pi-bwrap --model sonnet   # with arguments
pi-bwrap "fix the tests"  # one-shot
```

#### What this sandbox does

| Access                                          | Status                | Reason                                                       |
| ----------------------------------------------- | --------------------- | ------------------------------------------------------------ |
| Current project directory                       | **Read + Write**      | So Pi can edit code                                          |
| ~/.pi                                           | **Read + Write**      | Auth, settings, extensions, sessions                         |
| System binaries (/usr, /bin…)                   | Read-only             | Needed to run tools                                          |
| ~/.gitconfig, ~/.config/gh, ~/.npmrc            | Read-only (if exist)  | Git/GitHub/npm usage                                         |
| ~/.local/bin, ~/.nvm, ~/.cargo, ~/.rustup, etc. | Read-only (if exist)  | Toolchains Pi may need                                       |
| ~/.ssh                                          | **Hidden by default** | Uncomment the line in the script if needed                   |
| Rest of $HOME                                   | **Invisible**         | Protects documents, browser profiles, etc.                   |
| /tmp, /var/tmp, /run                            | Private tmpfs         | Wiped on every run                                           |
| Network                                         | Allowed               | Required for LLM API calls                                   |
| Host processes                                  | Invisible             | PID namespace                                                |
| Capabilities                                    | Dropped               | No privilege escalation                                      |
| Environment variables                           | Cleared               | Only HOME, USER, PATH, TERM, COLORTERM, LANG and common API keys are passed in |

#### Security notes

- The network is shared, so anything Pi can read (project files, `~/.pi` tokens, passed-through API keys, `~/.config/gh`) could be exfiltrated if the agent is manipulated by prompt injection. Remove bind lines you don't need.
- No seccomp filter or Landlock is applied by default.

#### Optional hardening / customisation

- **Offline** (pure local work): remove `--share-net`. Pi will not be able to reach LLM APIs or host `localhost` services.
- **Tighter**: delete the optional `--ro-bind-try` lines (`.gitconfig`, `.config/gh`, `.npmrc`, `.nvm`, etc.) you don't need.
- **Git over SSH**: uncomment the `~/.ssh` line (be aware of the exfiltration risk above).
- **More syscall filtering**: generate a seccomp BPF file and pass it with `--seccomp FD`.

#### Troubleshooting

- `bwrap: No permissions to create new namespace` / `setting up uid map: Permission denied`: unprivileged user namespaces are blocked. On Ubuntu 23.10+, AppArmor restricts them by default; allow `bwrap` via an AppArmor profile or relax `kernel.apparmor_restrict_unprivileged_userns`.
- `command not found` inside the sandbox: the tool lives in a directory that isn't bound in. Add a matching `--ro-bind-try` line.
