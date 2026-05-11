#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCKERFILE = ROOT / "vendor" / "nitro-docker" / "atomcms" / "Dockerfile"

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


def main() -> None:
    if not DOCKERFILE.exists():
        raise SystemExit(f"Missing {DOCKERFILE}")

    contents = DOCKERFILE.read_text(encoding="utf-8")
    if MARKER in contents:
        print("AtomCMS Dockerfile compatibility redirects already patched.")
        return

    if NEEDLE not in contents:
        raise SystemExit(f"Could not find insertion point in {DOCKERFILE}")

    DOCKERFILE.write_text(contents.replace(NEEDLE, NEEDLE + PATCH), encoding="utf-8")
    print("Patched AtomCMS Dockerfile compatibility redirects.")


if __name__ == "__main__":
    main()
