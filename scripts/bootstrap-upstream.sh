#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
    cp .env.example .env
    echo "Created .env from .env.example. Edit .env, then run this script again."
    exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${UPSTREAM_REPO:=https://github.com/Gurkengewuerz/nitro-docker.git}"
: "${UPSTREAM_REF:=main}"
: "${UPSTREAM_DIR:=vendor/nitro-docker}"

mkdir -p vendor generated

if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
    git clone --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$UPSTREAM_DIR"
else
    git -C "$UPSTREAM_DIR" fetch --depth 1 origin "$UPSTREAM_REF"
    git -C "$UPSTREAM_DIR" checkout "$UPSTREAM_REF"
    git -C "$UPSTREAM_DIR" pull --ff-only origin "$UPSTREAM_REF"
fi

(
    cd "$UPSTREAM_DIR"
    find . -type f -name 'example-*' -exec bash -c 'cp -n "$0" "${0/example-/}"' {} \;
)

"$ROOT_DIR/scripts/render-upstream-env.sh"
"$ROOT_DIR/scripts/patch-nitro-config.py"
"$ROOT_DIR/scripts/render-sql.py"

cat <<'MSG'
Bootstrap complete.

Next steps:
  1. Review vendor/nitro-docker/README.md for the upstream database/assets setup.
  2. Import the base SQL and required SQL updates.
  3. Review generated/public-settings.sql and import it after the base database exists.
  4. Start with ./scripts/up-local.sh or ./scripts/up-caddy.sh.
MSG
