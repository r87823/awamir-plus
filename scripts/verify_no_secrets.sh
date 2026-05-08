#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

failures=0

while IFS= read -r file; do
  case "$file" in
    .env.example|*/.env.example)
      continue
      ;;
    .env|*/.env|.env.*|*/.env.*|\
    *site_config.json|*common_site_config.json|\
    *.pem|*.key|*.p12|*.jks|*.keystore|\
    *.sql|*.sql.gz|\
    .DS_Store|*/.DS_Store|._*|*/._*)
      printf 'Forbidden tracked file: %s\n' "$file" >&2
      failures=1
      ;;
  esac
done < <(git ls-files)

if [[ "$failures" -ne 0 ]]; then
  printf 'Repository hygiene check failed. Remove sensitive or generated files before committing.\n' >&2
  exit 1
fi

printf 'Repository hygiene check passed.\n'
