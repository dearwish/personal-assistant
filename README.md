# personal-assistant

Self-hosted setup for my [OpenClaw](https://openclaw.ai/) personal assistant
running on a VM: the foundational hardening first, then skills/agents added over
time.

## Contents

### `vm-setup/` — secure the box + private access

Lock the server down to a private [Tailscale](https://tailscale.com/) mesh and
close the public internet off it, keeping a key-only SSH fallback so you can't
get locked out. Three ordered scripts (Tailscale → UFW lockdown → key-only SSH)
with a verification gate and recovery notes.

→ See [vm-setup/README.md](vm-setup/README.md) for the run order and details.

## Coming later

- **Skills / agents** — each a self-contained folder, installed into OpenClaw.
  First up: a **Gmail RAG** skill (chat with your inbox over Telegram). Others
  to follow.
