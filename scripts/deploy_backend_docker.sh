#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${CONTAINER:-docker-frappe-1}"
SITE="${SITE:-hrms.localhost}"
BENCH_DIR="${BENCH_DIR:-/home/frappe/frappe-bench}"
APP_DIR="${APP_DIR:-$BENCH_DIR/apps/awamir_plus}"
REPO_URL="${REPO_URL:-https://github.com/r87823/awamir-plus.git}"
BRANCH="${BRANCH:-main}"
SKIP_BACKUP="${SKIP_BACKUP:-0}"
RUN_MIGRATE="${RUN_MIGRATE:-0}"
RESTART_CONTAINER="${RESTART_CONTAINER:-1}"

printf 'Deploying awamir_plus backend from %s (%s)\n' "$REPO_URL" "$BRANCH"
printf 'Container=%s Site=%s Bench=%s App=%s\n' "$CONTAINER" "$SITE" "$BENCH_DIR" "$APP_DIR"

if [[ "$SKIP_BACKUP" != "1" ]]; then
  docker exec "$CONTAINER" bash -lc "cd '$BENCH_DIR' && bench --site '$SITE' backup --with-files"
else
  printf 'Skipping backup because SKIP_BACKUP=1\n'
fi

docker exec -u root "$CONTAINER" bash -lc "
set -euo pipefail
tmp_dir=\$(mktemp -d /tmp/awamir-plus-deploy.XXXXXX)
git clone --depth 1 --branch '$BRANCH' '$REPO_URL' \"\$tmp_dir/repo\"
src=\"\$tmp_dir/repo/backend/awamir_plus\"
dst='$APP_DIR'
test -f \"\$src/pyproject.toml\"
test -d \"\$src/awamir_plus\"
test -d \"\$dst/awamir_plus\"
cp \"\$src/pyproject.toml\" \"\$dst/pyproject.toml\"
cp \"\$src/README.md\" \"\$dst/README.md\"
cp \"\$src/MANIFEST.in\" \"\$dst/MANIFEST.in\"
cp -R \"\$src/awamir_plus/.\" \"\$dst/awamir_plus/\"
chown -R frappe:frappe \"\$dst\"
rm -rf \"\$tmp_dir\"
"

if [[ "$RUN_MIGRATE" == "1" ]]; then
  docker exec "$CONTAINER" bash -lc "cd '$BENCH_DIR' && bench --site '$SITE' migrate"
else
  printf 'Skipping migrate because RUN_MIGRATE is not 1\n'
fi

docker exec "$CONTAINER" bash -lc "
cd '$BENCH_DIR'
python3 -m compileall apps/awamir_plus/awamir_plus
bench --site '$SITE' clear-cache
"

if [[ "$RESTART_CONTAINER" == "1" ]]; then
  docker restart "$CONTAINER" >/dev/null
  printf 'Restarted %s\n' "$CONTAINER"
else
  printf 'Skipping container restart because RESTART_CONTAINER is not 1\n'
fi

printf 'Backend deployment completed.\n'
