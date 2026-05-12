#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

docker compose --env-file .env -f compose.server.yml pull
docker compose --env-file .env -f compose.server.yml up -d --remove-orphans "$@"
