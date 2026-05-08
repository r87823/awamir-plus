# Docker Deployment

These commands target the current ERPNext Docker environment:

- Container: `docker-frappe-1`
- Site: `hrms.localhost`
- Bench path: `~/frappe-bench`

## Clean Local Files

Before packaging backend files from macOS:

```bash
scripts/clean_macos_files.sh
find backend -name '._*' -o -name '.DS_Store'
```

## Backup

Always take a backup before `install-app` or `migrate`:

```bash
docker exec -it docker-frappe-1 bash
cd ~/frappe-bench
bench --site hrms.localhost backup --with-files
```

## Install App

The app path inside bench must be:

```text
~/frappe-bench/apps/awamir_plus
```

The path must directly contain the Frappe app package, `pyproject.toml`, and `awamir_plus/hooks.py`.

```bash
cd ~/frappe-bench
bench --site hrms.localhost install-app awamir_plus
bench --site hrms.localhost migrate
bench --site hrms.localhost clear-cache
bench restart
```

## Update Existing App

Preferred repeatable deployment from this repository:

```bash
CONTAINER=docker-frappe-1 \
SITE=hrms.localhost \
BRANCH=main \
RUN_MIGRATE=0 \
bash scripts/deploy_backend_docker.sh
```

Use `RUN_MIGRATE=1` only when DocTypes, fixtures, patches, or schema-related files changed.

Manual fallback after copying changed files into `apps/awamir_plus`:

```bash
cd ~/frappe-bench
bench --site hrms.localhost backup --with-files
bench --site hrms.localhost migrate
bench --site hrms.localhost clear-cache
bench restart
```

## Verify

```bash
bench --site hrms.localhost list-apps
bench --site hrms.localhost execute awamir_plus.scripts.seed_demo_data.run
python3 -m compileall apps/awamir_plus/awamir_plus
```

Check protected API behavior:

```text
GET https://awamirplus.r8787m.cc/api/method/awamir_plus.api.auth.get_current_user
```

Without a valid session this should return 403.
