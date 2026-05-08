# Awamir Plus v0.2 Deployment Checklist

This checklist is for deploying the v0.2 operational workflow changes after the code is committed and pulled on the ERPNext Docker server.

## Scope

v0.2 adds:

- Semantic permission checks across Awamir APIs.
- Audit and idempotency DocTypes.
- Split operational status fields on `Awamir Order Request`.
- Department work orders.
- Delivery batches.
- Soft order cancellation.
- Backward-compatible pagination/filtering for operational queues.

## Pre-Deployment

1. Confirm the working branch is committed and pushed.
2. Confirm no secrets or local environment files are included.
3. Confirm accounting submit flags remain as intended:
   - `submit_sales_order`
   - `submit_payment_entry`
   - `submit_sales_invoice`
   - `submit_work_order`

## Server Commands

Run from inside the Frappe container:

```bash
docker exec -it docker-frappe-1 bash
cd ~/frappe-bench
bench --site hrms.localhost backup --with-files
```

Update the app code:

```bash
cd ~/frappe-bench/apps/awamir_plus
git status
git pull origin main
```

Migrate and clear cache:

```bash
cd ~/frappe-bench
bench --site hrms.localhost migrate
bench --site hrms.localhost clear-cache
bench restart
```

## Read-Only Smoke Check

After migration:

```bash
bench --site hrms.localhost execute awamir_plus.scripts.smoke_v02.run
```

Expected:

- `ok` is `true`.
- No missing DocTypes.
- No missing split status fields.
- Settings flags are visible in the returned payload.

## Manual API Smoke Checks

Use an authenticated ERPNext session.

```bash
bench --site hrms.localhost execute awamir_plus.api.auth.get_current_user
bench --site hrms.localhost execute awamir_plus.api.distribution.get_distribution_orders
bench --site hrms.localhost execute awamir_plus.api.production.get_department_work_orders
bench --site hrms.localhost execute awamir_plus.api.delivery.get_delivery_batches
```

For idempotency-sensitive actions, test with an `Idempotency-Key` header from Flutter/API clients. Reusing the same key with the same payload should return the cached response. Reusing the same key with a different payload should fail.

## Flutter Smoke Checks

Run real mode:

```bash
cd mobile/awamir_plus_mobile
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc
```

Check:

- Login.
- Categories/products load.
- Create order as branch employee.
- Supervisor approval.
- Distribution to production department.
- Department work order visible in Production.
- Ready for delivery creates delivery batch.
- Delivery batch can be assigned to driver.
- Cancel action returns a clear result when used with a reason.

## Rollback

If migration fails:

1. Do not modify ERPNext Core.
2. Keep the backup path from `bench backup`.
3. Revert only the `awamir_plus` app code to the previous Git commit.
4. Restore the site backup if schema/data was partially migrated and cannot be corrected safely.

## Notes

- This deployment does not require enabling `submit_work_order`.
- Existing direct driver assignment remains available while delivery batches are introduced.
- Existing single `status` remains the compatibility field during the v0.2 transition.
