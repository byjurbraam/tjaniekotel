#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-local}"
shift || true
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
case "$MODE" in
  local)
    docker compose --env-file .env -f compose.local.yml logs -f "$@"
    ;;
  server|prod|production)
    docker compose --env-file .env -f compose.server.yml logs -f "$@"
    ;;
  *)
    echo "Usage: $0 [local|server] [service...]"
    exit 2
    ;;
esac
