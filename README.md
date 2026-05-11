# Retro Hotel Docker Starter

A private-project Docker starter for an open-source retro hotel stack based on an upstream Nitro + Arcturus/Morningstar Docker setup.

This scaffold is designed for a VPS or server where you want a repeatable Docker deployment with safer defaults than exposing every service directly.

## What is included

- `compose.local.yml` for local or first-time testing.
- `compose.prod.caddy.yml` for public deployment behind Caddy with HTTPS.
- Scripts to pull the upstream open-source stack into `vendor/nitro-docker`.
- Environment rendering for the upstream `.env` and `.cms.env` files.
- A SQL settings template for public domain settings.
- A basic Nitro URL patcher for localhost-to-domain replacements.
- A helper script to create a private GitHub repository using the GitHub CLI.

## What is not included

- Official Habbo/Sulake assets.
- A license to use the Habbo name, trademarks, trade dress, or proprietary assets.
- A production-ready user/account policy, moderation policy, or payment setup.

Use your own branding and assets for public deployment.

## Requirements

On your VPS:

```bash
sudo apt update
sudo apt install -y git curl unzip ca-certificates
```

Install Docker Engine and the Docker Compose plugin using Docker's official instructions for your OS.

Optional for pushing to GitHub:

```bash
sudo apt install -y gh
```

Then authenticate:

```bash
gh auth login
```

## Fast start

```bash
unzip retro-hotel-docker-starter.zip
cd retro-hotel-docker-starter
cp .env.example .env
nano .env
./scripts/bootstrap-upstream.sh
```

For first local-style testing:

```bash
./scripts/up-local.sh
```

Local ports:

| Service | URL / port |
|---|---|
| Nitro client | `http://SERVER_IP:3000` |
| Assets | `http://SERVER_IP:8080` |
| CMS | `http://SERVER_IP:8081` |
| WebSocket | `ws://SERVER_IP:2096` |
| MySQL | `127.0.0.1:3310` only |

For public deployment with Caddy HTTPS:

```bash
./scripts/up-caddy.sh
```

Public domains from `.env`:

| Variable | Purpose |
|---|---|
| `DOMAIN_CMS` | CMS / website host, for example `example.com` |
| `DOMAIN_GAME` | Nitro client host, for example `game.example.com` |
| `DOMAIN_ASSETS` | asset server host, for example `assets.example.com` |
| `DOMAIN_WS` | websocket host, for example `ws.example.com` |

Create DNS `A` or `AAAA` records for all of them pointing at your VPS before starting the Caddy deployment.

## First-time database and asset setup

This starter pulls the upstream repository but does not bypass its required setup. After bootstrap, read:

```bash
vendor/nitro-docker/README.md
```

The usual first-time tasks are:

1. Populate assets you are legally allowed to use.
2. Start the database.
3. Import the Arcturus base SQL and update SQL files.
4. Apply public URL settings.
5. Build/start assets, emulator, Nitro, and CMS.
6. Generate the AtomCMS Laravel `APP_KEY`.
7. Run CMS migrations/seeding.

During bootstrap, the scripts also try to patch common localhost URLs in `vendor/nitro-docker/nitro/renderer-config.json` and `vendor/nitro-docker/nitro/ui-config.json`. Review those files manually before public launch.

The rendered helper SQL is created at:

```bash
generated/public-settings.sql
```

Import it after the base database exists.

## Public deployment security notes

The production Caddy compose file exposes only ports `80` and `443` from the VPS. MySQL and RCON are kept internal. Do not expose MySQL, RCON, or default SSO/admin flows publicly.

Minimum checklist before going online:

- Replace every `CHANGE_ME_*` value in `.env`.
- Use your own domain names.
- Use original branding and assets.
- Import SQL updates correctly.
- Run backups and test restore.
- Restrict SSH access to your VPS.
- Put Cloudflare or another DDoS layer in front if you expect public traffic.

## Create a private GitHub repository

With GitHub CLI installed and authenticated:

```bash
./scripts/create-private-github-repo.sh my-private-retro-hotel
```

By default, `vendor/` is ignored so you push only this scaffold, not a cloned copy of upstream. That keeps your private repo lightweight and avoids accidentally committing assets or secrets.

## Useful commands

```bash
./scripts/logs.sh local
./scripts/logs.sh caddy
./scripts/backup-now.sh caddy
./scripts/down.sh local
./scripts/down.sh caddy
```

## Folder layout

```text
.
├── caddy/Caddyfile
├── compose.local.yml
├── compose.prod.caddy.yml
├── docs/
├── scripts/
├── sql/public-settings.sql.template
├── generated/
└── vendor/                 # created by bootstrap; ignored by git
```
