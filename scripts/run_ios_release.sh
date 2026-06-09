#!/usr/bin/env bash
# Ejecuta MotoLink en simulador o iPhone sin proxy local (evita Connection refused a Supabase).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

unset ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy 2>/dev/null || true

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE="$(flutter devices 2>/dev/null | awk -F '•' '/ios.*mobile/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }')"
fi

if [[ -n "$DEVICE" ]]; then
  echo "Dispositivo: $DEVICE"
  flutter run --release -d "$DEVICE" "${@:2}"
else
  flutter run --release "${@:1}"
fi
