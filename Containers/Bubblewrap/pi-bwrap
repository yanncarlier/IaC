#!/usr/bin/env bash
# pi-bwrap — lightweight bubblewrap sandbox for Pi coding agent
# Usage: cd /path/to/project && pi-bwrap [pi arguments...]

set -euo pipefail

# --- Locate the real pi binary (skip this wrapper itself) -------------------
SCRIPT_PATH=$(realpath "$0")
REAL_PI=""

# Prefer the first 'pi' in PATH that is not this script
while IFS= read -r candidate; do
  if [[ "$(realpath "$candidate")" != "$SCRIPT_PATH" ]]; then
    REAL_PI="$candidate"
    break
  fi
done < <(type -a -p pi 2>/dev/null || true)

# Fallback if type -a found nothing
if [[ -z "$REAL_PI" ]]; then
  REAL_PI=$(which pi 2>/dev/null || true)
  if [[ -z "$REAL_PI" || "$(realpath "$REAL_PI")" == "$SCRIPT_PATH" ]]; then
    echo "Error: real 'pi' binary not found in PATH" >&2
    exit 1
  fi
fi

REAL_PI_DIR=$(dirname "$REAL_PI")
REAL_PI_RESOLVED_DIR=$(dirname "$(realpath "$REAL_PI")")

# --- Paths -------------------------------------------------------------------
PROJECT_DIR=$(pwd)
HOME_DIR="$HOME"
PI_HOME="${HOME_DIR}/.pi"

# bwrap's --bind fails if the source doesn't exist
mkdir -p "$PI_HOME"

SANDBOX_PATH="/usr/local/bin:/usr/bin:/bin:${HOME_DIR}/.local/bin:${REAL_PI_DIR}:${REAL_PI_RESOLVED_DIR}"

# --- Build bwrap arguments ---------------------------------------------------
args=(
  --unshare-all
  --share-net            # network needed for LLM API calls
  --die-with-parent
  --new-session

  # System (read-only)
  --ro-bind /usr /usr
  --ro-bind-try /bin /bin
  --ro-bind-try /sbin /sbin
  --ro-bind-try /lib /lib
  --ro-bind-try /lib64 /lib64
  --ro-bind-try /etc/resolv.conf /etc/resolv.conf
  --ro-bind-try /etc/ssl /etc/ssl
  --ro-bind-try /etc/ca-certificates /etc/ca-certificates
  --ro-bind-try /etc/hosts /etc/hosts
  --ro-bind-try /etc/passwd /etc/passwd
  --ro-bind-try /etc/group /etc/group
  --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf
  --ro-bind-try /etc/ld.so.cache /etc/ld.so.cache
  --ro-bind-try /etc/alternatives /etc/alternatives

  # Runtime
  --dev /dev
  --proc /proc
  --tmpfs /tmp
  --tmpfs /var/tmp
  --tmpfs /run

  # Project (read-write)
  --bind "$PROJECT_DIR" "$PROJECT_DIR"
  --chdir "$PROJECT_DIR"

  # Pi config & cache (read-write)
  --bind "$PI_HOME" "$PI_HOME"

  # Optional useful read-only bits (delete any you don't want exposed)
  --ro-bind-try "$HOME_DIR/.gitconfig" "$HOME_DIR/.gitconfig"
  --ro-bind-try "$HOME_DIR/.config/gh" "$HOME_DIR/.config/gh"
  --ro-bind-try "$HOME_DIR/.npmrc" "$HOME_DIR/.npmrc"
  --ro-bind-try "$HOME_DIR/.local/bin" "$HOME_DIR/.local/bin"
  --ro-bind-try "$HOME_DIR/.nvm" "$HOME_DIR/.nvm"
  --ro-bind-try "$HOME_DIR/.local/share/fnm" "$HOME_DIR/.local/share/fnm"
  --ro-bind-try "$HOME_DIR/.npm-global" "$HOME_DIR/.npm-global"
  --ro-bind-try "$HOME_DIR/.cargo" "$HOME_DIR/.cargo"
  --ro-bind-try "$HOME_DIR/.rustup" "$HOME_DIR/.rustup"
  # Uncomment ONLY if you need git-over-ssh inside the sandbox.
  # Keep in mind the agent has network access and could read these keys.
  # --ro-bind-try "$HOME_DIR/.ssh" "$HOME_DIR/.ssh"

  # Clean environment
  --clearenv
  --setenv HOME "$HOME_DIR"
  --setenv USER "${USER:-$(id -un)}"
  --setenv PATH "$SANDBOX_PATH"
  --setenv TERM "${TERM:-xterm-256color}"
  --setenv COLORTERM "${COLORTERM:-}"
  --setenv LANG "${LANG:-C.UTF-8}"
)

# Pass through API keys only if they are set outside the sandbox
for var in ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY XAI_API_KEY GOOGLE_API_KEY ZAI_API_KEY; do
  if [[ -n "${!var:-}" ]]; then
    args+=(--setenv "$var" "${!var}")
  fi
done

exec bwrap "${args[@]}" "$REAL_PI" "$@"