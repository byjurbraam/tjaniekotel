# Push this scaffold to a private GitHub repository

## With GitHub CLI

```bash
gh auth login
./scripts/create-private-github-repo.sh my-private-retro-hotel
```

## Manual commands

```bash
git init
git add .
git commit -m "Initial retro hotel Docker starter"
gh repo create my-private-retro-hotel --private --source=. --remote=origin --push
```

## Important

The `.gitignore` excludes:

- `.env`
- `vendor/`
- generated SQL
- ZIP/archive files

That prevents you from committing secrets, cloned upstream source, database files, or assets by accident.
