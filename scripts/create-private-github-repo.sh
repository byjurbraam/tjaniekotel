#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="${1:-retro-hotel-docker-starter}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI not found. Install it first: https://cli.github.com/"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Run: gh auth login"
    exit 1
fi

if [[ ! -d .git ]]; then
    git init
fi

git add .
if git diff --cached --quiet; then
    echo "No new files to commit."
else
    git commit -m "Initial retro hotel Docker starter"
fi

if git remote get-url origin >/dev/null 2>&1; then
    echo "Remote origin already exists: $(git remote get-url origin)"
else
    gh repo create "$REPO_NAME" --private --source=. --remote=origin --push
    exit 0
fi

git push -u origin HEAD
