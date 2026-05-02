# Crowdsec stack

Engine in container + host firewall bouncer (apt). See `_bootstrap/05_install_crowdsec.sh` for initial install.

## Files in this directory

| File | Committed to git | Purpose |
|---|---|---|
| `docker-compose.yml` | ✅ | service definition |
| `acquis-nginx.yaml` | ✅ | tells crowdsec which logs to read (NPM proxy host logs) |
| `notifications-telegram.yaml.example` | ✅ | template for the Telegram http notifier |
| `profiles.yaml.example` | ✅ | template profile that wires the notifier into ban decisions |
| **runtime files (bind-mounted, not in git):** | | |
| `data/` | ❌ | crowdsec database, machine identity |
| `config/notifications/telegram.yaml` | ❌ | **REAL** notifier config with bot token |
| `config/profiles.yaml` | ❌ | live profile in use by the engine |

## Adding Telegram alerts

Run **once on the server**:

```bash
ssh -i ~/.ssh/server_gmzone gmiglio@192.168.40.40

# 1) Create the notifier config (you'll paste your token + chat_id)
sudo install -d -m 0750 -o 1000 -g 1000 /opt/gmzone/crowdsec/config/notifications
sudo nano /opt/gmzone/crowdsec/config/notifications/telegram.yaml
# → paste the content of notifications-telegram.yaml.example
# → replace <BOT_TOKEN> and <CHAT_ID> with the real values
sudo chmod 0600 /opt/gmzone/crowdsec/config/notifications/telegram.yaml
sudo chown 1000:1000 /opt/gmzone/crowdsec/config/notifications/telegram.yaml

# 2) Update the profile to attach the notifier
sudo cp /opt/gmzone/crowdsec/config/profiles.yaml /opt/gmzone/crowdsec/config/profiles.yaml.bak
sudo nano /opt/gmzone/crowdsec/config/profiles.yaml
# → replace content with profiles.yaml.example (already templated correctly)

# 3) Reload crowdsec
docker restart crowdsec

# 4) Verify the notifier is loaded
docker exec crowdsec cscli notifications list
# should show: telegram_alert (http)
```

## Test it

Force a fake ban and check Telegram:

```bash
docker exec crowdsec cscli decisions add --ip 192.0.2.1 --reason "telegram test" --duration 1m
```

You should receive a Telegram message within ~10 seconds (group_wait).
The fake ban will auto-expire after 1 minute.

## Useful runtime commands

```bash
# Live alert feed
docker exec crowdsec cscli alerts list

# Active decisions (= currently banned IPs)
docker exec crowdsec cscli decisions list

# Re-load notifications config without container restart
docker exec crowdsec kill -HUP 1     # crowdsec reloads on SIGHUP
```
