#!/usr/bin/env bash
# Activa .env para local, staging o production (copia desde plantillas del repo).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  echo "Usage: bash scripts/use_env.sh <local|staging|production>"
  echo ""
  echo "  local       → Supabase Docker (supabase start; keys en supabase status)"
  echo "  staging     → lwrqjpqyitnveizshawc"
  echo "  production  → ufrphhiynowsychgxvkn"
  exit 1
}

ENV_NAME="${1:-}"
[[ -n "$ENV_NAME" ]] || usage

TEMPLATE="$ROOT_DIR/config/env/$ENV_NAME.env"
TARGET="$ROOT_DIR/.env"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Missing template: $TEMPLATE"
  exit 1
fi

if [[ "$ENV_NAME" == "local" ]]; then
  PUBLISHABLE="$(supabase status -o json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('PUBLISHABLE_KEY',''))" 2>/dev/null || true)"
  if [[ -z "$PUBLISHABLE" ]]; then
    PUBLISHABLE="$(supabase status 2>/dev/null | awk '/Publishable/{print $3}')"
  fi
  cp "$TEMPLATE" "$TARGET"
  if [[ -n "$PUBLISHABLE" ]]; then
    if sed --version >/dev/null 2>&1; then
      sed -i "s|^NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=.*|NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$PUBLISHABLE|" "$TARGET"
    else
      sed -i '' "s|^NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=.*|NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$PUBLISHABLE|" "$TARGET"
    fi
    echo "OK: .env → local (publishable key from supabase status)"
  else
    echo "OK: .env → local (run supabase start; update key via supabase status if login fails)"
  fi
else
  cp "$TEMPLATE" "$TARGET"
  echo "OK: .env → $ENV_NAME"
  echo "Edit .env if publishable key placeholder is not filled."
fi

echo "Restart flutter run after switching env (hot reload does not reload .env)."
