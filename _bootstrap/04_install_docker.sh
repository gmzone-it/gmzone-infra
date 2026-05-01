#!/bin/bash
# Install Docker Engine + compose plugin from official Docker repo
# (NOT docker.io from Ubuntu - that's older and less maintained)
set -euo pipefail

# 1) Prereqs
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg lsb-release

# 2) Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

# 3) Add Docker repo
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

# 4) Install
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5) Enable + start
systemctl enable --now docker

# 6) Add gmiglio to docker group (so he can run docker without sudo)
#    SECURITY NOTE: docker group membership is effectively root-equivalent.
#    For homelab single-user this is acceptable.
usermod -aG docker gmiglio

# 7) Create stack base dir owned by gmiglio
install -d -m 0755 -o gmiglio -g gmiglio /opt/gmzone

# 8) Create the shared 'proxy' network now (so NPM and services can attach)
docker network inspect proxy >/dev/null 2>&1 || docker network create proxy

# 9) Verify
echo "--- docker ---"
docker --version
docker compose version
echo "--- service ---"
systemctl is-active docker
echo "--- networks ---"
docker network ls
echo "DONE_DOCKER"
