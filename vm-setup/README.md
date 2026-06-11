# Secure the VM + private access via Tailscale

Put SSH, RDP, Ollama, and the OpenClaw UI on a **private Tailscale mesh** and
close the public internet off the box. Public SSH stays open as a fallback so
you can't lock yourself out.

```
Before:  internet ──▶ :22 SSH, :3389 RDP, :11434 Ollama   (all public, exposed)

After:   your laptop ─(Tailscale mesh)─▶ SSH / RDP / Ollama / OpenClaw UI
         internet ──▶ :22 SSH only (key-only fallback); everything else DENIED
```

OpenClaw's Telegram bot keeps working throughout — it connects *outbound* to
Telegram and needs no public inbound ports.

## Run order

| # | Script | What it does | Lockout risk |
|---|--------|--------------|--------------|
| 1 | `01-tailscale-setup.sh` | Installs Tailscale, joins the tailnet | None (no firewall change) |
| — | **verify** | From your laptop (Tailscale installed), `ssh`/RDP to the VM's `100.x` tailnet IP | — |
| 2 | `02-lockdown-firewall.sh` | UFW: deny public inbound, allow `tailscale0`, keep public SSH 22 | Low (22 stays open) |
| 3 | `03-harden-ssh.sh` | Make public SSH key-only (optional) | Guarded — refuses if no key present |

```bash
sudo bash 01-tailscale-setup.sh
#   ... then VERIFY tailnet SSH/RDP from your laptop ...
sudo bash 02-lockdown-firewall.sh
sudo bash 03-harden-ssh.sh        # optional; test a new login before closing your session
```

> **Do the verify step.** It's the whole safety net — you confirm the private
> path works *before* you start closing public ports.

## Notes

- **Tailscale auth:** step 1 prints a login URL to approve in any browser. For
  unattended setup, `export TS_AUTHKEY=tskey-...` (an [auth key](https://login.tailscale.com/admin/settings/keys)) before running it.
- **Service binding gotcha:** a service is only reachable over the tailnet if it
  listens on `0.0.0.0` (or the tailnet IP), not just `127.0.0.1`. xrdp already
  does; **Ollama** needs `OLLAMA_HOST=0.0.0.0`; bind the **OpenClaw UI** to
  `0.0.0.0` in its config. The firewall blocks the public side, so `0.0.0.0` is safe.
- **Recovery:** if you ever lose access, DigitalOcean's **web console** (Droplet
  → Access → Launch Console) gets you a root shell with no SSH/network needed.
  To undo the firewall: `sudo ufw disable`. To undo SSH hardening: delete
  `/etc/ssh/sshd_config.d/99-hardening.conf` and `sudo systemctl reload ssh`.
- **Second layer (optional):** mirror these rules in DigitalOcean's cloud
  firewall (control panel) so they hold even if UFW is changed on the host.
- **Going fully private later:** once you trust the tailnet, drop the public SSH
  fallback by removing the `ufw allow 22/tcp` rule (`sudo ufw delete allow 22/tcp`).
