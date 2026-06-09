#!/usr/bin/env bash
# Build MotoLink iOS release (firmado para iPhone físico).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

unset ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy 2>/dev/null || true

if [[ "${CLEAN:-0}" == "1" ]]; then
  echo "Limpiando artefactos previos (CLEAN=1)..."
  flutter clean
fi

flutter pub get

echo "Instalando pods..."
(cd ios && pod install)

echo "Compilando iOS release..."
flutter build ios --release "$@"

APP_PATH="build/ios/iphoneos/Runner.app"
if [[ -d "$APP_PATH" ]]; then
  echo ""
  echo "OK: $ROOT_DIR/$APP_PATH"
  du -sh "$APP_PATH"
fi

echo ""
echo "iOS 26 en dispositivo físico: Debug falla (mprotect/JIT). Usa Release o Profile."
echo ""
echo "Instalar en iPhone conectado:"
echo "  bash scripts/install_ios_device.sh"
echo ""
echo "O desde Xcode:"
echo "  open ios/Runner.xcworkspace"
echo "  Seleccionar iPhone → Scheme Run en Release → Product → Run (⌘R)"
