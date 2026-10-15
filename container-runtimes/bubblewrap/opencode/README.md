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
| Git push over SSH fails                                      | `~/.ssh` is hidden by default. Uncomment the `.ssh` line if you accept the risk. |
| Syntax errors after editing the script                       | Bash does not allow comments after a trailing `\`. Keep comments on their own lines inside the `args=( ... )` array. |

## Uninstall

```bash
rm ~/.local/bin/opencode-bwrap
```