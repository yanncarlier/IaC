# OpenClaw — LXD VM + SPICE + Full Computer-Use Setup

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   YOUR UBUNTU HOST                       │
│                                                          │
│   ┌─────────────────────────────────────────────────┐   │
│   │          LXD VM  "ocvm01"                        │   │
│   │          Ubuntu 25.10 Desktop (questing)         │   │
│   │                                                  │   │
│   │  ┌──────────────┐   ┌─────────────────────────┐ │   │
│   │  │  XFCE Desktop│   │  OpenClaw (Node.js CLI) │ │   │
│   │  │  auto-login  │   │  runs as systemd service │ │   │
│   │  └──────┬───────┘   └────────────┬────────────┘ │   │
│   │         │                        │               │   │
│   │  ┌──────▼───────────────────────▼────────────┐  │   │
│   │  │           Input/Vision Layer               │  │   │
│   │  │  xdotool  │  scrot  │  wmctrl  │ Playwright│  │   │
│   │  └───────────────────────────────────────────┘  │   │
│   │                                                  │   │
│   │  ┌───────────────────────────────────────────┐  │   │
│   │  │  Google Chrome + Chromium (headful)        │  │   │
│   │  │  remote-debugging-port=9222                │  │   │
│   │  └───────────────────────────────────────────┘  │   │
│   │                                                  │   │
│   │  ┌───────────────────────────────────────────┐  │   │
│   │  │  SPICE unix socket (local only)            │  │   │
│   │  │  QXL video + spice-vdagent                │  │   │
│   │  └───────────────────────────────────────────┘  │   │
│   └─────────────────────────────────────────────────┘   │
│                        │ SPICE                           │
│              ┌──────────▼──────────┐                     │
│              │  remote-viewer /    │                     │
│              │  virt-viewer        │                     │
│              │  (you watch here)   │                     │
│              └─────────────────────┘                     │
└─────────────────────────────────────────────────────────┘
                          │ Internet
                   WhatsApp / Telegram
                   Claude API / OpenAI
```

---

## Prerequisites (Host)

```bash
sudo apt install lxd virt-viewer
# 01.0_host_create_vm.sh will run `lxd init --auto` if needed
```

---

## Step-by-Step

### Step 1 — Run on HOST (create VM)
```bash
chmod +x 01.0_host_create_vm.sh
./01.0_host_create_vm.sh
```
Creates the VM and stops it for boot-time configuration.

---

### Step 2 — Run on HOST (configure + start VM, push scripts)
```bash
chmod +x 02.0_host_config_and_start.sh
./02.0_host_config_and_start.sh
```
Applies boot config, starts the VM, and pushes the in-VM scripts.

---

### Step 3 — Run INSIDE the VM (base setup)
```bash
# Option A: exec directly from host
lxc exec ocvm01 -- bash /root/03.0_vm_setup.sh

# Option B: connect via SPICE first, open terminal, then run
bash /root/03.0_vm_setup.sh
```

Installs: XFCE + LightDM auto-login, SPICE guest agent, xdotool/wmctrl/scrot,
Google Chrome, Node.js LTS, pnpm, and OpenClaw. VM reboots automatically.

---

### Step 4 — Connect via SPICE (from host)
```bash
# Option A: VGA console (simplest)
lxc console ocvm01 --type=vga

# Option B: SPICE unix socket (virt-viewer / remote-viewer)
remote-viewer spice+unix:///var/snap/lxd/common/lxd/logs/ocvm01/qemu.spice
```
You will see the XFCE desktop auto-logged in as the `openclaw` user.

---

### Step 5 — Configure OpenClaw (inside VM)
```bash
# Option A: exec directly from host
lxc exec ocvm01 -- bash /root/05.0_openclaw_configure.sh

# Option B: connect via SPICE first, open terminal, then run
bash /root/05.0_openclaw_configure.sh
```
Installs computer-use skill, Playwright browser skill, and the systemd user service.

---

### Step 6 — (Optional) SSH + Firewall hardening (inside VM)
```bash
# Option A: exec directly from host
lxc exec ocvm01 -- bash /root/04.0_vm_setup.sh

# Option B: connect via SPICE first, open terminal, then run
bash /root/04.0_vm_setup.sh
```

---

### Step 7 — (Optional) Inject computer-use helper docs into TOOLS.md
```bash
# Option A: exec directly from host
lxc exec ocvm01 -- bash /root/06.0_inject_computer_use_tools.sh

# Option B: connect via SPICE first, open terminal, then run
bash /root/06.0_inject_computer_use_tools.sh
```

---

### Step 8 — Onboard OpenClaw
```bash
openclaw onboard
```
Set your API key, connect your chat app, name your assistant.

---

## How OpenClaw Controls the Desktop

### Screenshot
```bash
~/computer_use_helper.sh screenshot /tmp/screen.png
```

### Click at coordinates
```bash
~/computer_use_helper.sh click 640 400
```

### Type text
```bash
~/computer_use_helper.sh type "Hello from OpenClaw"
```

### Open Chrome to a URL
```bash
DISPLAY=:0 google-chrome "https://example.com" &
```

### Playwright browser control
```javascript
// /tmp/task.mjs
import { chromium } from '/home/openclaw/node_modules/playwright/index.mjs';
const browser = await chromium.launch({ headless: false });
const page = await browser.newPage();
await page.goto('https://gmail.com');
await page.screenshot({ path: '/tmp/gmail.png' });
await browser.close();
```

---

## Anthropic Computer-Use Style Loop

1. **See** — `scrot /tmp/screen.png` → pass to Claude vision
2. **Think** — Claude identifies what to click/type next
3. **Act** — `xdotool` executes the action
4. **Repeat** — loop until task is complete

Works for ANY desktop app visible in the SPICE window.

---

## Useful Commands

```bash
# Watch OpenClaw logs live (user service)
lxc exec ocvm01 -- sudo -u openclaw -- journalctl --user -u openclaw -f

# Shell as openclaw user
lxc exec ocvm01 -- sudo -u openclaw bash

# Restart OpenClaw
lxc exec ocvm01 -- sudo -u openclaw -- systemctl --user restart openclaw

# Pause/resume VM
lxc pause ocvm01 && lxc start ocvm01
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| SPICE black screen | Wait 30s; check `systemctl status lightdm` inside VM |
| xdotool not found | `apt install xdotool` inside VM |
| Chrome won't open | Try `DISPLAY=:0 google-chrome --no-sandbox` |
| OpenClaw not receiving messages | Check API key with `openclaw config` |
| VM too slow | Increase CPUs/RAM in `01_host_create_vm.sh` |
