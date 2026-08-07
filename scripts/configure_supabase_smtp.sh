#!/usr/bin/env bash
# Configura SMTP Auth (confirmación + recovery) en Supabase remoto.
# Uso:
#   bash scripts/configure_supabase_smtp.sh staging
#   bash scripts/configure_supabase_smtp.sh production
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Uso: $0 staging|production"
  exit 1
fi

SMTP_ENV="$ROOT_DIR/config/smtp.env"
if [[ ! -f "$SMTP_ENV" ]]; then
  echo "Copie config/smtp.env.example → config/smtp.env y complete SMTP_PASS (App Password de Gmail)."
  exit 1
fi

# shellcheck disable=SC1090
set -a && source "$SMTP_ENV" && set +a

SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-b2bconecta.ve@gmail.com}"
SMTP_PASS="${SMTP_PASS:-}"
SMTP_ADMIN_EMAIL="${SMTP_ADMIN_EMAIL:-b2bconecta.ve@gmail.com}"
SMTP_SENDER_NAME="${SMTP_SENDER_NAME:-B2B Conecta}"

# Gmail App Passwords suelen venir con espacios; SMTP acepta sin espacios.
SMTP_PASS="${SMTP_PASS// /}"

if [[ -z "$SMTP_PASS" ]]; then
  echo "SMTP_PASS vacío en config/smtp.env. Genere una App Password de Gmail y péguela ahí."
  echo "Si tiene espacios, entrecomíllela: SMTP_PASS=\"xxxx xxxx xxxx xxxx\""
  exit 1
fi

case "$TARGET" in
  staging|dev)
    PROJECT_REF="${STAGING_PROJECT_REF:-kdrccmqcrruixuworlmz}"
    SITE_URL="${STAGING_SITE_URL:-https://b2bconecta-app-git-dev-b2bconecta.vercel.app}"
    URI_ALLOW_LIST="${STAGING_URI_ALLOW_LIST:-https://b2bconecta-app-git-dev-b2bconecta.vercel.app/*,http://localhost:3000/*,http://127.0.0.1:3000/*,com.carlosf12.motolinkProApp://auth-callback}"
    ;;
  production|main)
    PROJECT_REF="${PRODUCTION_PROJECT_REF:-fzugzjcwdzcwfxgviltw}"
    SITE_URL="${PRODUCTION_SITE_URL:-https://www.b2bconecta.com.ve}"
    URI_ALLOW_LIST="${PRODUCTION_URI_ALLOW_LIST:-https://www.b2bconecta.com.ve/*,http://localhost:3000/*,http://127.0.0.1:3000/*,com.carlosf12.motolinkProApp://auth-callback}"
    ;;
  *)
    echo "Target desconocido: $TARGET (use staging|production)"
    exit 1
    ;;
esac

# Decodifica secretos del Keychain escritos por go-keyring (Supabase CLI).
_decode_keyring_secret() {
  local raw="$1"
  raw="$(printf '%s' "$raw" | tr -d '\n')"
  if [[ "$raw" == go-keyring-base64:* ]]; then
    printf '%s' "${raw#go-keyring-base64:}" | base64 --decode 2>/dev/null || true
  elif [[ "$raw" == go-keyring-encoded:* ]]; then
    printf '%s' "${raw#go-keyring-encoded:}" | xxd -r -p 2>/dev/null || true
  else
    printf '%s' "$raw"
  fi
}

_load_token_from_keychain() {
  command -v security >/dev/null 2>&1 || return 1
  local acct raw decoded
  # Perfil default CLI = "supabase"; legacy = "access-token"
  for acct in supabase access-token; do
    raw="$(security find-generic-password -s "Supabase CLI" -wa "$acct" 2>/dev/null || true)"
    [[ -z "$raw" ]] && continue
    decoded="$(_decode_keyring_secret "$raw")"
    if [[ -n "$decoded" ]]; then
      printf '%s' "$decoded"
      return 0
    fi
  done
  return 1
}

ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:-}"
if [[ -z "$ACCESS_TOKEN" ]]; then
  for token_file in \
    "$HOME/.supabase/access-token" \
    "$HOME/.config/supabase/access-token" \
    "$HOME/Library/Application Support/supabase/access-token"
  do
    if [[ -f "$token_file" ]]; then
      ACCESS_TOKEN="$(tr -d '[:space:]' <"$token_file")"
      break
    fi
  done
fi
if [[ -z "$ACCESS_TOKEN" ]]; then
  ACCESS_TOKEN="$(_load_token_from_keychain || true)"
fi
if [[ -z "$ACCESS_TOKEN" ]]; then
  cat <<'EOF'
Falta SUPABASE_ACCESS_TOKEN (el login del CLI no expone el token a este script).

Camino recomendado (2 min):
  1) Abra https://supabase.com/dashboard/account/tokens
  2) Generate new token → cópielo (empieza por sbp_…)
  3) En config/smtp.env agregue:
       SUPABASE_ACCESS_TOKEN=sbp_...
  4) Vuelva a ejecutar:
       bash scripts/configure_supabase_smtp.sh staging
       bash scripts/configure_supabase_smtp.sh production

EOF
  exit 1
fi

echo "Actualizando SMTP Auth en proyecto $PROJECT_REF ($TARGET)…"
echo "  From: $SMTP_ADMIN_EMAIL ($SMTP_SENDER_NAME)"
echo "  Host: $SMTP_HOST:$SMTP_PORT"
echo "  Site URL: $SITE_URL"

PAYLOAD="$(python3 - <<'PY' "$SMTP_HOST" "$SMTP_PORT" "$SMTP_USER" "$SMTP_PASS" "$SMTP_ADMIN_EMAIL" "$SMTP_SENDER_NAME" "$SITE_URL" "$URI_ALLOW_LIST"
import json, sys
host, port, user, password, admin, sender, site, allow = sys.argv[1:9]
print(json.dumps({
    "external_email_enabled": True,
    "mailer_secure_email_change_enabled": True,
    "mailer_autoconfirm": False,
    "smtp_host": host,
    "smtp_port": str(port),
    "smtp_user": user,
    "smtp_pass": password,
    "smtp_admin_email": admin,
    "smtp_sender_name": sender,
    "site_url": site,
    "uri_allow_list": allow,
}))
PY
)"

HTTP_CODE="$(curl -sS -o /tmp/supabase_smtp_resp.json -w "%{http_code}" \
  -X PATCH "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")"

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Error HTTP $HTTP_CODE al actualizar Auth config:"
  cat /tmp/supabase_smtp_resp.json
  echo
  exit 1
fi

echo "OK. SMTP y redirects aplicados en $PROJECT_REF."
echo "Verifique en Dashboard → Authentication → Emails (SMTP) y URL Configuration."
echo "Pruebe: registro (confirmación) y «Olvidé mi contraseña» abriendo el link en el mismo navegador."
