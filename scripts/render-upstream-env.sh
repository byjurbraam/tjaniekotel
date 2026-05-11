#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
    echo "Missing .env. Copy .env.example to .env first."
    exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${UPSTREAM_DIR:=vendor/nitro-docker}"
: "${DOMAIN_ASSETS:?Set DOMAIN_ASSETS in .env}"
: "${DOMAIN_GAME:?Set DOMAIN_GAME in .env}"
: "${DOMAIN_CMS:?Set DOMAIN_CMS in .env}"
: "${DOMAIN_WS:?Set DOMAIN_WS in .env}"
: "${MYSQL_ROOT_PASSWORD:?Set MYSQL_ROOT_PASSWORD in .env}"
: "${MYSQL_USER:?Set MYSQL_USER in .env}"
: "${MYSQL_PASSWORD:?Set MYSQL_PASSWORD in .env}"
: "${MYSQL_DATABASE:?Set MYSQL_DATABASE in .env}"

mkdir -p "$UPSTREAM_DIR"

cat > "$UPSTREAM_DIR/.env" <<EOF_ENV
TRAEFIK_VIRTUAL_HOST_ASSETS=${DOMAIN_ASSETS}
TRAEFIK_VIRTUAL_HOST_NITRO=${DOMAIN_GAME}
TRAEFIK_VIRTUAL_HOST_CMS=${DOMAIN_CMS}
TRAEFIK_VIRTUAL_HOST_WS=${DOMAIN_WS}

MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}

DB_HOSTNAME=db
DB_PORT=3306
DB_DATABASE=${MYSQL_DATABASE}
DB_USERNAME=${MYSQL_USER}
DB_PASSWORD=${MYSQL_PASSWORD}
DB_PARAMS=

EMU_HOST=${EMU_HOST:-0.0.0.0}
EMU_PORT=${EMU_PORT:-3000}
RCON_HOST=${RCON_HOST:-127.0.0.1}
RCON_PORT=${RCON_PORT:-3001}
RCON_ALLOWED=${RCON_ALLOWED:-127.0.0.1}
RT_THREADS=${RT_THREADS:-12}

API_HOST=${API_HOST:-imager}
API_PORT=${API_PORT:-3000}
AVATAR_SAVE_PATH=${AVATAR_SAVE_PATH:-/app/assets/usercontent/avatar/}

# Internal URLs used by services inside the Docker network.
AVATAR_ACTIONS_URL=http://assets/assets/gamedata/HabboAvatarActions.json
AVATAR_FIGUREDATA_URL=http://assets/assets/gamedata/FigureData.json
AVATAR_FIGUREMAP_URL=http://assets/assets/gamedata/FigureMap.json
AVATAR_EFFECTMAP_URL=http://assets/assets/gamedata/EffectMap.json
AVATAR_ASSET_URL=http://assets/assets/bundled/figure/%libname%.nitro
AVATAR_ASSET_EFFECT_URL=http://assets/assets/bundled/effect/%libname%.nitro

IMAGEPROXY_USER_AGENT=${IMAGEPROXY_USER_AGENT:-Mozilla/5.0 (compatible; RetroHotelDockerStarter/1.0)}
IMAGEPROXY_ADDR=${IMAGEPROXY_ADDR:-0.0.0.0:8080}
IMAGEPROXY_CACHE=${IMAGEPROXY_CACHE:-/tmp/imageproxy}
EOF_ENV

CMS_ENV="$UPSTREAM_DIR/.cms.env"
if [[ ! -f "$CMS_ENV" ]]; then
    if [[ -f "$UPSTREAM_DIR/example-.cms.env" ]]; then
        cp "$UPSTREAM_DIR/example-.cms.env" "$CMS_ENV"
    else
        touch "$CMS_ENV"
    fi
fi

python3 - <<'PY'
from pathlib import Path
import os

path = Path(os.environ.get("UPSTREAM_DIR", "vendor/nitro-docker")) / ".cms.env"
updates = {
    "APP_NAME": os.environ.get("PROJECT_TITLE", "Retro Hotel"),
    "APP_ENV": "production",
    "APP_DEBUG": "false",
    "APP_URL": f"{os.environ.get('PUBLIC_SCHEME', 'https')}://{os.environ['DOMAIN_CMS']}",
    "DB_CONNECTION": "mysql",
    "DB_HOST": "db",
    "DB_PORT": "3306",
    "DB_DATABASE": os.environ["MYSQL_DATABASE"],
    "DB_USERNAME": os.environ["MYSQL_USER"],
    "DB_PASSWORD": os.environ["MYSQL_PASSWORD"],
    "RCON_IP": "arcturus",
    "RCON_PORT": os.environ.get("RCON_PORT", "3001"),
}

existing = []
seen = set()
if path.exists():
    existing = path.read_text(encoding="utf-8", errors="ignore").splitlines()

out = []
for line in existing:
    if not line.strip() or line.lstrip().startswith("#") or "=" not in line:
        out.append(line)
        continue
    key = line.split("=", 1)[0].strip()
    if key in updates:
        value = updates[key]
        if " " in value and not (value.startswith('"') or value.startswith("'")):
            value = '"' + value.replace('"', '\\"') + '"'
        out.append(f"{key}={value}")
        seen.add(key)
    else:
        out.append(line)

for key, value in updates.items():
    if key not in seen:
        if " " in value and not (value.startswith('"') or value.startswith("'")):
            value = '"' + value.replace('"', '\\"') + '"'
        out.append(f"{key}={value}")

path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY

echo "Rendered $UPSTREAM_DIR/.env and $UPSTREAM_DIR/.cms.env"
