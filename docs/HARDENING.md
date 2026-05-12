# Production hardening checklist

## Network exposure

The server compose file exposes only the Caddy proxy ports:

- `80/tcp`
- `443/tcp`

Keep these internal:

- MySQL `3306/tcp`
- RCON `3001/tcp`
- Direct Nitro/assets/CMS ports
- Direct emulator websocket port, unless you intentionally bypass Caddy

## Secrets

Run:

```bash
./scripts/generate-secrets.sh
```

Then edit `.env` manually to set real domains and email.

Never commit `.env`, database dumps, or asset packs to GitHub.

## WebSocket

For the server setup, configure the Nitro client to use:

```text
wss://$DOMAIN_WS
```

If the upstream Nitro config still points to localhost, update:

```text
vendor/nitro-docker/nitro/renderer-config.json
vendor/nitro-docker/nitro/ui-config.json
```

Search for:

```text
127.0.0.1
localhost
ws://
wss://
```

## Database

Use `127.0.0.1:3310` only for local maintenance over SSH tunneling. Do not bind MySQL to `0.0.0.0` on a public VPS.

## Backups

Create a manual backup:

```bash
./scripts/backup-now.sh server
```

Check files under:

```text
vendor/nitro-docker/db/backup/
```

Test restore before you rely on backups.

## Legal/IP

Do not use official Habbo branding, copied official assets, or misleading trade dress unless you have permission. Use your own branding and assets.
