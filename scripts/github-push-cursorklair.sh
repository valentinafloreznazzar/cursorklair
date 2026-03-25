#!/usr/bin/env bash
# One-shot: log into GitHub (browser), create valentinafloreznazzar/cursorklair if missing, push main.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

OWNER="valentinafloreznazzar"
REPO="cursorklair"
FULL="$OWNER/$REPO"
ORIGIN_URL="https://github.com/$FULL.git"

if ! command -v gh >/dev/null 2>&1; then
  echo "Install GitHub CLI: brew install gh"
  exit 1
fi

git remote set-url origin "$ORIGIN_URL"
echo "origin -> $ORIGIN_URL"

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "Opening GitHub login (browser). Follow the prompts."
  gh auth login -h github.com -p https -w -s "repo"
fi

gh auth setup-git

if gh repo view "$FULL" >/dev/null 2>&1; then
  echo "Remote repo exists. Pushing main..."
else
  echo "Creating empty GitHub repo $FULL..."
  gh repo create "$FULL" --public --description "Klair · Cursor hackathon (IE University)"
fi
git push -u origin main

echo "Done. https://github.com/$FULL"
