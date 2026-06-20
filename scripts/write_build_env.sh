#!/usr/bin/env bash
# Genera .env en CI (Vercel) a partir de variables de entorno del dashboard.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT_DIR/.env"

url="${NEXT_PUBLIC_SUPABASE_URL:-}"
key="${NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:-${NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY:-}}"
redirect="${SUPABASE_AUTH_REDIRECT_URL:-}"

if [[ -z "$redirect" && -n "${VERCEL_URL:-}" ]]; then
  redirect="https://${VERCEL_URL}"
fi

if [[ -z "$url" || -z "$key" ]]; then
  echo "ERROR: Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in Vercel → Environment Variables."
  exit 1
fi

if [[ -z "$redirect" ]]; then
  echo "WARN: SUPABASE_AUTH_REDIRECT_URL not set; defaulting to http://localhost:3000"
  redirect="http://localhost:3000"
fi

if [[ "$redirect" == *"motolink-pro-app.vercel.app"* ]]; then
  echo "WARN: SUPABASE_AUTH_REDIRECT_URL uses motolink-pro-app.vercel.app (404)."
  echo "      Use https://motolink-app.vercel.app — see config/vercel-env.staging.example"
fi

cat >"$TARGET" <<EOF
# Generated at build time ($(date -u +%Y-%m-%dT%H:%MZ))
NEXT_PUBLIC_SUPABASE_URL=$url
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$key
SUPABASE_AUTH_REDIRECT_URL=$redirect
EOF

echo "Wrote $TARGET (redirect=$redirect)"
