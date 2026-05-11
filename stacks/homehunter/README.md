# homehunter — stack

App Next.js per la ricerca casa in Italia.
Source: https://github.com/giagione9/gmzone-it-homehunter

## Layout

```
homehunter/
├── docker-compose.yml      # app + db (postgis)
├── .env.example            # template variabili runtime
├── .env                    # (gitignored) valori reali
└── data/
    └── postgres/           # (gitignored) volume Postgres persistente
```

## Network

- `app` → reti `proxy` (ingress NPM) + `internal` (verso db)
- `db`  → solo `internal`, nessuna esposizione

Nessuna porta è mappata sull'host: ingress solo via NPM.

## Primo deploy

```bash
ssh gmiglio@<homelab-ip>
cd ~/gmzone-infra/stacks/homehunter

cp .env.example .env
nano .env                      # popola password e secret

docker compose pull
docker compose up -d
docker compose logs -f app

# verifica health
docker compose exec app wget -qO- http://127.0.0.1:3000/api/health
```

L'entrypoint del container applica le migrazioni Prisma al boot.

## Aggiornamento (deploy normale)

```bash
cd ~/gmzone-infra/stacks/homehunter
docker compose pull
docker compose up -d
docker compose logs -f app
```

## NPM Proxy Host

Configurazione UI di Nginx Proxy Manager dopo il primo `up`:

- Domain Names: `homehunter.gmzone.it`
- Forward Hostname / Port: `homehunter` / `3000`, schema `http`
- ✅ Block Common Exploits
- SSL: Let's Encrypt + Force SSL + HTTP/2 + HSTS

## Backup Postgres (manuale)

```bash
docker compose exec -T db pg_dump -U homehunter -d homehunter \
  | gzip > ~/backups/homehunter-$(date +%F).sql.gz
```

## Reset completo (⚠️ cancella dati)

```bash
docker compose down -v
rm -rf data/postgres
```

## Migration manuale (se serve forzare)

```bash
docker compose exec app node node_modules/prisma/build/index.js migrate deploy
```
