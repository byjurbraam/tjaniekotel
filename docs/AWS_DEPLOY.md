# AWS VPS deploy notes

Use this when deploying or debugging the AWS server. The intended production flow is:

1. Build Docker images on a build machine.
2. Push those images to the registry.
3. SSH to the VPS and run `docker compose pull` + `docker compose up`.

That keeps Node, npm, pnpm, Composer, Gradle, app packages, Nitro config, and runtime assets out of the VPS host. The server only needs Docker, `.env`, `.cms.env`, the compose file, and persistent database/storage volumes for normal deploys.

References: Docker Compose tags images from `image:` during builds, can push them to a registry, and can later pull those images with `docker compose pull`.

- https://docs.docker.com/reference/cli/docker/compose/build/
- https://docs.docker.com/reference/cli/docker/compose/push/
- https://docs.docker.com/reference/cli/docker/compose/pull/

## Connection source of truth

Deployment connection details live in the ignored local file:

```txt
.env.deploy
```

Current values:

```txt
VPS_HOST=3.71.5.101
VPS_USER=ec2-user
VPS_SSH_KEY_PATH=C:\tjanoekhotel\.deploy_ssh_key.pem
VPS_PROJECT_DIR=/opt/tjanoekhotel
AWS_ACCESS_KEY_ID=AKIARXIT6B7LHPIR6YGD
SERVER_COMPOSE_FILE=compose.server.yml
GIT_BRANCH=main
```

Do not commit `.env.deploy` or any `.pem` key.

## First checks

Before changing the server, run:

```powershell
.\scripts\aws-deploy.ps1 status
```

Open an SSH shell:

```powershell
.\scripts\aws-deploy.ps1 ssh
```

If SSH key permissions fail, use the strict local key copy:

```txt
C:\tjanoekhotel\.deploy_ssh_key.pem
```

The original AWS key is:

```txt
C:\tjanoekhotel\amz_private_key.pem
```

## Server setup already done

The AWS host is Amazon Linux 2023. Docker and Docker Compose v2 were installed on the host so containers can run.

Git and Python were used for the old bootstrap flow. They are not needed for normal production deploys once `vendor/nitro-docker` config/assets exist on the server and the application images are in the registry.

Node packages are installed inside Dockerfiles only:

- `nitro`: pnpm 10
- `assets`: pnpm 10
- `atomcms`: pnpm 10
- `imager`: Yarn, because upstream `nitro-imager` fails TypeScript build under pnpm

## Registry production flow

Make sure `.env` has the registry values:

```txt
IMAGE_REPOSITORY=ghcr.io/byjurbraam/tjaniekotel
IMAGE_NAME_PREFIX=tjanoekhotel
IMAGE_TAG=latest
```

Log in to the registry from the build machine before pushing. For GHCR:

```powershell
docker login ghcr.io
```

Build and push the production images:

```powershell
.\scripts\aws-deploy.ps1 build-push
```

The registry build includes:

- `arcturus`: emulator plus `/app/assets`
- `nitro`: compiled Nitro client plus nginx and Nitro JSON config
- `assets`: nginx asset server plus bundled runtime assets
- `imager`: compiled Nitro imager plus `/app/assets`
- `cms`: compiled AtomCMS app

Sync compose/env files, pull the pushed images on the VPS, and restart:

```powershell
.\scripts\aws-deploy.ps1 up
.\scripts\aws-deploy.ps1 status
```

`up` uses:

```bash
git fetch --prune origin
git pull --ff-only origin main
```

when `VPS_PROJECT_DIR` is a Git checkout. If the server directory is not a Git checkout yet, the script falls back to syncing only the deploy files.

Then it runs:

```bash
sudo docker compose --env-file .env -f compose.server.yml pull
sudo docker compose --env-file .env -f compose.server.yml up -d --remove-orphans
```

It does not build on the VPS.

## First-time/bootstrap fallback

Only use this if the server is missing `vendor/nitro-docker` configs/assets:

```powershell
.\scripts\aws-deploy.ps1 bootstrap
```

Only use this if you deliberately want the old server-side build flow:

```powershell
.\scripts\aws-deploy.ps1 legacy-up
```

`legacy-up` is slower and builds on the VPS. It is a fallback, not the normal production deploy.

## Mijndomein DNS

At Mijndomein DNS, point the `.nl` domain to the AWS public IP:

```txt
@       A       3.71.5.101
www     A       3.71.5.101
game    A       3.71.5.101
assets  A       3.71.5.101
ws      A       3.71.5.101
```

If Mijndomein asks for TTL, use `3600` seconds.

With `compose.server.yml`, keep these AWS security group ports open:

```txt
22   SSH
80   HTTP
443  HTTPS
```

The public web routes are handled by Caddy:

```txt
tjaniekahotel.nl          CMS
game.tjaniekahotel.nl     Nitro client
assets.tjaniekahotel.nl   Assets
ws.tjaniekahotel.nl       WebSocket
```

## IAM For Opening Ports

To let the deploy IAM user open the temporary direct IP test ports, attach the policy in:

```txt
docs/aws-security-group-port-policy.json
```

It grants only the EC2 actions needed to describe security groups and add inbound rules. After attaching it, add `AWS_SECRET_ACCESS_KEY` to `.env.deploy`, then the ports can be opened from this project.
