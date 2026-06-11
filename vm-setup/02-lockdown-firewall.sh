#!/usr/bin/env bash
# Step 2 of 2 — lock down the host firewall with UFW.
#
#   * Default DENY all public inbound.
#   * ALLOW everything on the Tailscale interface (tailscale0) -> SSH, RDP/xrdp,
#     Ollama, and your OpenClaw UI are all reachable privately over the tailnet.
#   * Keep public SSH (22) open as a fallback so you can't get locked out.
#
# Run this ONLY after 01-tailscale-setup.sh AND after you've confirmed you can
# reach the VM over Tailscale.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo:  sudo bash $0" >&2
  exit 1
fi

# --- safety check: is Tailscale actually up? ---
if ! tailscale status >/dev/null 2>&1; then
  cat >&2 <<'EOF'
WARNING: Tailscale does not appear to be up.
Public SSH (22) will stay open, so this is low-risk, but RDP/Ollama/OpenClaw
will only be reachable once Tailscale is connected. Recommended: run
01-tailscale-setup.sh and verify tailnet access first.
EOF
  read -r -p "Continue anyway? [y/N] " ans
  [[ "${ans,,}" == "y" ]] || { echo "Aborted."; exit 1; }
fi

if ! command -v ufw >/dev/null 2>&1; then
  echo "==> Installing ufw ..."
  apt-get update -y && apt-get install -y ufw
fi

echo "==> Configuring UFW rules ..."
ufw default deny incoming
ufw default allow outgoing

# All traffic on the Tailscale interface = your private mesh. This single rule
# exposes SSH, RDP (3389), Ollama (11434) and the OpenClaw UI to the tailnet.
ufw allow in on tailscale0 comment 'tailnet: all private services'

# Public SSH fallback. Harden to key-only with 03-harden-ssh.sh.
ufw allow 22/tcp comment 'public SSH fallback'

# Lets Tailscale negotiate fast direct (non-relayed) connections.
ufw allow 41641/udp comment 'tailscale direct connections'

echo "==> Enabling UFW ..."
ufw --force enable

echo
echo "==> Firewall active. Current rules:"
ufw status verbose

cat <<'EOF'

IMPORTANT — a service is reachable over Tailscale only if it LISTENS on the
tailscale interface (or 0.0.0.0), not just 127.0.0.1. The firewall now blocks
the public side, so binding to 0.0.0.0 is safe:
  * xrdp    -> listens on 0.0.0.0:3389 by default. Already reachable.
  * Ollama  -> defaults to 127.0.0.1. Set OLLAMA_HOST=0.0.0.0 (systemd:
               'systemctl edit ollama' -> Environment="OLLAMA_HOST=0.0.0.0')
               and restart it.
  * OpenClaw UI -> bind it to 0.0.0.0 (or the tailnet IP) in OpenClaw's config.

Tip: DigitalOcean also offers a cloud firewall in the control panel. Mirroring
these rules there gives you a second layer that survives even if UFW is changed.
EOF
