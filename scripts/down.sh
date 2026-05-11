#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-local}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
case "$MODE" in
  local)
    docker compose --env-file .env -f compose.local.yml down
    ;;
  caddy|prod|production)
    docker compose --env-file .env -f compose.prod.caddy.yml down
    ;;
  *)
    echo "Usage: $0 [local|caddy]"
    exit 2
    ;;
esac
