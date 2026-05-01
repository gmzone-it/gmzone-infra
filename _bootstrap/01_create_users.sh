#!/bin/bash
# Bootstrap users for gmzone server
# - Creates gmiglio (daily driver) and emergency (break-glass) accounts
# - Both with sudo NOPASSWD (access protected by SSH key only)
# - SSH keys deployed from authorized public keys
set -euo pipefail

GMIGLIO_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIvk0JmrlFXmq/8oF+P/I1nxXdOkTpbiH6Q8Xlo12xZ1 server-gmzone"
EMERGENCY_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIgysK9lWurxJC2QXr1nqTtirz2/P1uwLEJAiScdSnW5 emergency-gmzone"

create_user() {
  local USER_NAME=$1
  local PUBKEY=$2

  if id "$USER_NAME" >/dev/null 2>&1; then
    echo "[$USER_NAME] already exists, skipping create"
  else
    /usr/sbin/useradd -m -s /bin/bash -G sudo "$USER_NAME"
    echo "[$USER_NAME] created"
  fi

  install -d -m 0700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
  echo "$PUBKEY" > "/home/$USER_NAME/.ssh/authorized_keys"
  chmod 0600 "/home/$USER_NAME/.ssh/authorized_keys"
  chown "$USER_NAME":"$USER_NAME" "/home/$USER_NAME/.ssh/authorized_keys"
  echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USER_NAME"
  chmod 0440 "/etc/sudoers.d/$USER_NAME"
  echo "[$USER_NAME] ssh key + sudoers OK"
}

create_user gmiglio "$GMIGLIO_PUBKEY"
create_user emergency "$EMERGENCY_PUBKEY"

echo "--- verification ---"
echo "gmiglio sudo: $(/usr/bin/sudo -l -U gmiglio | tail -1)"
echo "emergency sudo: $(/usr/bin/sudo -l -U emergency | tail -1)"
ls -la /home/gmiglio/.ssh/ /home/emergency/.ssh/
echo "DONE_USERS"
