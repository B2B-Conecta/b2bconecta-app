#!/usr/bin/env bash
# Sube fotos del seed a Storage (bucket product-images / seed/) y opcionalmente
# aplica el enrichment SQL en el proyecto linked.
#
# Uso:
#   bash scripts/upload_seed_product_images.sh staging
#   bash scripts/upload_seed_product_images.sh staging --enrich
#
# Requiere en config/push.env (o env):
#   SUPABASE_SERVICE_ROLE_KEY
#   SUPABASE_URL  (o se arma desde STAGING_PROJECT_REF / PRODUCTION_PROJECT_REF)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_NAME="${1:-staging}"
DO_ENRICH=0
shift || true
for arg in "$@"; do
  case "$arg" in
    --enrich) DO_ENRICH=1 ;;
  esac
done

if [[ -f "$ROOT/config/push.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$ROOT/config/push.env"
  set +a
fi

ASSETS="$ROOT/supabase/seed_assets/product-images"
if [[ ! -d "$ASSETS" ]]; then
  echo "No hay assets en $ASSETS" >&2
  exit 1
fi

case "$ENV_NAME" in
  staging|dev|mobile-staging)
    REF="${STAGING_PROJECT_REF:-kdrccmqcrruixuworlmz}"
    ;;
  production|main|mobile-production)
    echo "Abortado: no suba seed images a producción por este script." >&2
    exit 1
    ;;
  local)
    REF="127.0.0.1"
    SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
    ;;
  *)
    echo "Entorno desconocido: $ENV_NAME (use staging)" >&2
    exit 1
    ;;
esac

if [[ -z "${SUPABASE_URL:-}" || "$SUPABASE_URL" == *"YOUR_"* ]]; then
  SUPABASE_URL="https://${REF}.supabase.co"
fi

if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "Falta SUPABASE_SERVICE_ROLE_KEY (config/push.env)." >&2
  exit 1
fi

echo "Subiendo seed images → $SUPABASE_URL / product-images/seed/"
shopt -s nullglob
files=("$ASSETS"/*.{jpg,jpeg,png,webp})
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No hay archivos de imagen en $ASSETS" >&2
  exit 1
fi

for file in "${files[@]}"; do
  name="$(basename "$file")"
  path="seed/$name"
  mime="image/jpeg"
  case "${name##*.}" in
    png) mime="image/png" ;;
    webp) mime="image/webp" ;;
  esac
  echo "  · $path"
  # upsert vía Storage API
  code="$(curl -sS -o /tmp/seed_upload_body.txt -w "%{http_code}" \
    -X POST \
    "${SUPABASE_URL}/storage/v1/object/product-images/${path}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Content-Type: ${mime}" \
    -H "x-upsert: true" \
    --data-binary @"$file")"
  if [[ "$code" != "200" && "$code" != "201" ]]; then
    echo "Fallo subiendo $name (HTTP $code): $(cat /tmp/seed_upload_body.txt)" >&2
    exit 1
  fi
done

echo "Listo. Base pública:"
echo "  ${SUPABASE_URL}/storage/v1/object/public/product-images/seed/"

if [[ "$DO_ENRICH" -eq 1 ]]; then
  echo "Aplicando seed_enrich_catalog.sql en proyecto linked…"
  (
    cd "$ROOT"
    supabase db query --linked -f supabase/scripts/seed_enrich_catalog.sql
  )
fi
