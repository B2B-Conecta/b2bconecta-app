#!/usr/bin/env bash
# Build B2B Conecta release APK (proxy disabled for Java/Gradle).
# Default QA: mobile-staging (dev API). Store: MOTOLINK_BUILD_ENV=mobile-production
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# mobile-staging (QA) | mobile-production (store)
BUILD_ENV="${MOTOLINK_BUILD_ENV:-mobile-staging}"

unset ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy 2>/dev/null || true

export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.net.useSystemProxies=false -DsocksProxyHost= -DsocksProxyPort=0 -Dhttp.proxyHost= -Dhttps.proxyHost= -Djava.net.preferIPv4Stack=true"
JAVA_TOOL_OPTIONS="$(echo "$JAVA_TOOL_OPTIONS" | xargs)"
export JAVA_TOOL_OPTIONS

echo "Activando .env $BUILD_ENV..."
bash "$ROOT_DIR/scripts/use_env.sh" "$BUILD_ENV"

if grep -qE 'YOUR_.*_PUBLISHABLE_KEY|REPLACE_ME' "$ROOT_DIR/.env"; then
  echo "ERROR: .env tiene placeholder. Cree config/env/${BUILD_ENV}.env.local con la publishable key."
  exit 1
fi

echo "Building release APK (proxy disabled for Java/Gradle)..."
flutter build apk --release "$@"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [[ -f "$APK_PATH" ]]; then
  echo ""
  echo "OK: $ROOT_DIR/$APK_PATH"
  ls -lh "$APK_PATH"
fi
