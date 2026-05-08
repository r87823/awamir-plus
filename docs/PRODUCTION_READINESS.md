# Production Readiness

This checklist defines what must be true before Awamir Plus moves from pilot to live operation.

## Release Gate

- GitHub CI passes on `main`.
- Local quality checks pass:
  - `bash scripts/run_quality_checks.sh`
- A database and files backup exists before every backend deployment.
- `Awamir App Settings` are reviewed before any accounting submit changes.

## Backend Deployment

Use the repeatable Docker deploy script from the repository root:

```bash
CONTAINER=docker-frappe-1 \
SITE=hrms.localhost \
BRANCH=main \
RUN_MIGRATE=0 \
bash scripts/deploy_backend_docker.sh
```

Set `RUN_MIGRATE=1` only when DocTypes, fixtures, patches, or schema-related files changed.

## Mobile Release Gate

- Real mode starts with:

```bash
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc
```

- App launches on a real iPhone.
- Login works for every pilot role.
- The app can complete at least one clean order without using System Admin for operational steps.
- Accounting screen search can find orders and payments by order number.
- ERPNext document status is visible as `Draft`, `Submitted`, or `Cancelled`.

## Operational Pilot Gate

Run a clean pilot order with the intended users:

1. Branch employee creates order and collects deposit.
2. Branch supervisor approves.
3. Distribution assigns production department.
4. Production user from the correct department updates production.
5. Branch employee or driver collects remaining amount.
6. Cashier accepts and closes closure.
7. Accountant creates Sales Order, Payment Entry, Sales Invoice, and allocation.

The final order must show:

- `status = Delivered`
- `payment_status = paid`
- `erp_sync_status = Synced`
- all payments are `Linked To Invoice`
- no `erp_sync_error`

## Accounting Controls

Current pilot settings:

- `submit_sales_order = 1`
- `submit_payment_entry = 1`
- `submit_sales_invoice = 1`
- `submit_work_order = 0`

Do not enable `submit_work_order` until BOM readiness has been validated for the specific products being manufactured.

## Known Follow-Ups

- Verify ERPNext ledger outstanding after every invoice allocation scenario.
- Add BOM coverage only for products selected for Work Order activation.
- Add push notifications only after internal notification flows are stable.
- Add TestFlight distribution after real-device smoke testing is stable.

## Rollback

If a backend deployment causes a runtime issue:

1. Restore the previous code version in `apps/awamir_plus`.
2. Run `bench --site hrms.localhost clear-cache`.
3. Restart the Frappe container.
4. If data was migrated incorrectly, restore the latest pre-deploy backup.

Do not modify ERPNext Core during rollback.
