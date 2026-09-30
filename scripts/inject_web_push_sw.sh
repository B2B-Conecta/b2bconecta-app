#!/usr/bin/env bash
# Append Web Push handlers to Flutter's generated service worker without replacing cache logic.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SW="${1:-$ROOT_DIR/build/web/flutter_service_worker.js}"
HANDLERS="$ROOT_DIR/web/push/handlers.js"

if [[ ! -f "$HANDLERS" ]]; then
  echo "Missing $HANDLERS"
  exit 1
fi

if [[ ! -f "$SW" ]]; then
  echo "No Flutter service worker at $SW (skip inject)."
  exit 0
fi

if grep -q "B2B_WEB_PUSH_HANDLERS" "$SW"; then
  echo "Web Push handlers already present in $(basename "$SW")"
  exit 0
fi

{
  printf '\n'
  cat "$HANDLERS"
} >>"$SW"

echo "Injected Web Push handlers into $SW"
