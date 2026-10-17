# opencode-bwrap

A lightweight [bubblewrap](https://github.com/containers/bubblewrap) sandbox for the [OpenCode](https://opencode.ai) coding agent on Linux.

It runs OpenCode in its own mount, PID, IPC, UTS and user namespaces. OpenCode can read and write your current project and its own config, and sees almost nothing else in your home directory. There is no daemon, no container image, and no root required.

## Files

| File                        | Purpose                                          |
| --------------------------- | ------------------------------------------------ |
| `opencode-bwrap`            | The wrapper script                               |
| `install-opencode-bwrap.sh` | Installs bubblewrap (if missing) and the wrapper |

## Install

```bash
chmod +x install-opencode-bwrap.sh
./install-opencode-bwrap.sh
```

The installer copies `opencode-bwrap` to `~/.local/bin/`. Make sure `~/.local/bin` is in your `PATH`.

You also need OpenCode itself installed and available as `opencode` in your `PATH` (or at `~/.opencode/bin/opencode`, where the official installer puts it).

## Usage

```bash
cd ~/your-project
opencode-bwrap                    # normal interactive session
opencode-bwrap run "fix the tests"  # any arguments are passed to opencode
```

Always run it from the project directory. Whatever directory you are in becomes the writable project.

> **The sandbox is opt-in by name.** It applies *only* when you launch
> `opencode-bwrap`. Running plain `opencode` — from an IDE, a launcher, or
> another terminal — is **not** sandboxed.
>
> The wrapper sets `$OPENCODE_BWRAP=1` inside the sandbox, but **do not treat
> that as proof.** Tool execution can happen in a process that inherited the
> variable from outside its own namespaces. See "Verifying the sandbox" below
> for a check that cannot produce a false positive.

The wrapper refuses to start (rather than silently degrading) if `HOME` is
unset, if `bwrap` is missing, or if unprivileged namespaces are blocked.

## What the sandbox does

| Access                                                       | Status                | Reason                                      |
| ------------------------------------------------------------ | --------------------- | ------------------------------------------- |
| Current project directory                                    | **Read + Write**      | So OpenCode can edit code                   |
| `~/.config/opencode`                                         | **Read + Write**      | Settings, agents, commands                  |
| `~/.local/share/opencode`                                    | **Read + Write**      | Auth (`auth.json`), sessions, data          |
| `~/.local/state/opencode`, `~/.cache/opencode`               | **Read + Write**      | State and cache                             |
| System binaries (`/usr`, `/bin`, `/lib`, ...)                | Read-only             | Needed to run tools                         |
| `~/.gitconfig`, `~/.config/gh`, `~/.npmrc`                   | Read-only (if exist)  | Git, GitHub CLI and npm usage               |
| `~/.opencode`, `~/.local/bin`, `~/.nvm`, `~/.bun`, `~/.cargo`, `~/.rustup`, `~/.npm-global`, fnm | Read-only (if exist)  | Toolchains OpenCode may need                |
| `~/.ssh`                                                     | **Hidden by default** | Uncomment the line in the script if needed  |
| Rest of `$HOME`                                              | **Invisible**         | Protects documents, browser profiles, etc.  |
| `/tmp`, `/var/tmp`, `/run`                                   | Private tmpfs         | Wiped on every run                          |
| Network                                                      | Allowed               | Required for LLM API calls                  |
| Host processes                                               | Invisible             | PID namespace                               |
| Capabilities                                                 | Dropped               | No privilege escalation                     |
| Environment variables                                        | Cleared               | Only an allow-list is passed in (see below) |

### Environment variables passed through

The environment is cleared. Only these are set inside the sandbox:

- `HOME`, `USER`, `PATH`, `TERM`, `COLORTERM`, `LANG`
- API keys, if set in your shell: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `XAI_API_KEY`, `GOOGLE_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`, `GROQ_API_KEY`, `DEEPSEEK_API_KEY`, `MISTRAL_API_KEY`, `ZAI_API_KEY`
- Any variable starting with `OPENCODE_`

If your provider uses a different variable, add its name to the `for var in ...` list in the script.

## Security notes

- **The network is shared.** Anything OpenCode can read could be sent out if the agent is manipulated (for example by prompt injection from a file or web page). That includes project files, the credentials in `~/.local/share/opencode/auth.json`, passed-through API keys, and `~/.config/gh`. Remove any bind line you don't need.
- **`.git` is writable.** The whole project directory is read-write, including `.git/hooks`. Hooks run outside the sandbox when you later run git yourself, so review them if you let the agent work unattended.
- **Shared kernel.** Namespaces are not a VM boundary. A kernel exploit could escape. For hostile or untrusted code, use a microVM instead.
- **No seccomp or Landlock.** This wrapper uses namespaces, dropped capabilities and `NO_NEW_PRIVS` only. Bubblewrap can load a seccomp filter with `--seccomp FD` if you want to add one.
- **OpenCode delegates tools to a host daemon.** Without `--standalone` this is fatal to the sandbox; the wrapper sets it for you. Verify with "Verifying the sandbox" above if you ever launch OpenCode another way.

## Verifying the sandbox

`$OPENCODE_BWRAP` can be set in a process that is *not* sandboxed, so check the namespaces instead. From inside a shell tool:

```bash
# Host PID 1 is systemd/init. Inside the sandbox, PID 1 is bwrap.
tr '\0' ' ' < /proc/1/cmdline

# A sandboxed process has bwrap's user-namespace mapping.
cat /proc/self/uid_map

# The two decisive checks: your Desktop and .ssh must be invisible.
ls -d ~/Desktop 2>&1
ls -d ~/.ssh   2>&1
```

If `/proc/1/cmdline` shows `systemd` or `init`, you are **not** in a sandbox.

## Why `--standalone` is required

OpenCode v2 splits into a client and a shared background daemon. By default the
client attaches to `opencode serve --service`, and **tool calls are executed by
that daemon** — which lives in the host namespaces, where `bwrap` cannot see or
contain it. Confining only the client leaves the agent with full access to
`~/Desktop`, `~/.ssh` and the rest of `$HOME`.

The wrapper therefore passes `--standalone`, which makes the client run a
private server of its own. That server is a child process and inherits the
namespaces set up here, so its tool calls stay confined:

| Process                              | Namespaces | Role                        |
| ------------------------------------ | ---------- | --------------------------- |
| `opencode --standalone`              | sandboxed  | The client for your session |
| `opencode serve --stdio --port 0`    | sandboxed  | Runs the tool calls         |

Without `--standalone` the second row becomes `opencode serve --service` in the
**host** namespaces, and the sandbox is effectively bypassed.

This uses OpenCode's own CLI flag, so it keeps working across upgrades and
reinstalls — no patch to the application is involved. Note that `--standalone`
is only accepted by the agent entry points (`opencode`, `opencode run`,
`opencode mini`); `session` and `debug` reject it, so the wrapper injects it
only where it is valid.

Because each sandboxed session gets its own server, you lose the shared
background server's cross-session continuity. Sessions still persist, but
`opencode service status` will not list them.

To confirm which process ran your tool, and in which namespaces:

```bash
ps -o pid=,ppid=,args= -C opencode
for p in $(pgrep -x opencode); do
  echo "$p $(readlink /proc/$p/ns/mnt) $(tr '\0' ' ' < /proc/$p/cmdline)"
done
```

## Customisation

- **Offline mode:** remove `--share-net`. OpenCode will not be able to reach LLM APIs or `localhost` services on the host (such as a local model server).
- **Tighter:** delete the optional `--ro-bind-try` lines you don't need (`.gitconfig`, `.config/gh`, `.npmrc`, toolchain directories).
- **Git over SSH:** uncomment the `~/.ssh` line. Be aware of the exfiltration risk above.
- **Extra tools or directories:** add another `--ro-bind-try SRC DEST` line to the `args` array in the script.
- **Different paths:** the OpenCode locations are set in the `OC_CONFIG`, `OC_DATA`, `OC_STATE` and `OC_CACHE` variables near the top of the script. If your install uses other locations, change them there.

## Troubleshooting

| Symptom                                                      | Cause and fix                                                |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `bwrap: No permissions to create new namespace` or `setting up uid map: Permission denied` | Unprivileged user namespaces are blocked. On Ubuntu 23.10 and later, AppArmor restricts them by default. Allow `bwrap` through an AppArmor profile or relax `kernel.apparmor_restrict_unprivileged_userns`. |
| `Error: real 'opencode' binary not found in PATH`            | OpenCode isn't installed, or isn't in `PATH`. Install it, or check `~/.opencode/bin/opencode` exists. |
| `command not found` for a tool inside the sandbox            | The tool lives in a directory that isn't bound in. Add a matching `--ro-bind-try` line and, if needed, extend `SANDBOX_PATH`. |
| OpenCode can't save sessions or login                        | Its data directory differs from the defaults. Adjust the `OC_*` variables in the script. |
| `$OPENCODE_BWRAP` is unset                                   | You launched plain `opencode`. Only `opencode-bwrap` is sandboxed.                            |
| Tool runs outside the sandbox despite a sandboxed session     | Check that `--standalone` is being passed; without it OpenCode delegates tool calls to a host-side `opencode serve --service` daemon.        |
| Git push over SSH fails                                      | `~/.ssh` is hidden by default. Uncomment the `.ssh` line if you accept the risk. |
| Syntax errors after editing the script                       | Bash does not allow comments after a trailing `\`. Keep comments on their own lines inside the `args=( ... )` array. |

## Uninstall

```bash
rm ~/.local/bin/opencode-bwrap
```