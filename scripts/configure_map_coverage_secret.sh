#!/usr/bin/env bash
# Configura MAP_COVERAGE_TOKEN en el proyecto Supabase (Edge Function map-coverage).
# El token NO se imprime entero al final; cópielo de la salida única de openssl.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET="${1:-}"
if [[ "$TARGET" != "staging" && "$TARGET" != "production" ]]; then
  echo "Usage: bash scripts/configure_map_coverage_secret.sh <staging|production>"
  echo "  staging    → DEV kdrccmqcrruixuworlmz"
  echo "  production → MAIN fzugzjcwdzcwfxgviltw"
  exit 1
fi

if [[ "$TARGET" == "staging" ]]; then
  PROJECT_REF="kdrccmqcrruixuworlmz"
else
  PROJECT_REF="fzugzjcwdzcwfxgviltw"
fi

TOKEN="${MAP_COVERAGE_TOKEN:-}"
if [[ -z "$TOKEN" ]]; then
  TOKEN="$(openssl rand -hex 32)"
  echo "Generado MAP_COVERAGE_TOKEN (guárdelo en el canal seguro del Worker):"
  echo "$TOKEN"
  echo ""
fi

echo "Enlazando ${PROJECT_REF}..."
supabase link --project-ref "$PROJECT_REF" --yes

echo "Secret MAP_COVERAGE_TOKEN -> ${PROJECT_REF}"
supabase secrets set --project-ref "$PROJECT_REF" "MAP_COVERAGE_TOKEN=$TOKEN"

echo "Deploy Edge Function map-coverage..."
supabase functions deploy map-coverage --project-ref "$PROJECT_REF" --no-verify-jwt

echo ""
echo "URL: https://${PROJECT_REF}.supabase.co/functions/v1/map-coverage"
echo "Header: Authorization: Bearer <token>"
echo "Metodo: GET"
echo "Pase URL + token por canal seguro (no por WhatsApp)."
