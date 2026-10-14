#!/usr/bin/env bash
# opencode-bwrap — lightweight bubblewrap sandbox for the OpenCode coding agent
# Usage: cd /path/to/project && opencode-bwrap [opencode arguments...]

set -euo pipefail

# --- Locate the real opencode binary (skip this wrapper itself) --------------
SCRIPT_PATH=$(realpath "$0")
REAL_BIN=""

while IFS= read -r candidate; do
  if [[ "$(realpath "$candidate")" != "$SCRIPT_PATH" ]]; then
    REAL_BIN="$candidate"
    break
  fi
done < <(type -a -p opencode 2>/dev/null || true)

# Fallback: the official install script puts it in ~/.opencode/bin
if [[ -z "$REAL_BIN" && -x "$HOME/.opencode/bin/opencode" ]]; then
  REAL_BIN="$HOME/.opencode/bin/opencode"
fi

if [[ -z "$REAL_BIN" || "$(realpath "$REAL_BIN")" == "$SCRIPT_PATH" ]]; then
  echo "Error: real 'opencode' binary not found in PATH" >&2
  exit 1
fi

REAL_BIN_DIR=$(dirname "$REAL_BIN")
REAL_BIN_RESOLVED_DIR=$(dirname "$(realpath "$REAL_BIN")")

# --- Paths -------------------------------------------------------------------
PROJECT_DIR=$(pwd)
HOME_DIR="$HOME"

OC_CONFIG="${HOME_DIR}/.config/opencode"
OC_DATA="${HOME_DIR}/.local/share/opencode"
OC_STATE="${HOME_DIR}/.local/state/opencode"
OC_CACHE="${HOME_DIR}/.cache/opencode"

# bwrap's --bind fails if the source doesn't exist
mkdir -p "$OC_CONFIG" "$OC_DATA" "$OC_STATE" "$OC_CACHE"

SANDBOX_PATH="/usr/local/bin:/usr/bin:/bin:${HOME_DIR}/.local/bin:${HOME_DIR}/.opencode/bin:${REAL_BIN_DIR}:${REAL_BIN_RESOLVED_DIR}"

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

  # OpenCode config, data (auth.json, sessions), state and cache (read-write)
  --bind "$OC_CONFIG" "$OC_CONFIG"
  --bind "$OC_DATA" "$OC_DATA"
  --bind "$OC_STATE" "$OC_STATE"
  --bind "$OC_CACHE" "$OC_CACHE"

  # Optional useful read-only bits (delete any you don't want exposed)
  --ro-bind-try "$HOME_DIR/.opencode" "$HOME_DIR/.opencode"
  --ro-bind-try "$HOME_DIR/.gitconfig" "$HOME_DIR/.gitconfig"
  --ro-bind-try "$HOME_DIR/.config/gh" "$HOME_DIR/.config/gh"
  --ro-bind-try "$HOME_DIR/.npmrc" "$HOME_DIR/.npmrc"
  --ro-bind-try "$HOME_DIR/.local/bin" "$HOME_DIR/.local/bin"
  --ro-bind-try "$HOME_DIR/.nvm" "$HOME_DIR/.nvm"
  --ro-bind-try "$HOME_DIR/.local/share/fnm" "$HOME_DIR/.local/share/fnm"
  --ro-bind-try "$HOME_DIR/.npm-global" "$HOME_DIR/.npm-global"
  --ro-bind-try "$HOME_DIR/.bun" "$HOME_DIR/.bun"
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
for var in \
  ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY XAI_API_KEY \
  GOOGLE_API_KEY GEMINI_API_KEY GOOGLE_GENERATIVE_AI_API_KEY \
  GROQ_API_KEY DEEPSEEK_API_KEY MISTRAL_API_KEY ZAI_API_KEY; do
  if [[ -n "${!var:-}" ]]; then
    args+=(--setenv "$var" "${!var}")
  fi
done

# Pass through any OPENCODE_* settings (e.g. OPENCODE_CONFIG)
while IFS= read -r var; do
  args+=(--setenv "$var" "${!var}")
done < <(compgen -v OPENCODE_ || true)

exec bwrap "${args[@]}" "$REAL_BIN" "$@"