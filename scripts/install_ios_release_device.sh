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
TERMINATE_RUNNERS="${TERMINATE_RUNNERS:-1}"

cd "$MOBILE_DIR"

terminate_runner_processes() {
  local pids
  pids="$(
    xcrun devicectl device info processes --device "$DEVICE_ID" 2>/dev/null \
      | awk '/Runner\.app\/Runner/ {print $1}' \
      || true
  )"

  if [[ -z "$pids" ]]; then
    return 0
  fi

  echo "==> Terminating stale Runner processes: $pids"
  local pid
  for pid in $pids; do
    xcrun devicectl device process terminate \
      --device "$DEVICE_ID" \
      --pid "$pid" \
      --kill || true
  done
}

echo "==> Target device: $DEVICE_ID"
flutter devices

if [[ "$UNINSTALL_OLD" == "1" ]]; then
  echo "==> Removing stale old bundle if present: $OLD_BUNDLE_ID"
  xcrun devicectl device uninstall app \
    --device "$DEVICE_ID" \
    "$OLD_BUNDLE_ID" || true
fi

if [[ "$TERMINATE_RUNNERS" == "1" ]]; then
  terminate_runner_processes
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

sleep 2

echo "==> Installed Awamir apps on device"
xcrun devicectl device info apps --device "$DEVICE_ID" \
  | grep -E "Name|Bundle Identifier|Awamir|$BUNDLE_ID" || true

echo "==> Running Awamir process check"
xcrun devicectl device info processes --device "$DEVICE_ID" \
  | grep -E "PID|Runner\\.app/Runner" || true

echo "==> Installed and launched $BUNDLE_ID in release mode."
