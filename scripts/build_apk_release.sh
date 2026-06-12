#!/usr/bin/env bash
# Build MotoLink release APK avoiding broken local proxy (Cursor/VPN leftovers).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Cursor and some VPN tools inject a dead local proxy; Java/Gradle then fail with
# "Connection refused" (SocksSocketImpl) or "No route to host".
unset ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy 2>/dev/null || true

export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.net.useSystemProxies=false -DsocksProxyHost= -DsocksProxyPort=0 -Dhttp.proxyHost= -Dhttps.proxyHost= -Djava.net.preferIPv4Stack=true"
# Trim duplicate spaces if JAVA_TOOL_OPTIONS was empty.
JAVA_TOOL_OPTIONS="$(echo "$JAVA_TOOL_OPTIONS" | xargs)"
export JAVA_TOOL_OPTIONS

echo "Activando .env mobile-staging (deep link auth)..."
bash "$ROOT_DIR/scripts/use_env.sh" mobile-staging

echo "Building release APK (proxy disabled for Java/Gradle)..."
flutter build apk --release "$@"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [[ -f "$APK_PATH" ]]; then
  echo ""
  echo "OK: $ROOT_DIR/$APK_PATH"
  ls -lh "$APK_PATH"
fi
