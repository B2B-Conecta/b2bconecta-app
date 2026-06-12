#!/usr/bin/env bash
# Edge Functions locales (push notifications).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PUSH_ENV="$ROOT_DIR/config/push.env"

if [[ -f "$PUSH_ENV" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$PUSH_ENV" && set +a
  echo "Secrets push cargados desde config/push.env"
else
  echo "Aviso: cree config/push.env desde config/push.env.example"
fi

export MOTOLINK_FCM_SERVER_KEY="${MOTOLINK_FCM_SERVER_KEY:-${FCM_SERVER_KEY:-}}"
export MOTOLINK_PUSH_WEBHOOK_SECRET="${MOTOLINK_PUSH_WEBHOOK_SECRET:-${PUSH_WEBHOOK_SECRET:-}}"

if [[ -z "${MOTOLINK_FCM_SERVER_KEY:-}" ]]; then
  echo "Aviso: FCM_SERVER_KEY vacío — push se omitirá en local."
fi

echo "Sirviendo Edge Functions en http://127.0.0.1:54321/functions/v1 …"
exec supabase functions serve --env-file "$PUSH_ENV" 2>/dev/null || supabase functions serve
