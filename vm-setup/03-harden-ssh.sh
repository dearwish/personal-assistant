#!/usr/bin/env bash
# Optional — make public SSH key-only (disable password login).
# REFUSES to run if no authorized_keys exists, so you can't lock yourself out.
# Keep your current SSH session open and test a NEW login before closing it.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo:  sudo bash $0" >&2
  exit 1
fi

# --- safety check: at least one non-empty authorized_keys must exist ---
has_key=0
while IFS= read -r f; do
  [[ -s "$f" ]] && has_key=1
done < <(find /root/.ssh /home/*/.ssh -maxdepth 1 -name authorized_keys 2>/dev/null)

if [[ "$has_key" -ne 1 ]]; then
  cat >&2 <<'EOF'
ABORT: no non-empty ~/.ssh/authorized_keys found.
Add your public key first (from your laptop:  ssh-copy-id user@host
or paste it into ~/.ssh/authorized_keys on the VM), or disabling password
auth would lock you out.
EOF
  exit 1
fi

conf=/etc/ssh/sshd_config.d/99-hardening.conf
echo "==> Writing $conf ..."
cat > "$conf" <<'EOF'
# Key-only SSH. Managed by 03-harden-ssh.sh
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin prohibit-password
EOF

echo "==> Validating sshd config ..."
sshd -t

echo "==> Reloading SSH ..."
systemctl reload ssh 2>/dev/null || systemctl reload sshd

cat <<'EOF'
Done — password SSH is disabled (key-only now).
DO NOT close this session yet: open a NEW terminal and confirm you can still
ssh in. If something's wrong, revert by deleting
/etc/ssh/sshd_config.d/99-hardening.conf and reloading ssh.
EOF
