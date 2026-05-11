# homehunter stack

App per la ricerca casa in Italia. Codice sorgente: [`giagione9/gmzone-it-homehunter`](https://github.com/giagione9/gmzone-it-homehunter).

## Servizi

| Service | Image | Network(s) | Note |
|---|---|---|---|
| `app` | `ghcr.io/giagione9/gmzone-it-homehunter:${IMAGE_TAG}` | `proxy`, `homehunter-internal` | Next.js 15 standalone, non-root UID 10001, healthcheck `/api/health` |
| `db` | `postgis/postgis:16-3.4-alpine` | `homehunter-internal` | Postgres 16 + PostGIS, mai esposto al proxy |

## Reti

- **`proxy`** (external) — solo `app`. Usata da NPM per il routing pubblico.
- **`homehunter-internal`** (bridge interno) — `app` ↔ `db`. Isolata.

## Volumi

- `homehunter_pgdata` → `/var/lib/postgresql/data`. **Includere nel backup Veeam.**

## Deploy

```bash
# Prima volta
cp .env.example .env
nano .env   # popolare POSTGRES_PASSWORD, NEXTAUTH_SECRET, GOOGLE_*, ORS_API_KEY
docker compose pull
docker compose up -d
docker compose logs -f app

# Aggiornamenti
docker compose pull && docker compose up -d
```

## NPM configurazione

Proxy Host:
- Domain: `homehunter.gmzone.it`
- Forward: `http://homehunter:3000`
- SSL: Let's Encrypt, Force SSL, HTTP/2, HSTS
- Common: Block Common Exploits

## Operations

```bash
# Logs
docker compose logs -f app
docker compose logs -f db

# Migration manuale (di solito non serve, le applica l'entrypoint)
docker compose exec app node node_modules/prisma/build/index.js migrate deploy

# psql nel DB
docker compose exec db psql -U homehunter -d homehunter

# Backup manuale rapido (oltre a Veeam)
docker compose exec db pg_dump -U homehunter homehunter | gzip > "homehunter-$(date +%F).sql.gz"
```

## Pull GHCR (solo se il package non è public)

```bash
echo $GHCR_PAT | docker login ghcr.io -u giagione9 --password-stdin
```

Per evitarlo, rendi il package pubblico:
`https://github.com/giagione9/gmzone-it-homehunter/pkgs/container/gmzone-it-homehunter/settings`
→ Change visibility → Public.

## Troubleshooting

- **App non parte / loop di restart**: `docker compose logs app` — quasi sempre è `DATABASE_URL` errato o `db` non ancora healthy
- **`docker compose pull` fallisce con `denied`**: il package GHCR non è public e non hai fatto login (vedi sopra)
- **Migration fallisce**: la pipeline potrebbe aver introdotto una migration che non si applica → rollback al tag precedente con `IMAGE_TAG=sha-xxxxxx` in `.env`
- **/api/health 502 da NPM**: verifica che `app` sia connesso alla rete `proxy` con `docker network inspect proxy`
