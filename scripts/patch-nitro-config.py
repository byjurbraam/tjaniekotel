#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"


def parse_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
            value = value[1:-1]
        values[key.strip()] = value
    return values


def main() -> int:
    if not ENV_PATH.exists():
        raise SystemExit("Missing .env. Copy .env.example to .env first.")
    env = parse_env(ENV_PATH)
    upstream_dir = ROOT / env.get("UPSTREAM_DIR", "vendor/nitro-docker")

    public = env.get("PUBLIC_SCHEME", "https")
    ws_scheme = env.get("WEBSOCKET_SCHEME", "wss")
    game_url = f"{public}://{env['DOMAIN_GAME']}"
    assets_url = f"{public}://{env['DOMAIN_ASSETS']}"
    cms_url = f"{public}://{env['DOMAIN_CMS']}"
    ws_url = f"{ws_scheme}://{env['DOMAIN_WS']}"

    replacements = {
        "http://127.0.0.1:3000": game_url,
        "http://localhost:3000": game_url,
        "http://127.0.0.1:3080": game_url,
        "http://localhost:3080": game_url,
        "http://127.0.0.1:8080": assets_url,
        "http://localhost:8080": assets_url,
        "http://127.0.0.1:8081": cms_url,
        "http://localhost:8081": cms_url,
        "ws://127.0.0.1:2096": ws_url,
        "ws://localhost:2096": ws_url,
        "ws://0.0.0.0:2096": ws_url,
        "wss://127.0.0.1:2096": ws_url,
        "wss://localhost:2096": ws_url,
    }

    candidates = [
        upstream_dir / "nitro" / "renderer-config.json",
        upstream_dir / "nitro" / "ui-config.json",
        upstream_dir / "nitro" / "client-config.json",
    ]

    patched = []
    for path in candidates:
        if not path.exists():
            continue
        original = path.read_text(encoding="utf-8", errors="ignore")
        updated = original
        for old, new in replacements.items():
            updated = updated.replace(old, new)
        if updated != original:
            backup = path.with_suffix(path.suffix + ".bak")
            if not backup.exists():
                backup.write_text(original, encoding="utf-8")
            path.write_text(updated, encoding="utf-8")
            patched.append(path.relative_to(ROOT))

    if patched:
        print("Patched Nitro config files:")
        for item in patched:
            print(f"  - {item}")
    else:
        print("No Nitro config URL replacements were needed or files were not present yet.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
