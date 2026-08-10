#!/usr/bin/env bash
# Reinicia Supabase local con SMTP Gmail (config/smtp.env).
# Requisito: [auth.email.smtp] enabled en supabase/config.toml
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SMTP_ENV="$ROOT_DIR/config/smtp.env"
if [[ ! -f "$SMTP_ENV" ]]; then
  echo "Falta config/smtp.env — copie desde config/smtp.env.example y pegue SMTP_PASS."
  exit 1
fi

# shellcheck disable=SC1090
set -a && source "$SMTP_ENV" && set +a

if [[ -z "${SMTP_PASS:-}" || -z "${SMTP_USER:-}" || -z "${SMTP_HOST:-}" ]]; then
  echo "config/smtp.env incompleto (SMTP_HOST / SMTP_USER / SMTP_PASS)."
  exit 1
fi

if ! grep -qE '^\[auth\.email\.smtp\]' "$ROOT_DIR/supabase/config.toml"; then
  echo "Aviso: [auth.email.smtp] no está activo en supabase/config.toml"
  exit 1
fi

echo "Reiniciando Supabase local con SMTP → ${SMTP_USER} @ ${SMTP_HOST}..."
supabase stop
supabase start
echo ""
echo "OK. Confirmación / recovery salen por Gmail (${SMTP_ADMIN_EMAIL:-$SMTP_USER})."
echo "App: bash scripts/use_env.sh local && bash scripts/run_web_local.sh"
echo "Redirect local: SUPABASE_AUTH_REDIRECT_URL=http://localhost:3000"
