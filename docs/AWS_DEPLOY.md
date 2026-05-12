# AWS VPS deploy notes

Use this when deploying or debugging the AWS server. The production flow is:

1. Build Docker images on a build machine.
2. Push those images to the registry.
3. SSH to the VPS and run `docker compose pull` + `docker compose up`.

That keeps Node, npm, pnpm, Composer, Gradle, app packages, Nitro config, and runtime assets out of the VPS host. The server only needs Docker, a Git checkout for production runtime files such as `compose.server.yml`, `.env`, `.cms.env`, optional init SQL files, and persistent database volumes for normal deploys.

Do not build application images on the VPS for normal deploys. If GHCR or another registry rejects a push/pull, fix registry authentication or permissions before deploying.

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
AWS_ACCESS_KEY_ID=your-access-key-id
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

If SSH key permissions fail, use the strict local key path configured in `.env.deploy`:

```txt
C:\tjanoekhotel\.deploy_ssh_key.pem
```

## Server setup already done

The AWS host is Amazon Linux 2023. Docker and Docker Compose v2 were installed on the host so containers can run.

Git is used only to pull production runtime files such as `compose.server.yml`. Python, Node, Composer, and app build tools are not needed for normal production deploys.

Because the repository is private, the VPS needs Git read access configured once, for example with a deploy key or another GitHub credential that can only read this repository.

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

`compose.local.yml` is used for local development and for building/pushing the tagged images from the local build machine or CI. The deploy script builds and pushes only the project image services: `arcturus`, `nitro`, `assets`, `imager`, `cms`, and `proxy`.

When only specific images changed, pass those service names so unchanged images keep their existing layers and are not rebuilt or pushed:

```powershell
.\scripts\aws-deploy.ps1 build-push -Services cms,proxy
```

The registry build includes:

- `arcturus`: emulator plus `/app/assets`
- `nitro`: compiled Nitro client plus nginx and Nitro JSON config
- `assets`: nginx asset server plus bundled runtime assets
- `imager`: compiled Nitro imager plus `/app/assets`
- `cms`: compiled AtomCMS app
- `proxy`: nginx reverse proxy with the project route template

Pull the latest production runtime files from Git, pull the pushed images on the VPS, and restart:

```powershell
.\scripts\aws-deploy.ps1 up
.\scripts\aws-deploy.ps1 status
```

For normal updates, prefer targeting only the services that changed. This pulls and recreates only those containers, leaving the database and unrelated containers untouched:

```powershell
.\scripts\aws-deploy.ps1 up -Services cms,proxy
.\scripts\aws-deploy.ps1 status
```

`up` first updates the Git checkout on the VPS:

```bash
git fetch --prune origin
git pull --ff-only origin main
```

Then it copies only ignored runtime files that are intentionally not committed:

```txt
.env
.cms.env
```

Then it runs on the VPS:

```bash
sudo docker compose --env-file .env -f compose.server.yml pull
sudo docker compose --env-file .env -f compose.server.yml up -d --remove-orphans
```

When `-Services` is used, the script runs targeted equivalents:

```bash
sudo docker compose --env-file .env -f compose.server.yml pull cms proxy
sudo docker compose --env-file .env -f compose.server.yml up -d --no-deps cms proxy
```

It does not build on the VPS.

## No Server Builds

There is no normal server-side build command. Build and push images from the build machine, then pull them on the VPS.

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

The public web routes are handled by the nginx `proxy` image:

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
