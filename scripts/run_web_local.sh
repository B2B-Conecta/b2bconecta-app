#!/usr/bin/env bash
# Flutter web en puerto 3000 (alineado con SUPABASE_AUTH_REDIRECT_URL y config.toml local).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PORT=3000
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port $PORT is already in use (likely a previous flutter run)."
  echo "Stop it with: kill \$(lsof -t -iTCP:$PORT -sTCP:LISTEN)"
  echo "Or close the other Chrome/flutter terminal, then retry."
  exit 1
fi

echo "Starting Flutter web on http://localhost:$PORT (ensure .env is local)..."
echo ""
echo "Registro (local):"
echo "  http://localhost:$PORT/registro"
echo "  http://localhost:$PORT/?registro=1"
echo "Hot reload no basta: hay que reiniciar este script si cambió web/registro."
echo ""
echo "Push (local, opcional): en otra terminal ejecute"
echo "  bash scripts/serve_functions_local.sh"
echo "Web Push en iPhone requiere un build web con inject (Vercel DEV o:"
echo "  flutter build web --release && bash scripts/inject_web_push_sw.sh"
echo "  y servir build/web por HTTPS)."
echo ""
flutter run -d chrome --web-port="$PORT" "$@"
