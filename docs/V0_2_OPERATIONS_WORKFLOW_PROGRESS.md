# Awamir Plus v0.2 Operations Workflow Progress

This document tracks the first implementation slice of the expanded operations workflow.

## Implemented In This Slice

- Added a backend permission catalog for semantic operational permissions.
- Added compatibility mapping from the existing Frappe roles to the new semantic roles:
  - `branch_operator`
  - `branch_supervisor`
  - `fulfillment_coordinator`
  - `production_operator`
  - `driver`
  - `cashier`
  - `accountant`
  - `platform_admin`
- Exposed `semantic_roles` and `permissions` from `awamir_plus.api.auth.get_current_user`.
- Updated Flutter `AccessControl` so operational checks use permissions instead of direct role checks.
- Added initial branch seed data:
  - فرع الشرايع
  - فرع الخضراء
  - فرع العوالي
  - فرع الستين
  - فرع النوارية
- Added production department metadata:
  - `production_center`
  - `daily_capacity`
- Updated seed data for the new factory and kitchen departments.
- Added split status fields to `Awamir Order Request` while preserving the existing `status` field:
  - `order_status`
  - `production_status`
  - `delivery_status`
  - `payment_status`
  - `accounting_status`
- Added Department Work Order foundation:
  - `Awamir Department Work Order`
  - `Awamir Department Work Order Item`
- Added Delivery Batch foundation:
  - `Awamir Delivery Batch`
  - `Awamir Delivery Batch Order`
- Added idempotent services for:
  - Creating department work orders grouped by product/department mapping.
  - Creating delivery batches grouped by destination branch.
- Added audit and idempotency foundation:
  - `Awamir Audit Log`
  - `Awamir Idempotency Key`
  - Shared helpers for request hashing, audit logging, and idempotent responses.
- Migrated the main backend APIs from role-only checks to permission checks:
  - Orders
  - Supervisor approvals
  - Distribution
  - Production
  - Delivery
  - Cash closures
  - Accounting
- Added soft cancellation support:
  - `order.cancel` semantic permission.
  - `awamir_plus.api.orders.cancel_order`
  - Cancels related department work orders without deleting operational records.
  - Blocks cancellation of delivered orders.
- Added operational extension fields requested in `txt.txt`:
  - priority and scheduled-order fields.
  - delivery window and pickup-time fields.
  - packing status foundation.
  - proof-of-delivery fields on orders and delivery assignments.
  - soft cancellation metadata fields.
- Added delivery batch `pending` status while keeping legacy `draft` compatibility.
- Added production capacity snapshots on department work orders:
  - department daily capacity.
  - current open work order count.
  - capacity warning message when the count exceeds configured capacity.
- Removed remaining direct role checks from Flutter operational screen routing and replaced them with permission checks.
- Added Flutter native models and repository/service contracts for:
  - Department work orders
  - Delivery batches
- Added operational UI surfaces:
  - Department work orders inside production order details.
  - Delivery batch preparation and driver assignment inside Distribution.
- Added Flutter production capacity visibility:
  - Department daily capacity.
  - Open work order count.
  - Capacity warning banner inside production work order cards.
- Added Flutter proof-of-delivery capture UI:
  - Pickup delivery proof note/reference entry.
  - Driver delivery proof note/reference entry.
  - Backward-compatible mock and ERPNext service contracts.
- Added Flutter tests for:
  - Department work order idempotency in mock mode.
  - Department work order status updates.
  - Delivery batch creation from ready delivery orders.
  - Delivery batch assignment to a driver.
- Added backend contract tests for:
  - v0.2 permissions.
  - split order status fields.
  - department work order DocTypes.
  - delivery batch DocTypes.
  - audit/idempotency DocTypes.
- Added a read-only Frappe smoke script:
  - `bench --site <site> execute awamir_plus.scripts.smoke_v02.run`

## Compatibility Notes

- The MVP workflow remains compatible with the existing single `status` field.
- Existing Flutter screens continue to consume the current order responses.
- Department work orders and delivery batches are returned as additional fields in order details.
- Existing direct driver assignment remains available alongside batch-based delivery assignment during the transition.

## New Backend APIs

- `awamir_plus.api.distribution.create_department_work_orders`
- `awamir_plus.api.distribution.get_department_work_orders`
- `awamir_plus.api.production.get_department_work_orders`
- `awamir_plus.api.production.update_work_order_status`
- `awamir_plus.api.delivery.create_delivery_batches`
- `awamir_plus.api.delivery.get_delivery_batches`
- `awamir_plus.api.delivery.assign_delivery_batch`

## New Operational Safety Utilities

- `make_audit_log(...)`
- `get_request_idempotency_key(...)`
- `get_idempotent_response(...)`
- `save_idempotent_response(...)`
- `run_idempotent(...)`

The order creation endpoints now support idempotency:

- `create_order`
- `save_order_as_draft`
- `submit_order_for_approval`

Supported idempotency sources:

- `Idempotency-Key` request header
- `X-Idempotency-Key` request header
- `idempotency_key` payload field

Additional mutating APIs now accept the same idempotency sources for safe mobile retries:

- `approve_order`
- `reject_order`
- `return_order_for_edit`
- `assign_production_department`
- `create_department_work_orders`
- `update_production_status`
- `update_work_order_status`
- `create_delivery_batches`
- `assign_delivery_batch`
- `submit_cash_closure`
- `accept_cash_closure`
- `return_cash_closure`
- `close_cash_closure`
- `create_sales_order_for_order`
- `create_work_order_for_order`
- `post_accepted_payments_to_erpnext`
- `create_payment_entry_for_payment`
- `create_sales_invoice_for_order`
- `allocate_advance_payment_to_invoice`
- `sync_order_accounting_status`

Reusing an idempotency key with a different payload is blocked by request-hash validation.

List APIs now accept backward-compatible pagination inputs:

- `limit_start`
- `limit_page_length`

Status filters were added where useful for operational queues.

## Remaining v0.2 Work

- Smoke test the new production capacity warning and delivery proof UI from a real iPhone.
- Smoke test delivery batch assignment from Distribution against the real server after the next mobile install.
- Confirm production department capacities with the operations team before the expanded pilot.
- Optional future expansion: Trip management above Delivery Batches.
- Optional future expansion: signature, camera image upload, and QR capture widgets for proof of delivery.
