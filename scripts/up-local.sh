#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
"$ROOT_DIR/scripts/bootstrap-upstream.sh"
docker compose --env-file .env -f compose.local.yml up -d --build "$@"
