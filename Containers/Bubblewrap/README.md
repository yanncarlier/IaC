**Bubblewrap + Landlock + seccomp + namespaces** is the lightest real isolation stack available on Linux. It’s what Flatpak, Claude Code (on Linux), and many AI-agent sandboxes use under the hood.

Here’s a clear breakdown of each piece and how they fit together.

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

### 2. seccomp-bpf (system-call filter)

- Filters which **syscalls** a process is allowed to make.
- Runs at the kernel entry point (very early).
- Can allow, deny with `EPERM`, kill the process, or notify a supervisor.
- Great for shrinking the kernel attack surface (block `ptrace`, `kexec`, `bpf`, `mount`, `userfaultfd`, etc.).

Limitation: it cannot understand paths (it only sees numbers and register values). So it pairs perfectly with Landlock.

### 3. Landlock (filesystem + limited network LSM)

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

### 4. bubblewrap (`bwrap`) — the convenient glue

`bwrap` is a small, unprivileged tool that makes the above easy to use from the command line or scripts. It was written by Alexander Larsson (Red Hat) as the backend for Flatpak.

What it does:
- Creates a new mount namespace with an empty tmpfs root.
- Lets you precisely build the filesystem the sandboxed process will see (`--ro-bind`, `--bind`, `--tmpfs`, etc.).
- Optionally creates user, PID, network, IPC, UTS namespaces.
- Can load a seccomp filter.
- Drops capabilities and sets `NO_NEW_PRIVS`.
- Starts a tiny PID 1 inside the sandbox so child processes are reaped correctly.

It does **not** use a daemon and does not require root (when user namespaces are enabled).

### Practical Example (minimal AI agent sandbox)

```bash
bwrap \
  --unshare-all \                    # all namespaces
  --share-net \                      # keep network (needed for LLM APIs)
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
  --bind "$PWD" "$PWD" \             # only current project is writable
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
- Not as strong as a microVM (Firecracker / libkrun) when the code is truly adversarial.

### When to use this stack

| Use case                                | Recommendation                                    |
| --------------------------------------- | ------------------------------------------------- |
| Local coding agents on your own machine | **bubblewrap** (or tools built on it) is ideal    |
| Maximum density / lowest overhead       | This stack                                        |
| Untrusted / multi-tenant / hostile code | Prefer microVM (libkrun, Firecracker) or full KVM |
| Long-running services                   | Rootless Podman is usually more convenient        |

Many modern AI-agent wrappers (ai-jail, ai-bwrap, Claude Code’s built-in sandbox, safe-agent, etc.) are thin shells around exactly these four primitives.





### pi-bwrap

Here’s a ready-to-use, hardened bubblewrap wrapper tailored specifically for Pi (the Earendil coding agent).

```
cd ~/your-project
pi-bwrap                  # normal interactive session
pi-bwrap --model sonnet   # with arguments
pi-bwrap "fix the tests"  # one-shot
```

### What this sandbox does

| Access                        | Status           | Reason                               |
| ----------------------------- | ---------------- | ------------------------------------ |
| Current project directory     | **Read + Write** | So Pi can edit code                  |
| ~/.pi                         | **Read + Write** | Auth, settings, extensions, sessions |
| System binaries (/usr, /bin…) | Read-only        | Needed to run tools                  |
| Network                       | Allowed          | Required for LLM API calls           |
| Rest of $HOME                 | **Invisible**    | Protects ~/.ssh, documents, etc.     |
| Host processes                | Invisible        | PID namespace                        |
| Capabilities                  | Dropped          | No privilege escalation              |

### Optional hardening / customisation

- **Stricter** (block network for pure offline work): remove --share-net
- **Even tighter** (only project + minimal system): delete the optional ~/.gitconfig, ~/.ssh, ~/.nvm etc. lines.
- **Add Landlock** (if you want extra FS enforcement on top): you can wrap further with a small Landlock helper, but for most people the mount namespace is already strong enough.

This is currently one of the lightest and most practical ways to run Pi safely on Linux.



