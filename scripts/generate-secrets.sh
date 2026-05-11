#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
    cp .env.example .env
fi

python3 - <<'PY'
from pathlib import Path
import secrets
import string

path = Path('.env')
text = path.read_text(encoding='utf-8')
chars = string.ascii_letters + string.digits

def token(n=40):
    return ''.join(secrets.choice(chars) for _ in range(n))

replacements = {
    'MYSQL_ROOT_PASSWORD': token(48),
    'MYSQL_PASSWORD': token(48),
}

lines = []
seen = set()
for line in text.splitlines():
    if '=' not in line or line.lstrip().startswith('#'):
        lines.append(line)
        continue
    key = line.split('=', 1)[0].strip()
    if key in replacements:
        lines.append(f'{key}={replacements[key]}')
        seen.add(key)
    else:
        lines.append(line)
for key, value in replacements.items():
    if key not in seen:
        lines.append(f'{key}={value}')

path.write_text('\n'.join(lines).rstrip() + '\n', encoding='utf-8')
print('Updated .env with generated database secrets.')
PY
