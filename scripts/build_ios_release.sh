#!/usr/bin/env bash
# Build MotoLink iOS release (para instalar en iPhone vía Xcode).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Evita proxy local muerto (Cursor/VPN) que provoca Connection refused en simulador/dispositivo.
unset ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy 2>/dev/null || true

echo "Limpiando artefactos iOS previos..."
flutter clean
flutter pub get

echo "Instalando pods..."
cd ios
pod install
cd ..

echo "Compilando iOS release (sin codesign para validar build)..."
flutter build ios --release --no-codesign "$@"

echo ""
echo "Build iOS release listo."
echo "Para instalar en iPhone mañana:"
echo "  1. open ios/Runner.xcworkspace"
echo "  2. Conectar iPhone → seleccionar dispositivo físico"
echo "  3. Product → Scheme → Edit Scheme → Run → Build Configuration: Release"
echo "  4. Product → Run (⌘R)"
echo ""
echo "Salida: build/ios/iphoneos/Runner.app"
