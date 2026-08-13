#!/usr/bin/env bash
# Build B2B Conecta release AAB for Google Play.
# Default store: mobile-production. QA: MOTOLINK_BUILD_ENV=mobile-staging
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_ENV="${MOTOLINK_BUILD_ENV:-mobile-production}"

unset ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy 2>/dev/null || true

# Prefer Android Studio JBR + real Gradle home (avoid sandbox GRADLE_USER_HOME).
if [[ -z "${JAVA_HOME:-}" && -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"

export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.net.useSystemProxies=false -DsocksProxyHost= -DsocksProxyPort=0 -Dhttp.proxyHost= -Dhttps.proxyHost= -Djava.net.preferIPv4Stack=true"
JAVA_TOOL_OPTIONS="$(echo "$JAVA_TOOL_OPTIONS" | xargs)"
export JAVA_TOOL_OPTIONS

if [[ ! -f "$ROOT_DIR/android/key.properties" || ! -f "$ROOT_DIR/android/upload-keystore.jks" ]]; then
  echo "ERROR: falta android/key.properties o android/upload-keystore.jks (firma de release)."
  exit 1
fi

echo "Activando .env $BUILD_ENV..."
bash "$ROOT_DIR/scripts/use_env.sh" "$BUILD_ENV"

if grep -qE 'YOUR_.*_PUBLISHABLE_KEY|REPLACE_ME' "$ROOT_DIR/.env"; then
  echo "ERROR: .env tiene placeholder. Cree config/env/${BUILD_ENV}.env.local con la publishable key."
  exit 1
fi

echo "Building release AAB..."
flutter build appbundle --release "$@"

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [[ -f "$AAB_PATH" ]]; then
  echo ""
  echo "OK: $ROOT_DIR/$AAB_PATH"
  ls -lh "$AAB_PATH"
fi
