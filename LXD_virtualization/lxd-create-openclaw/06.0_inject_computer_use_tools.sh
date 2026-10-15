#!/bin/bash
# =============================================================================
# 
# Run inside the VM as root.
# Injects computer_use_helper.sh docs into TOOLS.md for all agents.
# Safe to re-run — skips agents that already have the section.
#
# VM layout:
#   openclaw → runs openclaw service + agent processes + computer_use_helper.sh
#   openclaw → owns the desktop session (DISPLAY=:0, lightdm)
# =============================================================================

set -euo pipefail

APP_USER="openclaw"
VM_NAME="ocvm01"
AGENT="main"
USER_HOME="/home/${APP_USER}"
HELPER_SCRIPT="${USER_HOME}/computer_use_helper.sh"
OPENCLAW_BASE="${USER_HOME}/.openclaw"
WORKSPACE="${OPENCLAW_BASE}/workspace"
TOOLS_FILE="${WORKSPACE}/TOOLS.md"

TOOLS_SECTION="
---

## Computer Use (Desktop Automation)

Agents can control the desktop GUI of the ${VM_NAME} VM using the helper script at \`${HELPER_SCRIPT}\`.

### VM User Layout
- \`${APP_USER}\` — runs openclaw service and agent processes; owns the helper script and the desktop session (DISPLAY=:0, lightdm)

### Invocation
The helper script internally exports \`DISPLAY=:0\` and \`XAUTHORITY=${USER_HOME}/.Xauthority\`:
\`\`\`bash
# Standard — call directly as ${APP_USER} inside the VM
${HELPER_SCRIPT} <command> [args]

# Fallback — only if xdotool reports display/auth errors
su - ${APP_USER} -c '${HELPER_SCRIPT} <command> [args]'
\`\`\`

### Critical Rules
- Always call \`screenshot\` **before** any interaction — never assume coordinates.
- Always call \`screenshot\` **after** each action to verify before proceeding.
- Never guess coordinates — screenshot → identify → act → verify.

### Commands

#### \`screenshot [output_path]\`
Capture the current screen. Do this before every interaction.
\`\`\`bash
${HELPER_SCRIPT} screenshot /tmp/screen.png
# Omit path to auto-generate: /tmp/screenshot_<timestamp>.png
\`\`\`

#### \`position\`
Get current mouse X,Y coordinates and window ID under cursor.
\`\`\`bash
${HELPER_SCRIPT} position
\`\`\`

#### \`click X Y\`
Move mouse to X,Y and left-click.
\`\`\`bash
${HELPER_SCRIPT} click 500 400
\`\`\`

#### \`rclick X Y\`
Move mouse to X,Y and right-click (opens context menus).
\`\`\`bash
${HELPER_SCRIPT} rclick 500 400
\`\`\`

#### \`dclick X Y\`
Move mouse to X,Y and double left-click (opens files, folders, apps).
\`\`\`bash
${HELPER_SCRIPT} dclick 500 400
\`\`\`

#### \`type \"TEXT\"\`
Type a string at the current cursor position (40ms keystroke delay).
Always \`click\` the target input field before calling this.
\`\`\`bash
${HELPER_SCRIPT} type \"Hello World\"
\`\`\`

#### \`key KEY\`
Press a key or key combination in xdotool format.
\`\`\`bash
${HELPER_SCRIPT} key Return
${HELPER_SCRIPT} key Escape
${HELPER_SCRIPT} key Tab
${HELPER_SCRIPT} key BackSpace
${HELPER_SCRIPT} key ctrl+c
${HELPER_SCRIPT} key ctrl+v
${HELPER_SCRIPT} key ctrl+z
${HELPER_SCRIPT} key ctrl+alt+t
${HELPER_SCRIPT} key alt+F4
${HELPER_SCRIPT} key super
\`\`\`

#### \`windows\`
List all open windows with ID, desktop number, and title.
\`\`\`bash
${HELPER_SCRIPT} windows
\`\`\`

#### \`focus \"WINDOW TITLE\"\`
Bring a window to the foreground by partial title match (case-sensitive).
Always call \`windows\` first to find the correct title substring.
\`\`\`bash
${HELPER_SCRIPT} focus \"Firefox\"
${HELPER_SCRIPT} focus \"Terminal\"
\`\`\`

#### \`open APP [ARGS]\`
Launch an application in the background on the display.
\`\`\`bash
${HELPER_SCRIPT} open firefox
${HELPER_SCRIPT} open gnome-terminal
${HELPER_SCRIPT} open gedit /tmp/notes.txt
\`\`\`

### Standard Workflow
\`\`\`
1. screenshot          → observe current screen state
2. identify target     → determine X,Y from the image
3. click/dclick/focus  → interact with the target
4. type / key          → enter text or trigger shortcuts
5. screenshot          → verify result before next step
\`\`\`
"

# ── Inject into agent workspace ───────────────────────────────────────────────
echo "============================================="
echo " Injecting computer_use tools into TOOLS.md"
echo "============================================="

mkdir -p "${WORKSPACE}"

# Skip if already injected
if [[ -f "${TOOLS_FILE}" ]] && grep -q "Computer Use (Desktop Automation)" "${TOOLS_FILE}" 2>/dev/null; then
  echo "  [~] ${AGENT}: already has computer_use section — skipped"
  exit 0
fi

# Create TOOLS.md from scratch if missing
if [[ ! -f "${TOOLS_FILE}" ]]; then
  cat > "${TOOLS_FILE}" <<'HEADER'
# TOOLS.md - Local Notes
Skills define _how_ tools work. This file is for _your_ specifics — the stuff that is unique to your setup.

---
HEADER
  echo "  [+] ${AGENT}: created TOOLS.md"
fi

# Append computer use section
echo "${TOOLS_SECTION}" >> "${TOOLS_FILE}"
chown -R "${APP_USER}:${APP_USER}" "${WORKSPACE}"
echo "  [+] ${AGENT}: injected computer_use section"

echo ""
echo "============================================="
echo " Done. Verify with:"
echo ""
echo "   cat ${WORKSPACE}/${TOOLS_FILE}"
echo "============================================="
echo ""
echo "   lxc file push ./openclaw.json "${VM_NAME}/${OPENCLAW_BASE}/openclaw.json" "
echo "  inside the vm: chown ${APP_USER}:${APP_USER} /home/${APP_USER}/.openclaw/openclaw.json "
echo ""
# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================="
echo " Configuration complete!"
echo "============================================="
echo ""
echo "   lxc exec ${VM_NAME} -- bash  "
echo ""
echo "   su - openclaw"
echo ""
echo " Now run OpenClaw onboarding:"
echo "   openclaw onboard"
echo "
echo "   openclaw gateway restart"
echo ""
echo "lxc exec ${VM_NAME} -- bash -c "mkdir -p /home/${APP_USER}/.ssh && echo '$(cat ~/.ssh/id_rsa.pub)' >> /home/${APP_USER}/.ssh/authorized_keys && chmod 600 /home/${APP_USER}/.ssh/authorized_keys && chown -R ${APP_USER}:${APP_USER} /home/${APP_USER}/.ssh"

