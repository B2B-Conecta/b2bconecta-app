#!/usr/bin/env bash
# Activa .env para local, staging o production (copia desde plantillas del repo).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  echo "Usage: bash scripts/use_env.sh <local|staging|mobile-staging|mobile-production|production>"
  echo ""
  echo "  local              → Supabase Docker (supabase start; keys en supabase status)"
  echo "  staging            → B2B Conecta DEV kdrccmqcrruixuworlmz (data de trabajo)"
  echo "  mobile-staging     → mismo API DEV + deep link auth para APK/iOS QA"
  echo "  mobile-production  → B2B Conecta MAIN fzugzjcwdzcwfxgviltw + deep link"
  echo "  production         → B2B Conecta MAIN (plantilla limpia + seed)"
  echo ""
  echo "Optional overrides (gitignored): config/env/<env>.env.local"
  exit 1
}

merge_env_local() {
  local env_name="$1"
  local local_file="$ROOT_DIR/config/env/${env_name}.env.local"
  [[ -f "$local_file" ]] || return 0
  echo "Merging secrets from config/env/${env_name}.env.local"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      continue
    fi
    local key="${line%%=*}"
    local val="${line#*=}"
    if sed --version >/dev/null 2>&1; then
      sed -i "s|^${key}=.*|${key}=${val}|" "$TARGET"
    else
      sed -i '' "s|^${key}=.*|${key}=${val}|" "$TARGET"
    fi
  done <"$local_file"
}

ENV_NAME="${1:-}"
[[ -n "$ENV_NAME" ]] || usage

if [[ "$ENV_NAME" == "mobile" ]]; then
  ENV_NAME="mobile-staging"
fi

TEMPLATE="$ROOT_DIR/config/env/$ENV_NAME.env"
TARGET="$ROOT_DIR/.env"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Missing template: $TEMPLATE"
  exit 1
fi

if [[ "$ENV_NAME" == "local" ]]; then
  PUBLISHABLE="$(supabase status -o json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('PUBLISHABLE_KEY',''))" 2>/dev/null || true)"
  if [[ -z "$PUBLISHABLE" ]]; then
    PUBLISHABLE="$(supabase status 2>/dev/null | awk '/Publishable/{print $3}' || true)"
  fi
  cp "$TEMPLATE" "$TARGET"
  merge_env_local "local"
  if [[ -n "$PUBLISHABLE" ]]; then
    if sed --version >/dev/null 2>&1; then
      sed -i "s|^NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=.*|NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$PUBLISHABLE|" "$TARGET"
    else
      sed -i '' "s|^NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=.*|NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$PUBLISHABLE|" "$TARGET"
    fi
    echo "OK: .env → local (publishable key from supabase status)"
  else
    echo "OK: .env → local (run supabase start; or set config/env/local.env.local)"
  fi
else
  cp "$TEMPLATE" "$TARGET"
  merge_env_local "$ENV_NAME"
  echo "OK: .env → $ENV_NAME"
  if grep -q 'YOUR_.*_PUBLISHABLE_KEY\|REPLACE_ME' "$TARGET" 2>/dev/null; then
    echo "WARN: publishable key is still a placeholder."
    echo "      Create config/env/${ENV_NAME}.env.local with real keys from Supabase Dashboard."
  fi
fi

echo "Restart flutter run after switching env (hot reload does not reload .env)."
