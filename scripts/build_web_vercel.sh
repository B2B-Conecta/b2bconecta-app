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

echo "==> Building Flutter web (release)"
flutter build web --release

echo "==> Build output: build/web"
