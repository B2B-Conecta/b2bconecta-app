#!/usr/bin/env bash
# Build Flutter web on Vercel (Hobby). Instala Flutter stable pinned y empaqueta build/web.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FLUTTER_VERSION="${FLUTTER_VERSION:-3.24.4}"
FLUTTER_HOME="${FLUTTER_HOME:-/tmp/flutter}"

echo "==> Writing .env from Vercel environment"
bash "$ROOT_DIR/scripts/write_build_env.sh"

if [[ ! -d "$FLUTTER_HOME/bin" ]]; then
  echo "==> Installing Flutter $FLUTTER_VERSION"
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
flutter config --enable-web --no-analytics
flutter precache --web
flutter pub get

echo "==> Building the Excel / PDF catalog reader"
# tools/catalog-reader exige Node >=22 y pnpm@11.25.0 (lockfileVersion 9).
# Vercel trae un `pnpm` global viejo (p. ej. 6.x) delante en PATH: tras
# `npm i -g pnpm@11` el comando `pnpm` sigue resolviendo a 6.x y ignora el
# lockfile → "Headless installation requires a pnpm-lock.yaml".
# Usar siempre `npx -y pnpm@PIN` para no depender del PATH.
PNPM_VERSION="${PNPM_VERSION:-11.25.0}"
NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
echo "Node $(node -v); PATH pnpm (si existe): $(command -v pnpm || echo none)"
if [[ "${NODE_MAJOR}" -lt 22 ]]; then
  echo "ERROR: Node ${NODE_MAJOR} detectado; catalog-reader/pnpm@${PNPM_VERSION} requiere Node >= 22."
  echo "En Vercel → Project Settings → Node.js Version → 22.x (package.json engines / .nvmrc)."
  exit 1
fi
run_pnpm() {
  npx --yes "pnpm@${PNPM_VERSION}" "$@"
}
run_pnpm --version
run_pnpm --dir tools/catalog-reader install --frozen-lockfile --ignore-scripts
run_pnpm --dir tools/catalog-reader run build

echo "==> Building Flutter web (release)"
# Flutter 3.24 CanvasKit can leave decoded Chromium VideoFrames unclosed.
# Use CanvasKit's own image codecs until the engine is upgraded and verified.
flutter build web --release --dart-define=BROWSER_IMAGE_DECODING_ENABLED=false

bash "$ROOT_DIR/scripts/inject_web_push_sw.sh"

# El stub web/registro/ es solo para `flutter run` (sin fallback SPA).
# En Vercel el rewrite debe servir index.html y dejar la URL en /registro.
rm -rf build/web/registro

echo "==> Build output: build/web"
