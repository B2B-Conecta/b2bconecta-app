#!/usr/bin/env bash
# Configura secrets FCM para send-push-notification en Supabase remoto.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET="${1:-staging}"
PUSH_ENV="$ROOT_DIR/config/push.env"

if [[ ! -f "$PUSH_ENV" ]]; then
  echo "Copie config/push.env.example → config/push.env y pegue FCM_SERVER_KEY."
  exit 1
fi

# shellcheck disable=SC1090
set -a && source "$PUSH_ENV" && set +a

PROJECT_REF="${SUPABASE_PROJECT_REF:-}"
if [[ -z "$PROJECT_REF" ]]; then
  if [[ "$TARGET" == "staging" ]]; then
    PROJECT_REF="${STAGING_PROJECT_REF:-lwrqjpqyitnveizshawc}"
  else
    echo "Defina SUPABASE_PROJECT_REF o use target staging."
    exit 1
  fi
fi

FCM_KEY="${MOTOLINK_FCM_SERVER_KEY:-${FCM_SERVER_KEY:-}}"
WEBHOOK="${MOTOLINK_PUSH_WEBHOOK_SECRET:-${PUSH_WEBHOOK_SECRET:-}}"

if [[ -z "$FCM_KEY" ]]; then
  echo "FCM_SERVER_KEY requerido en config/push.env"
  exit 1
fi

if [[ -z "$WEBHOOK" ]]; then
  WEBHOOK="$(openssl rand -hex 24)"
  echo "Generado PUSH_WEBHOOK_SECRET=$WEBHOOK"
fi

echo "Configurando secrets en proyecto $PROJECT_REF…"
supabase secrets set \
  --project-ref "$PROJECT_REF" \
  FCM_SERVER_KEY="$FCM_KEY" \
  PUSH_WEBHOOK_SECRET="$WEBHOOK"

echo "Desplegando Edge Function send-push-notification…"
supabase functions deploy send-push-notification --project-ref "$PROJECT_REF"

echo "Listo. Configure Vault push_supabase_url, push_service_role_key, push_webhook_secret para despacho desde BD."
