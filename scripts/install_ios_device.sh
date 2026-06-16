#!/usr/bin/env bash
# Compila MotoLink iOS release y lo instala en el iPhone conectado por cable.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

unset ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy 2>/dev/null || true

DEVICE_ID="${1:-}"
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(flutter devices 2>/dev/null | awk -F '•' '/ios.*mobile/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }')"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No hay iPhone conectado. Conecta el dispositivo por cable y confía en este Mac."
  echo "Luego ejecuta: flutter devices"
  exit 1
fi

echo "Dispositivo: $DEVICE_ID"
BUILD_ENV="${MOTOLINK_BUILD_ENV:-mobile-staging}"
echo "Activando .env $BUILD_ENV..."
bash "$ROOT_DIR/scripts/use_env.sh" "$BUILD_ENV"

echo "Dependencias..."
flutter pub get

echo "Pods..."
(cd ios && pod install)

echo "Compilando iOS release (firma automática, team Xcode)..."
flutter build ios --release

echo "Instalando en iPhone (desinstala la app manualmente si quedó una build Debug rota)..."
flutter install -d "$DEVICE_ID" --release

echo ""
echo "Nota iOS 26+: en iPhone físico NO usar Debug (JIT bloqueado → mprotect error)."
echo "Este script y el scheme Runner ya usan Release."
echo ""
echo "Listo. En el iPhone:"
echo "  Ajustes → General → VPN y gestión de dispositivos → confiar en el desarrollador (si aparece)."
echo "  Abre MotoLink desde el icono."
echo ""
echo "Entorno: revisa .env (staging/production) antes de distribuir."
