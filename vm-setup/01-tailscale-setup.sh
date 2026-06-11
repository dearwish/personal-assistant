#!/usr/bin/env bash
# Step 1 of 2 — install Tailscale and join the tailnet.
# Does NOT touch the firewall, so it's safe to run over your current public SSH
# session. After this, VERIFY you can reach the VM over Tailscale, THEN run
# 02-lockdown-firewall.sh.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo:  sudo bash $0" >&2
  exit 1
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "==> Installing Tailscale ..."
  curl -fsSL https://tailscale.com/install.sh | sh
else
  echo "==> Tailscale already installed: $(tailscale version | head -n1)"
fi

echo "==> Bringing Tailscale up ..."
# Non-interactive option: export TS_AUTHKEY=tskey-... before running this script
# (generate one at https://login.tailscale.com/admin/settings/keys).
if [[ -n "${TS_AUTHKEY:-}" ]]; then
  tailscale up --authkey "$TS_AUTHKEY"
else
  echo "    A login URL will be printed below — open it on any device and approve."
  tailscale up
fi

echo
echo "==> Tailscale is up. This VM's private (tailnet) IP:"
tailscale ip -4 || true

cat <<'EOF'

NEXT — verify private access BEFORE locking down the firewall.
Install Tailscale on your laptop (same account), then from the laptop:

    ssh <user>@<tailnet-ip-above>          # shell over the tailnet
    # RDP your client to  <tailnet-ip-above>:3389   for the desktop

Once that works, run:   sudo bash 02-lockdown-firewall.sh

(Optional: 'sudo tailscale up --ssh' enables Tailscale-managed SSH over the
tailnet — no SSH key needed for tailnet logins, authorized via your tailnet
ACLs. Coexists with normal sshd.)
EOF
