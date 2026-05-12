# Codex Project Instructions

## Repository Rules

- Use modern JavaScript and current platform APIs when editing JavaScript code.
- Before doing broad code-quality cleanup, suggest it first and wait for approval.
- Prefer current official documentation and established best practices for Docker, Docker Compose, Nginx, JavaScript, and framework-specific work.
- Do not delete, rewrite, or change unrelated functions. Keep edits scoped to the requested behavior unless a small compatibility change is required for the same result.
- Do not add migration, cleanup, reset, or backfill passes for persisted data unless the user explicitly requests it.

## Docker And Deployment

- The host should only need Docker and Docker Compose. Application packages, build tools, and runtime dependencies belong inside Docker images.
- Keep local and server behavior the same. Use the same images and Compose topology wherever practical; differences should be environment values, not separate manual config.
- Prefer Compose environment interpolation and env files for deployment-specific values. Avoid hard-coded public IPs, domains, websocket hosts, or asset hosts in image contents when they can be injected at runtime.
- Route public HTTP traffic through one reverse proxy service. Websocket proxying must preserve `Upgrade` and `Connection` headers.
- Never run commands that reset or remove database state without explicit approval. This includes `docker compose down -v`, `docker volume rm`, deleting MySQL data folders, replacing SQL dumps over live data, or recreating database volumes.
- Never delete database content to fix application behavior. Preserve data and use explicit, reviewable migrations or targeted idempotent `UPDATE` statements when persisted settings must change.
- Recreate app containers only when needed and avoid recreating the database container unless required. A normal `up -d --no-deps --force-recreate <service>` is preferred for targeted app refreshes.
- Production deploys must build Docker images locally or in CI, push them to the registry, then update the VPS with `docker compose pull` and `docker compose up -d`. Do not build application images on the VPS during normal deploys.
- If registry push/pull fails, fix registry authentication or permissions first. Do not work around a registry problem by doing a server-side production build unless the user explicitly approves an emergency exception.
- `compose.registry-build.yml` is only for build/push on the build machine. `compose.server.yml` is only for pull/run on the VPS. Do not run both as production builds; the same tagged images should be reused by changing only Compose environment values.
- The VPS should be a Git checkout for production runtime files so `compose.server.yml` and deploy docs/rules can be updated with `git pull`. It still must not build application images on the VPS.
- When deploying to the VPS, first run `git pull --ff-only` for production runtime files, then sync ignored env files if needed, then run `docker compose --env-file .env -f compose.server.yml pull` and `docker compose --env-file .env -f compose.server.yml up -d --remove-orphans`.

## Hotel Verification

- Before saying the hotel works, check the actual hotel page in a browser flow, not only `curl`.
- A valid check must confirm Nitro loads, the expected websocket URL opens, and the console shows `Connection Initialized` and `Connection Authenticated` without `Connection Closed`, websocket 403, or visible connection error.
- Check both local and AWS/server when a change affects deployment, routing, images, assets, CMS config, Nitro config, or Arcturus websocket behavior.

## Secrets And Access

- Do not print secrets in responses or logs. Keep access keys, passwords, PEM files, and deployment env files out of commits.
- Use the existing deployment env/key files only for operational commands.

## Tooling Habits

- Use `rg` or `rg --files` first for searching.
- Use `apply_patch` for repository file edits.
- Do not revert user changes or unrelated work.
