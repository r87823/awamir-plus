#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile/awamir_plus_mobile"

cd "$ROOT_DIR"

echo "==> Checking repository hygiene"
bash scripts/verify_no_secrets.sh

echo "==> Compiling Frappe app Python files"
python3 -m compileall backend/awamir_plus/awamir_plus

echo "==> Running Flutter analyze"
(
  cd "$MOBILE_DIR"
  flutter analyze
)

echo "==> Running Flutter tests"
(
  cd "$MOBILE_DIR"
  flutter test
)

echo "All quality checks passed."
