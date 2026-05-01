#!/bin/bash
# Crowdsec setup:
# 1) Add the Crowdsec apt repo (so we can install the host firewall bouncer)
# 2) Start the crowdsec engine via docker compose
# 3) Install host-level firewall bouncer (apt) - enforces bans via iptables
# 4) Generate API key, register the bouncer with crowdsec, configure, start
set -euo pipefail

STACK_DIR=/opt/gmzone/crowdsec

# 0) Cleanup previous failed attempt (idempotency)
cd "$STACK_DIR"
docker compose down 2>/dev/null || true
# Remove old metabase remnant if present
rm -rf "$STACK_DIR/metabase"

# 1) Add Crowdsec apt repository (packagecloud)
if ! [[ -f /etc/apt/sources.list.d/crowdsec_crowdsec.list ]]; then
  curl -s https://install.crowdsec.net | bash
fi
echo "[1/4] Crowdsec apt repo configured"

# 2) Bring up the engine
docker compose up -d
echo "[2/4] crowdsec engine starting"

# Wait for crowdsec API to be ready (max 60s)
for i in $(seq 1 60); do
  if docker exec crowdsec cscli lapi status >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker exec crowdsec cscli lapi status >/dev/null 2>&1 || {
  echo "FATAL: crowdsec API never became ready"; exit 1;
}
echo "[2/4] crowdsec API responsive"

# 3) Install host firewall bouncer
DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y crowdsec-firewall-bouncer-iptables
echo "[3/4] firewall bouncer installed"

# 4) Generate API key and register the bouncer
BOUNCER_NAME="firewall-bouncer-host"
docker exec crowdsec cscli bouncers delete "$BOUNCER_NAME" 2>/dev/null || true
API_KEY=$(docker exec crowdsec cscli bouncers add "$BOUNCER_NAME" -o raw)
if [[ -z "$API_KEY" ]]; then
  echo "FATAL: could not generate API key for bouncer"; exit 1
fi

cat > /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml <<EOF
# Managed by gmzone bootstrap
mode: iptables
update_frequency: 10s
include_scopes: ["Ip", "Range"]
only_drop_on_local_ip: false
log_mode: file
log_dir: /var/log/
log_level: info
log_compression: true
log_max_size: 100
log_max_backups: 3
log_max_age: 30
api_url: http://127.0.0.1:8080/
api_key: ${API_KEY}
disable_ipv6: false
deny_action: DROP
deny_log: false
supported_decisions_types:
  - ban
iptables_chains:
  - INPUT
  - FORWARD
  - DOCKER-USER
EOF
chmod 0600 /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml

systemctl enable --now crowdsec-firewall-bouncer
sleep 2
echo "[4/4] firewall bouncer enabled"

echo ""
echo "=== sanity checks ==="
echo "Bouncers registered:"
docker exec crowdsec cscli bouncers list -o human
echo ""
echo "Active decisions (should be empty for now):"
docker exec crowdsec cscli decisions list -o human || true
echo ""
echo "Bouncer service status:"
systemctl is-active crowdsec-firewall-bouncer

echo "DONE_CROWDSEC"
