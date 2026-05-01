#!/bin/bash
# Harden sshd (CAUTIOUS VERSION):
# - keep port 22 (no socket override needed)
# - no root login
# - no password authentication
# - whitelist users (gmiglio, emergency)
# Validates and reloads, never restarts ssh.service or ssh.socket.
set -euo pipefail

# 1) Drop-in hardening conf
cat > /etc/ssh/sshd_config.d/99-gmzone-hardening.conf <<'EOF'
# Managed by gmzone bootstrap - hardening overrides
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
LoginGraceTime 30
AllowUsers gmiglio emergency
EOF
chmod 0644 /etc/ssh/sshd_config.d/99-gmzone-hardening.conf

# 2) Make sure cloud-init drop-in does not re-enable password auth
if [[ -f /etc/ssh/sshd_config.d/50-cloud-init.conf ]]; then
  sed -i 's/^PasswordAuthentication yes/#PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloud-init.conf
fi

# 3) Validate
if ! /usr/sbin/sshd -t; then
  echo "FATAL: sshd config validation failed, removing drop-in and aborting"
  rm -f /etc/ssh/sshd_config.d/99-gmzone-hardening.conf
  exit 1
fi
echo "sshd config validated"

# 4) Reload (no restart, just SIGHUP - existing connections unaffected)
systemctl reload ssh.service 2>/dev/null || systemctl reload ssh 2>/dev/null || true
sleep 1

# 5) Verify still listening on 22
if ss -tlnp 2>/dev/null | grep -q ':22 '; then
  echo "OK: sshd still listening on port 22"
else
  echo "WARN: cannot confirm 22, dump:"
  ss -tlnp || true
fi

echo "DONE_SSHD_HARDENING_V2"
