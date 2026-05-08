#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile/awamir_plus_mobile"

DEVICE_ID="${DEVICE_ID:-00008130-0014643A26F2001C}"
BUNDLE_ID="${BUNDLE_ID:-com.awamir.plus}"
OLD_BUNDLE_ID="${OLD_BUNDLE_ID:-com.awamirplus.awamirMobile}"
ERPNEXT_BASE_URL="${ERPNEXT_BASE_URL:-https://awamirplus.r8787m.cc}"
USE_MOCK_DATA="${USE_MOCK_DATA:-false}"
RUN_CLEAN="${RUN_CLEAN:-0}"
UNINSTALL_OLD="${UNINSTALL_OLD:-1}"

cd "$MOBILE_DIR"

echo "==> Target device: $DEVICE_ID"
flutter devices

if [[ "$UNINSTALL_OLD" == "1" ]]; then
  echo "==> Removing stale old bundle if present: $OLD_BUNDLE_ID"
  xcrun devicectl device uninstall app \
    --device "$DEVICE_ID" \
    "$OLD_BUNDLE_ID" || true
fi

if [[ "$RUN_CLEAN" == "1" ]]; then
  echo "==> Running flutter clean"
  flutter clean
fi

echo "==> Resolving Flutter dependencies"
flutter pub get

echo "==> Building signed iOS release"
flutter build ios --release \
  --dart-define=USE_MOCK_DATA="$USE_MOCK_DATA" \
  --dart-define=ERPNEXT_BASE_URL="$ERPNEXT_BASE_URL"

echo "==> Installing release app on device"
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  build/ios/iphoneos/Runner.app

echo "==> Launching $BUNDLE_ID"
xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  "$BUNDLE_ID"

echo "==> Installed and launched $BUNDLE_ID in release mode."
