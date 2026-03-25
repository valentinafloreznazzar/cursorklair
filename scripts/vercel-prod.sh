#!/usr/bin/env bash
# Deploy no interactivo. La URL de producción aparece al final (Production: https://….vercel.app).
#
# 1) Token: https://vercel.com/account/tokens
# 2) export VERCEL_TOKEN="…"
# 3) export GEMINI_API_KEY="…"   (obligatorio para que /api/gemini funcione)
# 4) npm run deploy
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${VERCEL_TOKEN:-}" ]]; then
  echo "Falta VERCEL_TOKEN → https://vercel.com/account/tokens"
  echo "  export VERCEL_TOKEN='…' && export GEMINI_API_KEY='…' && npm run deploy"
  exit 1
fi

ENV_ARGS=()
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  ENV_ARGS+=(-e "GEMINI_API_KEY=$GEMINI_API_KEY")
else
  echo "Aviso: GEMINI_API_KEY vacío — el chat web fallará hasta que la añadas en Vercel → Settings → Environment Variables."
fi

exec npx --yes vercel@latest deploy --prod --yes \
  --token "$VERCEL_TOKEN" \
  "${ENV_ARGS[@]}" \
  .
