#!/usr/bin/env bash
# Configura FCM + Vault para despacho push desde notifications INSERT.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET="${1:-staging}"
PUSH_ENV="$ROOT_DIR/config/push.env"

if [[ ! -f "$PUSH_ENV" ]]; then
  echo "Copie config/push.env.example → config/push.env y complete las claves."
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

SUPABASE_URL="${SUPABASE_URL:-https://${PROJECT_REF}.supabase.co}"
FCM_KEY="${MOTOLINK_FCM_SERVER_KEY:-${FCM_SERVER_KEY:-}}"
FCM_SA_JSON="${FCM_SERVICE_ACCOUNT_JSON:-}"
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
WEBHOOK="${MOTOLINK_PUSH_WEBHOOK_SECRET:-${PUSH_WEBHOOK_SECRET:-}}"

if [[ -z "$FCM_KEY" && -z "$FCM_SA_JSON" ]]; then
  echo "Configure FCM_SERVER_KEY (legacy) o FCM_SERVICE_ACCOUNT_JSON (recomendado) en config/push.env"
  exit 1
fi

if [[ -z "$SERVICE_ROLE_KEY" ]]; then
  echo "SUPABASE_SERVICE_ROLE_KEY requerido en config/push.env (Dashboard → Settings → API)."
  exit 1
fi

if [[ -z "$WEBHOOK" ]]; then
  WEBHOOK="$(openssl rand -hex 24)"
  echo "Generado PUSH_WEBHOOK_SECRET=$WEBHOOK"
fi

escape_sql() {
  printf "%s" "$1" | sed "s/'/''/g"
}

SQL_URL="$(escape_sql "$SUPABASE_URL")"
SQL_KEY="$(escape_sql "$SERVICE_ROLE_KEY")"
SQL_WH="$(escape_sql "$WEBHOOK")"

TMP_SQL="$(mktemp)"
trap 'rm -f "$TMP_SQL"' EXIT
sed \
  -e "s|__PUSH_SUPABASE_URL__|${SQL_URL}|g" \
  -e "s|__PUSH_SERVICE_ROLE_KEY__|${SQL_KEY}|g" \
  -e "s|__PUSH_WEBHOOK_SECRET__|${SQL_WH}|g" \
  "$ROOT_DIR/scripts/setup_push_vault_secrets.sql" >"$TMP_SQL"

echo "Configurando Vault (push_supabase_url, push_service_role_key, push_webhook_secret)…"
if ! supabase projects list 2>/dev/null | grep -q "$PROJECT_REF"; then
  echo "Enlazando proyecto $PROJECT_REF…"
  supabase link --project-ref "$PROJECT_REF" --yes
fi
supabase db query --linked --file "$TMP_SQL"

echo "Configurando Edge Function secrets en proyecto $PROJECT_REF…"
SECRET_ARGS=(--project-ref "$PROJECT_REF" PUSH_WEBHOOK_SECRET="$WEBHOOK")
if [[ -n "$FCM_KEY" ]]; then
  SECRET_ARGS+=(FCM_SERVER_KEY="$FCM_KEY")
fi
if [[ -n "$FCM_SA_JSON" ]]; then
  SECRET_ARGS+=(FCM_SERVICE_ACCOUNT_JSON="$FCM_SA_JSON")
fi
supabase secrets set "${SECRET_ARGS[@]}"

echo "Desplegando Edge Function send-push-notification…"
supabase functions deploy send-push-notification --project-ref "$PROJECT_REF"

echo ""
echo "Listo. Verificación rápida:"
echo "  1. En Supabase SQL: select name from vault.secrets where name like 'push_%';"
echo "  2. Login en app móvil → tabla device_push_tokens debe tener fila para el usuario."
echo "  3. Insertar notificación de prueba y revisar logs de send-push-notification."
