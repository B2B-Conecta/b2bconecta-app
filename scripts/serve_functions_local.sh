#!/usr/bin/env bash
# Edge Functions locales (correos transaccionales, etc.).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EMAIL_ENV="$ROOT_DIR/config/email.env"
EMAIL_ENV_LOCAL="$ROOT_DIR/config/email.env.local"

export SMTP_USER="${MOTOLINK_SMTP_USER:-motolink.admin@gmail.com}"
export SMTP_FROM="${MOTOLINK_SMTP_FROM:-MotoLink <motolink.admin@gmail.com>}"
export SMTP_HOST="${MOTOLINK_SMTP_HOST:-smtp.gmail.com}"
export SMTP_PORT="${MOTOLINK_SMTP_PORT:-587}"
export SMTP_PASS="${MOTOLINK_SMTP_PASS:-${SMTP_PASS:-}}"

if [[ -f "$EMAIL_ENV" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$EMAIL_ENV" && set +a
  echo "Secrets SMTP cargados desde config/email.env"
else
  echo "Aviso: cree config/email.env desde config/email.env.example"
fi

if [[ -f "$EMAIL_ENV_LOCAL" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$EMAIL_ENV_LOCAL" && set +a
  echo "Overrides locales desde config/email.env.local"
elif [[ -f "$ROOT_DIR/config/email.env.local.example" ]]; then
  echo "Tip local: cp config/email.env.local.example config/email.env.local"
  echo "         (Mailpit http://127.0.0.1:54324 — evita bloqueos SMTP a Gmail desde Docker)"
fi

# config.toml → [edge_runtime.secrets] lee MOTOLINK_SMTP_* del entorno al arrancar serve.
export MOTOLINK_SMTP_USER="${MOTOLINK_SMTP_USER:-${SMTP_USER:-motolink.admin@gmail.com}}"
export MOTOLINK_SMTP_FROM="${MOTOLINK_SMTP_FROM:-${SMTP_FROM:-MotoLink <motolink.admin@gmail.com>}}"
export MOTOLINK_SMTP_HOST="${MOTOLINK_SMTP_HOST:-${SMTP_HOST:-smtp.gmail.com}}"
export MOTOLINK_SMTP_PORT="${MOTOLINK_SMTP_PORT:-${SMTP_PORT:-587}}"
export MOTOLINK_SMTP_PASS="${MOTOLINK_SMTP_PASS:-${SMTP_PASS:-}}"
export SMTP_USER="${SMTP_USER:-$MOTOLINK_SMTP_USER}"
export SMTP_FROM="${SMTP_FROM:-$MOTOLINK_SMTP_FROM}"
export SMTP_HOST="${SMTP_HOST:-$MOTOLINK_SMTP_HOST}"
export SMTP_PORT="${SMTP_PORT:-$MOTOLINK_SMTP_PORT}"
export SMTP_PASS="${SMTP_PASS:-$MOTOLINK_SMTP_PASS}"

SMTP_HOST_EFF="${MOTOLINK_SMTP_HOST:-${SMTP_HOST:-smtp.gmail.com}}"
if [[ "$SMTP_HOST_EFF" == "inbucket" || "$SMTP_HOST_EFF" == *mailpit* ]]; then
  echo "SMTP local → ${SMTP_HOST_EFF}:${MOTOLINK_SMTP_PORT:-${SMTP_PORT:-1025}} (ver bandeja en http://127.0.0.1:54324)"
elif [[ -n "${MOTOLINK_SMTP_PASS:-}" ]]; then
  echo "SMTP Gmail → ${SMTP_HOST_EFF} (contraseña de aplicación cargada)."
else
  echo "Aviso: MOTOLINK_SMTP_PASS vacío — la función no enviará correo real."
  echo "      Tras editar config/email.env reinicie este script (Ctrl+C y volver a ejecutar)."
fi

echo "Sirviendo Edge Functions en http://127.0.0.1:54321/functions/v1 …"
echo "Deje esta terminal abierta mientras prueba la app en Supabase local."

SERVE_ENV_FILE="$EMAIL_ENV"
if [[ -f "$EMAIL_ENV_LOCAL" ]]; then
  SERVE_ENV_FILE="$(mktemp "${TMPDIR:-/tmp}/motolink-smtp-env.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -f '$SERVE_ENV_FILE'" EXIT
  if [[ -f "$EMAIL_ENV" ]]; then
    cat "$EMAIL_ENV" "$EMAIL_ENV_LOCAL" >"$SERVE_ENV_FILE"
  else
    cat "$EMAIL_ENV_LOCAL" >"$SERVE_ENV_FILE"
  fi
fi

if [[ -f "$SERVE_ENV_FILE" ]]; then
  exec supabase functions serve --env-file "$SERVE_ENV_FILE"
else
  exec supabase functions serve
fi
