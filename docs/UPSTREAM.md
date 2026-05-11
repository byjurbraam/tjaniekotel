# Upstream strategy

This starter does not vendor the full upstream codebase in the ZIP. Instead, it clones the upstream Docker stack during bootstrap:

```text
https://github.com/Gurkengewuerz/nitro-docker.git
```

Reasons:

1. The ZIP stays small.
2. You get the latest upstream code when bootstrapping.
3. Upstream licenses remain separate and clear.
4. You avoid accidentally committing assets, database data, or secrets.

Change upstream source in `.env`:

```text
UPSTREAM_REPO=https://github.com/Gurkengewuerz/nitro-docker.git
UPSTREAM_REF=main
```

After changing it, run:

```bash
./scripts/bootstrap-upstream.sh
```
