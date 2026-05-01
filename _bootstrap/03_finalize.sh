#!/bin/bash
# Finalize bootstrap (force mode for miglio cleanup):
# - kill any process owned by miglio, then delete account
# - UFW + fail2ban + unattended-upgrades
set -euo pipefail

# 1) Remove legacy miglio user (force, even if active sessions)
if id miglio >/dev/null 2>&1; then
  echo "killing processes owned by miglio..."
  pkill -9 -u miglio 2>/dev/null || true
  sleep 1
  /usr/sbin/userdel -f -r miglio 2>/dev/null || /usr/sbin/userdel -f miglio
  echo "[miglio] removed"
fi
rm -f /etc/sudoers.d/99-miglio-temp /etc/sudoers.d/miglio
echo "[miglio] sudoers cleaned"

# 2) UFW
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.0.0/16 to any port 22 proto tcp comment 'SSH from LAN only'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable
echo "--- UFW status ---"
ufw status verbose | head -20

# 3) fail2ban for sshd
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
backend  = systemd
ignoreip = 127.0.0.1/8 ::1 192.168.0.0/16

[sshd]
enabled  = true
port     = ssh
filter   = sshd
mode     = aggressive
EOF
systemctl enable --now fail2ban >/dev/null 2>&1 || true
systemctl restart fail2ban
sleep 2
echo "--- fail2ban sshd jail ---"
fail2ban-client status sshd 2>&1 | head -10 || echo "(fail2ban warming up)"

# 4) unattended-upgrades
cat > /etc/apt/apt.conf.d/52gmzone-unattended-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true

echo "DONE_FINALIZE"
