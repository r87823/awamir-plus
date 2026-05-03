# Awamir Plus Pilot Test Report

Date: 2026-05-03

## Scope

This report documents the limited MVP pilot after the first successful end-to-end run. Accounting submit flags stayed disabled throughout the pilot:

- `submit_sales_order = false`
- `submit_payment_entry = false`
- `submit_sales_invoice = false`
- `submit_work_order = false`

ERPNext accounting documents were created as Draft only.

## Demo Users

| User | Role | Branch / Scope |
| --- | --- | --- |
| `employee@awamir.plus` | Awamir Branch Employee | فرع المروج |
| `supervisor@awamir.plus` | Awamir Branch Supervisor | فرع المروج |
| `distribution@awamir.plus` | Awamir Distribution Manager | فرع المروج |
| `production@awamir.plus` | Awamir Production User | مصنع الحلويات |
| `production.kitchen@awamir.plus` | Awamir Production User | المطبخ |
| `production.buffet@awamir.plus` | Awamir Production User | قسم البوفيه |
| `production.special@awamir.plus` | Awamir Production User | قسم الطلبات الخاصة |
| `driver@awamir.plus` | Awamir Driver | فرع المروج |
| `cashier@awamir.plus` | Awamir Cashier | الخزينة |
| `accountant@awamir.plus` | Awamir Accountant | المحاسبة |
| `admin@awamir.plus` | Awamir System Admin | كل الصلاحيات |

## Orders Tested

| Order | Flow | Sales Order | Payment Entries | Sales Invoice | Final State |
| --- | --- | --- | --- | --- | --- |
| `ORD-2026-00009` | Pickup | `SAL-ORD-2026-00003` | `ACC-PAY-2026-00005`, `ACC-PAY-2026-00006` | `ACC-SINV-2026-00003` | Delivered / Synced |
| `ORD-2026-00010` | Pickup | `SAL-ORD-2026-00004` | `ACC-PAY-2026-00007`, `ACC-PAY-2026-00008` | `ACC-SINV-2026-00004` | Delivered / Synced |
| `ORD-2026-00011` | Pickup | `SAL-ORD-2026-00005` | `ACC-PAY-2026-00009`, `ACC-PAY-2026-00010` | `ACC-SINV-2026-00005` | Delivered / Synced |
| `ORD-2026-00012` | Delivery | `SAL-ORD-2026-00006` | `ACC-PAY-2026-00011`, `ACC-PAY-2026-00012` | `ACC-SINV-2026-00006` | Delivered / Synced |
| `ORD-2026-00013` | Delivery | `SAL-ORD-2026-00007` | `ACC-PAY-2026-00013`, `ACC-PAY-2026-00014` | `ACC-SINV-2026-00007` | Delivered / Synced |
| `ORD-2026-00014` | Delivery | `SAL-ORD-2026-00008` | `ACC-PAY-2026-00015`, `ACC-PAY-2026-00016` | `ACC-SINV-2026-00008` | Delivered / Synced |

## Cash Closures

| Closure | Owner Type | Status | Total |
| --- | --- | --- | --- |
| `CASH-2026-00004` | branch_employee | Closed | 1070.0 |
| `CASH-2026-00005` | driver | Closed | 575.0 |

The repository E2E mock test now covers non-cash payments:

- Card deposit with a transaction reference.
- Transfer remaining payment with a transaction reference.
- Closure totals split by Cash, Card, Transfer, and Other.

## Operational Notes

- Awamir product categories are now filtered using `custom_is_awamir_category` and active Product Department Mapping, so ERPNext default item groups are not shown in the mobile flow.
- Driver seed data now includes phone numbers. Flutter shows the call button only when a phone number exists; otherwise it displays `لا يوجد رقم جوال`.
- Production demo users are available for all execution departments. Each production user is scoped with an `Awamir Production Department` user default and permission.
- `Awamir System Admin` can see all production orders; production users see only their assigned department.

## Readiness Retest

The pre-expansion readiness retest confirmed:

- API categories returned only: `الحلويات`, `الضيافة`, `المطبخ`, `طلبات البوفيه`, `طلبات خاصة`.
- Driver phone returned for `driver@awamir.plus`: `0505000001`.
- Card test order: `ORD-2026-00018`.
- Transfer test order: `ORD-2026-00019`.
- Cash closure used for non-cash totals: `CASH-2026-00006`.
- Closure totals separated payment methods correctly: Cash `0.0`, Card `20.0`, Transfer `20.0`, Other `0.0`.
- Production scope test order: `ORD-2026-00020`.
- Kitchen production user could see `ORD-2026-00020`.
- Sweets production user could not see `ORD-2026-00020`.
- System admin could see `ORD-2026-00020`.
- Submit flags stayed disabled for Sales Order, Payment Entry, Sales Invoice, and Work Order.

## Current Limits

- ERPNext documents are Draft only. Ledger posting is intentionally not active.
- Work Order is not enabled for the pilot. It requires a valid ERPNext BOM per item.
- If a product has no BOM, the expected message is: `لا يمكن إنشاء Work Order لأن المنتج لا يحتوي BOM`.
- No payment gateway is connected.
- Notifications are internal Awamir notifications only. Push notifications are not enabled.

## Recommendations Before Wider Rollout

- Add real branch users and drivers with verified phone numbers.
- Run Card and Transfer scenarios on real devices before finance go-live.
- Decide which products require manufacturing, then create BOMs for those items in ERPNext before enabling Work Order.
- Keep accounting submit flags disabled until finance validates Draft document contents.
- Add a small pilot checklist per branch to capture UX notes and operational exceptions.
