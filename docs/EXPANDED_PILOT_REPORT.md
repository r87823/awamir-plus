# Expanded Pilot Report

Date: 2026-05-03
Run ID: `804169`

## Scope

This expanded pilot was executed against the real `awamir_plus` APIs on ERPNext before enabling accounting submit. The goal was to exercise a broader operating sample across branch order creation, supervisor decisions, distribution, production, delivery, cash closures, and draft accounting sync.

Accounting submit flags were checked before and after the run and stayed disabled:

| Setting | Before | After |
| --- | ---: | ---: |
| `submit_sales_order` | 0 | 0 |
| `submit_payment_entry` | 0 | 0 |
| `submit_sales_invoice` | 0 | 0 |
| `submit_work_order` | 0 | 0 |

No ERPNext ledger posting was enabled.

## Users And Roles

The pilot used the seeded semi-real Awamir users:

| User | Role | Scope |
| --- | --- | --- |
| `employee@awamir.plus` | Awamir Branch Employee | فرع المروج |
| `supervisor@awamir.plus` | Awamir Branch Supervisor | فرع المروج |
| `distribution@awamir.plus` | Awamir Distribution Manager | فرع المروج |
| `production@awamir.plus` | Awamir Production User | مصنع الحلويات |
| `production.kitchen@awamir.plus` | Awamir Production User | المطبخ |
| `production.buffet@awamir.plus` | Awamir Production User | قسم البوفيه |
| `production.special@awamir.plus` | Awamir Production User | قسم الطلبات الخاصة |
| `driver@awamir.plus` | Awamir Driver | فرع المروج, phone `0505000001` |
| `cashier@awamir.plus` | Awamir Cashier | Cash closure review |
| `accountant@awamir.plus` | Awamir Accountant | Draft ERPNext accounting sync |
| `admin@awamir.plus` | Awamir System Admin | Cross-scope verification |

## Data Readiness

Only Awamir categories were returned by `get_categories`:

- الحلويات
- الضيافة
- المطبخ
- طلبات البوفيه
- طلبات خاصة

Production departments used:

- مصنع الحلويات
- المطبخ
- قسم البوفيه
- قسم الطلبات الخاصة

The pilot used seeded products and prices close to operating scenarios, including sweets, kitchen items, buffet products, special orders, and hospitality items. Test customers included individual and company-style names, phone numbers, delivery addresses, and Google Maps links.

## Order Summary

Total orders executed in this expanded pilot: **27**.

| Final Status | Count |
| --- | ---: |
| Delivered | 18 |
| Rejected | 3 |
| Returned For Edit | 2 |
| Delivery Failed | 3 |
| Draft, supporting returned closure test | 1 |

| Fulfillment Type | Count |
| --- | ---: |
| Pickup | 15 |
| Delivery | 12 |

| Product Group | Count |
| --- | ---: |
| الحلويات | 7 |
| المطبخ | 6 |
| طلبات البوفيه | 6 |
| طلبات خاصة | 4 |
| الضيافة | 4 |

| Production Department | Count |
| --- | ---: |
| مصنع الحلويات | 5 |
| المطبخ | 5 |
| قسم البوفيه | 5 |
| قسم الطلبات الخاصة | 6 |

## Payment Coverage

Deposit payment methods:

| Method | Count |
| --- | ---: |
| Cash | 13 |
| Card | 7 |
| Transfer | 6 |
| Other | 1 |

Remaining payment methods:

| Method | Count |
| --- | ---: |
| Cash | 9 |
| Card | 6 |
| Transfer | 6 |

Payment references were saved for non-cash payments during the pilot.

## Orders Tested

| Order | Result | Fulfillment | Group | Department | Deposit | Remaining |
| --- | --- | --- | --- | --- | --- | --- |
| `ORD-2026-00021` | Delivered | Pickup | الحلويات | مصنع الحلويات | Cash | Cash |
| `ORD-2026-00022` | Delivered | Pickup | المطبخ | المطبخ | Card | Card |
| `ORD-2026-00023` | Delivered | Pickup | طلبات البوفيه | قسم البوفيه | Transfer | Transfer |
| `ORD-2026-00024` | Delivered | Pickup | طلبات خاصة | قسم الطلبات الخاصة | Cash | Card |
| `ORD-2026-00025` | Delivered | Pickup | الضيافة | قسم الطلبات الخاصة | Card | Transfer |
| `ORD-2026-00026` | Delivered | Delivery | الحلويات | مصنع الحلويات | Cash | Cash |
| `ORD-2026-00027` | Delivered | Delivery | المطبخ | المطبخ | Card | Card |
| `ORD-2026-00028` | Delivered | Delivery | طلبات البوفيه | قسم البوفيه | Transfer | Cash |
| `ORD-2026-00029` | Delivered | Delivery | طلبات خاصة | قسم الطلبات الخاصة | Cash | Transfer |
| `ORD-2026-00030` | Delivered | Delivery | الضيافة | قسم الطلبات الخاصة | Card | Cash |
| `ORD-2026-00031` | Delivered | Pickup | الحلويات | مصنع الحلويات | Transfer | Card |
| `ORD-2026-00032` | Delivered | Delivery | المطبخ | المطبخ | Cash | Card |
| `ORD-2026-00033` | Delivered | Pickup | طلبات البوفيه | قسم البوفيه | Card | Cash |
| `ORD-2026-00034` | Delivered | Delivery | طلبات خاصة | قسم الطلبات الخاصة | Transfer | Transfer |
| `ORD-2026-00035` | Delivered | Pickup | الضيافة | قسم الطلبات الخاصة | Cash | Transfer |
| `ORD-2026-00036` | Delivered | Delivery | الحلويات | مصنع الحلويات | Card | Transfer |
| `ORD-2026-00037` | Delivered | Pickup | المطبخ | المطبخ | Transfer | Cash |
| `ORD-2026-00038` | Delivered | Delivery | طلبات البوفيه | قسم البوفيه | Cash | Card |
| `ORD-2026-00039` | Rejected | Pickup | الحلويات | - | None | - |
| `ORD-2026-00040` | Rejected | Pickup | المطبخ | - | None | - |
| `ORD-2026-00041` | Rejected | Pickup | طلبات البوفيه | - | None | - |
| `ORD-2026-00042` | Returned For Edit | Pickup | طلبات خاصة | - | None | - |
| `ORD-2026-00043` | Returned For Edit | Pickup | الضيافة | - | None | - |
| `ORD-2026-00044` | Delivery Failed | Delivery | الحلويات | مصنع الحلويات | Cash | Not collected |
| `ORD-2026-00045` | Delivery Failed | Delivery | المطبخ | المطبخ | Card | Not collected |
| `ORD-2026-00046` | Delivery Failed | Delivery | طلبات البوفيه | قسم البوفيه | Transfer | Not collected |
| `ORD-2026-00047` | Draft | Pickup | الحلويات | - | Other | - |

## Cash Closures

Pre-pilot cleanup:

- Readiness closure `CASH-2026-00006` was closed with total `40.0` before creating the expanded pilot orders, to keep the expanded pilot closure results isolated.

Expanded pilot closures:

| Closure | Owner | Status | Cash | Card | Transfer | Other | Total | Difference |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `CASH-2026-00007` | Branch Employee | Closed | 1225.0 | 808.75 | 1930.0 | 0.0 | 3963.75 | 0.0 |
| `CASH-2026-00008` | Driver | Closed | 663.75 | 1087.5 | 498.75 | 0.0 | 2250.0 | 7.0 |
| `CASH-2026-00009` | Branch Employee | Returned For Review | 0.0 | 0.0 | 0.0 | 15.0 | 15.0 | n/a |

Cashier scenarios covered:

- Accepted branch employee closure with no difference.
- Accepted driver closure with a recorded difference reason.
- Returned a branch employee closure for review with a reason.

## Accounting Draft Sync

Draft accounting sync was completed for the 18 delivered orders only.

| Metric | Result |
| --- | ---: |
| Delivered orders synced | 18 |
| Sales Orders created | 18 |
| Payment Entries created | 36 |
| Sales Invoices created | 18 |
| Accounting errors | 0 |

Sales Orders generated: `SAL-ORD-2026-00009` through `SAL-ORD-2026-00026`.

Sales Invoices generated: `ACC-SINV-2026-00009` through `ACC-SINV-2026-00026`.

All synced delivered orders ended with `erp_sync_status = Synced`. All ERPNext accounting documents remain Draft because submit flags are still disabled.

## Issues Found And Fixed

One operational backend issue was found during the pilot:

- `get_my_daily_cash_closure` can create or attach payments to a cash closure, but it was often called through GET. Frappe does not reliably commit side effects from GET requests, so the app could receive a closure response that was not persisted yet.
- Fix applied in `awamir_plus.api.cash_closure.get_my_daily_cash_closure`: explicit commit after creating or recalculating a daily cash closure.

No workflow-level changes were made.

## UX Notes

- The operational flow is usable across roles, but long accounting batches should keep strong loading feedback and avoid duplicate taps.
- Driver phone availability now matters: records with phone numbers make the call action useful; missing numbers should continue showing `لا يوجد رقم جوال`.
- Cashier screens should keep highlighting method totals and differences clearly, especially when accepting with a difference.
- Supervisor rejection and return dialogs behaved as expected; reasons/notes are essential for auditability.

## Accountant And Cashier Notes

- Draft Sales Orders, Payment Entries, and Sales Invoices were created consistently.
- Payment method totals separated correctly across Cash, Card, Transfer, and Other.
- Difference handling worked and saved `difference_amount` plus reason.
- Returned cash closure moved payments back into review status as expected.
- Ledger posting must remain disabled until finance approves Draft document structure.

## Production And Driver Notes

- Production users saw only orders assigned to their execution department.
- System admin could see all production orders.
- Delivery sequence was enforced: assigned, picked up, out for delivery, delivered or failed.
- Delivery Failed worked with a required reason and remained visible for review.

## Current Constraints

- Work Order is still not enabled. It requires BOM setup per product before testing.
- No payment gateway is connected.
- Notifications are in-system only.
- Accounting documents are Draft only; no ERPNext ledger posting has been enabled.

## Recommendations Before Go-Live

- Keep submit flags disabled until finance signs off on Draft Sales Order, Payment Entry, and Sales Invoice content.
- Add BOMs for a small subset of manufacturing products before any Work Order pilot.
- Run another device-based test with branch staff using the Flutter UI, focusing on speed of product search, payment entry, and delivery actions.
- Add more real driver phone numbers before wider rollout.
- Define cashier handling policy for over/short differences before enabling accounting submit.

## Post-Submit Remaining Validation - 2026-05-08

This follow-up was run after controlled submit activation for Sales Order, Payment Entry, and Sales Invoice. `submit_work_order` stayed disabled.

### Scenarios Completed

| Scenario | Order | Result |
| --- | --- | --- |
| Full pickup E2E from Flutter/iOS flow | `ORD-2026-00078` | Delivered, closure accepted, accounting synced |
| Delivery success with driver closure | `ORD-2026-00079` | Delivered, driver closure accepted; exposed delivery fee accounting gap |
| Card payment pickup | `ORD-2026-00080` | Delivered, Card reference saved, accounting synced |
| Transfer payment pickup | `ORD-2026-00081` | Delivered, Transfer reference saved, accounting synced |
| Supervisor rejection | `ORD-2026-00082` | Rejected with reason |
| Supervisor return for edit | `ORD-2026-00083` | Returned For Edit with note |
| Delivery failed | `ORD-2026-00084` | Delivery Failed with reason |
| Delivery fee accounting retest | `ORD-2026-00085` | Delivered, delivery fee included in ERPNext accounting, synced |

### Key Accounting Results

`ORD-2026-00078` completed the full submitted accounting path:

- Sales Order: `SAL-ORD-2026-00058`, `docstatus = 1`
- Payment Entries: `ACC-PAY-2026-00086`, `ACC-PAY-2026-00087`, both `docstatus = 1`
- Sales Invoice: `ACC-SINV-2026-00032`, `docstatus = 1`
- Final sync: `Synced`
- Payments: `Linked To Invoice`

Card and Transfer payment coverage:

- `ORD-2026-00080`: `Card`, reference `CARD-PILOT-001`, Sales Order `SAL-ORD-2026-00060`, Sales Invoice `ACC-SINV-2026-00033`, synced.
- `ORD-2026-00081`: `Transfer`, reference `TR-PILOT-001`, Sales Order `SAL-ORD-2026-00061`, Sales Invoice `ACC-SINV-2026-00034`, synced.
- Employee closure `CASH-2026-00043` separated totals correctly: Cash `20.0`, Card `160.0`, Transfer `160.0`, Other `0.0`, Total `340.0`.

### Delivery Fee Issue And Fix

During the delivery scenario `ORD-2026-00079`, ERPNext rejected one Payment Entry because the order collected product amount plus delivery fee, while the generated Sales Order and Sales Invoice only contained product rows. The error was:

`المبلغ المخصص لا يمكن أن يكون أكبر من المبلغ المستحق`

Fix applied in `awamir_plus.services.accounting`:

- If `Awamir Order Request.delivery_fee > 0`, add a non-stock ERPNext item row `AWAMIR-DELIVERY-FEE` to the Sales Order.
- Add the same delivery fee row to the Sales Invoice.
- Create the delivery fee item automatically if missing, under `Services` when available.

Retest result:

- Order: `ORD-2026-00085`
- Sales Order: `SAL-ORD-2026-00062`, `docstatus = 1`, grand total `110.0`
- Sales Invoice: `ACC-SINV-2026-00035`, `docstatus = 1`, grand total `110.0`
- Payment Entries: `ACC-PAY-2026-00090` for `20.0`, `ACC-PAY-2026-00091` for `90.0`, both `docstatus = 1`
- Delivery fee item: `AWAMIR-DELIVERY-FEE`, amount `15.0`
- Final sync: `Synced`
- Employee closure: `CASH-2026-00044`
- Driver closure: `CASH-2026-00045`

### Remaining Operational Notes

- `ORD-2026-00079` remains a useful historical failed accounting test caused by the delivery-fee gap before the fix.
- Work Order submit remains disabled and should not be activated until BOM coverage is expanded and tested.
- Delivery, driver collection, non-cash payment references, rejection, return-for-edit, and delivery-failed paths are now validated against the real server.
