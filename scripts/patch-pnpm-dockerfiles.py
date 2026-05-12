#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / "vendor" / "nitro-docker"

PNPM_SETUP = "RUN corepack enable && corepack prepare pnpm@10 --activate\n"

PATCHES = {
    UPSTREAM / "nitro" / "Dockerfile": [
        (
            "RUN npm install --force\nRUN npm install --save-dev nx\nRUN npx nx build frontend\n",
            (
                PNPM_SETUP
                + "RUN rm -rf node_modules\n"
                + "RUN pnpm install --no-frozen-lockfile --config.node-linker=hoisted\n"
                + "RUN pnpm add --save-dev nx\n"
                + "RUN pnpm exec nx build frontend\n"
            ),
        ),
    ],
    UPSTREAM / "assets" / "Dockerfile": [
        (
            "RUN yarn install\nRUN yarn build\n",
            (
                PNPM_SETUP
                + "RUN rm -rf node_modules\n"
                + "RUN pnpm install --no-frozen-lockfile --config.node-linker=hoisted\n"
                + "RUN pnpm run build\n"
            ),
        ),
    ],
    UPSTREAM / "atomcms" / "Dockerfile": [
        (
            "# Install dependencies and build assets\nRUN yarn install --frozen-lockfile\nRUN yarn run build:atom\nRUN yarn run build:dusk\n",
            (
                "# Install dependencies and build assets\n"
                + PNPM_SETUP
                + "RUN rm -rf node_modules\n"
                + "RUN pnpm install --no-frozen-lockfile --config.node-linker=hoisted\n"
                + "RUN pnpm run build:atom\n"
                + "RUN pnpm run build:dusk\n"
            ),
        ),
    ],
}


def main() -> None:
    changed = []
    imager = UPSTREAM / "imager" / "Dockerfile"
    if imager.exists():
        contents = imager.read_text(encoding="utf-8")
        original = contents
        contents = contents.replace(
            (
                PNPM_SETUP
                + "RUN rm -rf node_modules\n"
                + "RUN pnpm install --no-frozen-lockfile --config.node-linker=hoisted\n"
                + "RUN pnpm run build\n"
            ),
            "RUN yarn install\nRUN yarn build\n",
        )
        contents = contents.replace(
            (
                "RUN corepack enable && corepack prepare pnpm@latest --activate\n"
                + "RUN rm -rf node_modules\n"
                + "RUN pnpm install --no-frozen-lockfile --shamefully-hoist\n"
                + "RUN pnpm run build\n"
            ),
            "RUN yarn install\nRUN yarn build\n",
        )
        if contents != original:
            imager.write_text(contents, encoding="utf-8")
            changed.append(imager.relative_to(ROOT).as_posix())

    for path, replacements in PATCHES.items():
        if not path.exists():
            raise SystemExit(f"Missing {path}")

        contents = path.read_text(encoding="utf-8")
        original = contents
        contents = contents.replace(
            "RUN corepack enable && corepack prepare pnpm@latest --activate\n",
            PNPM_SETUP,
        )
        contents = contents.replace(
            "RUN pnpm install --no-frozen-lockfile --shamefully-hoist\n",
            "RUN pnpm install --no-frozen-lockfile --config.node-linker=hoisted\n",
        )
        for needle, replacement in replacements:
            if replacement in contents:
                continue
            if needle not in contents:
                raise SystemExit(f"Could not find pnpm patch point in {path}")
            contents = contents.replace(needle, replacement)

        if contents != original:
            path.write_text(contents, encoding="utf-8")
            changed.append(path.relative_to(ROOT).as_posix())

    if changed:
        print("Patched Dockerfiles to use pnpm:")
        for path in changed:
            print(f"  - {path}")
    else:
        print("Dockerfiles already patched to use pnpm.")


if __name__ == "__main__":
    main()
