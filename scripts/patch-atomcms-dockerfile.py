#!/usr/bin/env python3
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[1]
DOCKERFILE = ROOT / "vendor" / "nitro-docker" / "atomcms" / "Dockerfile"
NITRO_DOCKERFILE = ROOT / "vendor" / "nitro-docker" / "nitro" / "Dockerfile"
BRANDING_SOURCE = ROOT / "branding"
BRANDING_DESTINATION = ROOT / "vendor" / "nitro-docker" / "atomcms" / "branding"
NITRO_BRANDING_DESTINATION = ROOT / "vendor" / "nitro-docker" / "nitro"
ASSETS_BRANDING_DESTINATION = ROOT / "vendor" / "nitro-docker" / "assets"
PATCH_SOURCE = ROOT / "scripts" / "disable-paid-shop.php"
PATCH_DESTINATION = ROOT / "vendor" / "nitro-docker" / "atomcms" / "docker-patches"
BRANDING_FILES = (
    "tjaniekotel-logo.webp",
    "tjaniekotel-logo.png",
    "favicon.ico",
)

MARKER = "Route::redirect('/game/nitr', '/game/nitro');"
NEEDLE = "RUN git checkout $COMMIT\n"
PATCH = r'''

# Local Docker compatibility redirects. In this setup Nitro is served by the
# separate nitro container, while AtomCMS may still contain older client paths.
RUN <<'EOF'
php <<'PHP'
<?php
$path = 'routes/web.php';
$contents = file_get_contents($path);

$redirects = <<<'ROUTES'

// Local Docker compatibility redirects.
Route::redirect('/game/nitr', '/game/nitro');
Route::get('/client/nitro/nitro-react/dist/index.html', static function () {
    $query = request()->getQueryString();
    $url = rtrim(setting('nitro_path'), '/') . '/index.html';

    return redirect()->away($query ? "{$url}?{$query}" : $url);
});
ROUTES;

if (! str_contains($contents, "Route::redirect('/game/nitr', '/game/nitro');")) {
    $contents = str_replace('// Language route', "{$redirects}\n\n// Language route", $contents);
    file_put_contents($path, $contents);
}
PHP
EOF
'''.lstrip("\n")

BRANDING_MARKER = "Tjaniekotel branding assets."
BRANDING_NEEDLE = "COPY --from=npm-builder --chown=www-data:www-data /app /var/www/html\n"
BRANDING_PATCH = r'''

# Tjaniekotel branding assets.
COPY --chown=www-data:www-data ./branding/tjaniekotel-logo.webp /var/www/html/public/assets/images/tjaniekotel-logo.webp
COPY --chown=www-data:www-data ./branding/tjaniekotel-logo.png /var/www/html/public/assets/images/tjaniekotel-logo.png
COPY --chown=www-data:www-data ./branding/favicon.ico /var/www/html/public/favicon.ico
'''.lstrip("\n")

COMMERCE_MARKER = "Real-money shop removal."
COMMERCE_NEEDLE = "RUN git checkout $COMMIT\n"
COMMERCE_PATCH = r'''

# Real-money shop removal.
COPY ./docker-patches/disable-paid-shop.php /tmp/disable-paid-shop.php
RUN php /tmp/disable-paid-shop.php /app
'''.lstrip("\n")

NITRO_FAVICON_MARKER = "COPY favicon.ico /usr/share/nginx/html/favicon.ico"
NITRO_FAVICON_NEEDLE = "COPY --from=builder /build/dist/apps/frontend/ /usr/share/nginx/html/\n"
NITRO_FAVICON_PATCH = "COPY favicon.ico /usr/share/nginx/html/favicon.ico\n"


def sync_branding_files() -> None:
    missing = [name for name in BRANDING_FILES if not (BRANDING_SOURCE / name).exists()]
    if missing:
        raise SystemExit(f"Missing branding files: {', '.join(missing)}")

    BRANDING_DESTINATION.mkdir(parents=True, exist_ok=True)
    for name in BRANDING_FILES:
        shutil.copy2(BRANDING_SOURCE / name, BRANDING_DESTINATION / name)

    shutil.copy2(BRANDING_SOURCE / "favicon.ico", NITRO_BRANDING_DESTINATION / "favicon.ico")
    shutil.copy2(BRANDING_SOURCE / "favicon.ico", ASSETS_BRANDING_DESTINATION / "favicon.ico")


def sync_patch_files() -> None:
    if not PATCH_SOURCE.exists():
        raise SystemExit(f"Missing commerce patch script: {PATCH_SOURCE}")

    PATCH_DESTINATION.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PATCH_SOURCE, PATCH_DESTINATION / PATCH_SOURCE.name)


def patch_nitro_dockerfile() -> bool:
    if not NITRO_DOCKERFILE.exists():
        return False

    contents = NITRO_DOCKERFILE.read_text(encoding="utf-8")
    if NITRO_FAVICON_MARKER in contents:
        return False

    if NITRO_FAVICON_NEEDLE not in contents:
        raise SystemExit(f"Could not find Nitro favicon insertion point in {NITRO_DOCKERFILE}")

    NITRO_DOCKERFILE.write_text(
        contents.replace(NITRO_FAVICON_NEEDLE, NITRO_FAVICON_NEEDLE + NITRO_FAVICON_PATCH),
        encoding="utf-8",
    )
    return True


def main() -> None:
    if not DOCKERFILE.exists():
        raise SystemExit(f"Missing {DOCKERFILE}")

    sync_branding_files()
    sync_patch_files()
    contents = DOCKERFILE.read_text(encoding="utf-8")
    changed = False

    if MARKER not in contents:
        if NEEDLE not in contents:
            raise SystemExit(f"Could not find redirects insertion point in {DOCKERFILE}")

        contents = contents.replace(NEEDLE, NEEDLE + PATCH)
        changed = True

    if BRANDING_MARKER not in contents:
        if BRANDING_NEEDLE not in contents:
            raise SystemExit(f"Could not find branding insertion point in {DOCKERFILE}")

        contents = contents.replace(BRANDING_NEEDLE, BRANDING_NEEDLE + BRANDING_PATCH)
        changed = True

    if COMMERCE_MARKER not in contents:
        if COMMERCE_NEEDLE not in contents:
            raise SystemExit(f"Could not find commerce patch insertion point in {DOCKERFILE}")

        contents = contents.replace(COMMERCE_NEEDLE, COMMERCE_NEEDLE + COMMERCE_PATCH)
        changed = True

    if changed:
        DOCKERFILE.write_text(contents, encoding="utf-8")
        print("Patched AtomCMS Dockerfile.")
    else:
        print("AtomCMS Dockerfile already patched.")

    print("Synced AtomCMS branding assets.")
    print("Synced AtomCMS commerce removal patch.")

    if patch_nitro_dockerfile():
        print("Patched Nitro Dockerfile favicon.")

    print("Synced Nitro and assets favicon.")


if __name__ == "__main__":
    main()
