#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-local}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
case "$MODE" in
  local)
    docker compose --env-file .env -f compose.local.yml exec backup backup-now
    ;;
  server|prod|production)
    docker compose --env-file .env -f compose.server.yml exec backup backup-now
    ;;
  *)
    echo "Usage: $0 [local|server]"
    exit 2
    ;;
esac
