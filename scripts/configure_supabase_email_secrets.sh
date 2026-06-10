#!/usr/bin/env bash
# Configura secrets SMTP para send-account-email en Supabase remoto.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_NAME="${1:-staging}"
EMAIL_ENV="$ROOT_DIR/config/email.env"

case "$ENV_NAME" in
  staging) PROJECT_REF="lwrqjpqyitnveizshawc" ;;
  production) PROJECT_REF="ufrphhiynowsychgxvkn" ;;
  *)
    echo "Usage: bash scripts/configure_supabase_email_secrets.sh <staging|production>"
    exit 1
    ;;
esac

if [[ -f "$EMAIL_ENV" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$EMAIL_ENV" && set +a
fi

: "${MOTOLINK_SMTP_USER:=motolink.admin@gmail.com}"
: "${MOTOLINK_SMTP_FROM:=MotoLink <motolink.admin@gmail.com>}"
: "${MOTOLINK_SMTP_HOST:=smtp.gmail.com}"
: "${MOTOLINK_SMTP_PORT:=587}"

if [[ -z "${MOTOLINK_SMTP_PASS:-}" ]]; then
  echo "ERROR: MOTOLINK_SMTP_PASS vacío."
  echo "Copie config/email.env.example → config/email.env y pegue la contraseña de aplicación Gmail."
  exit 1
fi

echo "Configurando secrets SMTP en $ENV_NAME ($PROJECT_REF)…"
supabase secrets set \
  SMTP_USER="$MOTOLINK_SMTP_USER" \
  SMTP_FROM="$MOTOLINK_SMTP_FROM" \
  SMTP_HOST="$MOTOLINK_SMTP_HOST" \
  SMTP_PORT="$MOTOLINK_SMTP_PORT" \
  SMTP_PASS="$MOTOLINK_SMTP_PASS" \
  --project-ref "$PROJECT_REF"

echo "Desplegando Edge Function send-account-email…"
supabase functions deploy send-account-email --project-ref "$PROJECT_REF"

echo "OK. Pruebe enviar registro inicial o aprobar un aliado."
