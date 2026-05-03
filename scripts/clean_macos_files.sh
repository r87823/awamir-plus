#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find "$ROOT_DIR" \
  \( -name ".DS_Store" -o -name "._*" \) \
  -type f \
  -print \
  -delete
