# Controlled ERPNext Submit Activation Report

Date: 2026-05-03  
Phase: 1 - `submit_sales_order` only

## Scope

This controlled activation enabled ERPNext submit for Sales Order only, then executed one new full order flow through Awamir Plus and accounting sync.

The phase intentionally did not enable submit for Payment Entry, Sales Invoice, or Work Order.

## Backup

A full site backup with files was taken before changing submit settings.

| Backup Item | Result |
| --- | --- |
| Site | `hrms.localhost` |
| Time | `2026-05-03 14:23:27` |
| Database | `20260503_142325-hrms_localhost-database.sql.gz` |
| Public files | `20260503_142325-hrms_localhost-files.tar` |
| Private files | `20260503_142325-hrms_localhost-private-files.tar` |
| Config | `20260503_142325-hrms_localhost-site_config_backup.json` |

## Submit Flags

The flags were verified after the change:

| Setting | Value |
| --- | ---: |
| `submit_sales_order` | 1 |
| `submit_payment_entry` | 0 |
| `submit_sales_invoice` | 0 |
| `submit_work_order` | 0 |

## Test Order

| Field | Value |
| --- | --- |
| Awamir order | `ORD-2026-00048` |
| Fulfillment | Pickup |
| Branch | فرع المروج |
| Product | `AWAMIR-KUNAFA` / كنافة |
| Quantity | 2 |
| Total | 190 SAR |
| Deposit | 50 SAR by Card |
| Remaining payment | 140 SAR by Transfer |
| Final operational status | Delivered |
| Cash closure | `CASH-2026-00009` |
| Cash closure status | Closed |

Note: `CASH-2026-00009` already contained one previous returned pilot payment of 15 SAR under `Other`. The phase 1 order payments were still isolated in accounting by posting payments for `ORD-2026-00048` only.

## Operational Flow

The new order passed through:

1. Branch employee created the order and submitted it for approval.
2. Branch supervisor approved it.
3. Distribution assigned it to the default production department.
4. Production moved it through `In Production`, `Production Completed`, and `Ready For Pickup`.
5. Branch employee collected the remaining amount.
6. Branch employee delivered the order.
7. Cashier accepted and closed the daily cash closure.
8. Accountant created the ERPNext accounting documents for the order.

## Accounting Results

| Document | Result | ERPNext DocStatus |
| --- | --- | ---: |
| Sales Order | `SAL-ORD-2026-00027` | 1 |
| Payment Entry | `ACC-PAY-2026-00053` | 0 |
| Payment Entry | `ACC-PAY-2026-00054` | 0 |
| Sales Invoice | `ACC-SINV-2026-00027` | 0 |

The Sales Order was submitted successfully in ERPNext. Payment Entries and Sales Invoice remained Draft as required.

## Idempotency

`awamir_plus.api.accounting.create_sales_order_for_order` was called twice for `ORD-2026-00048`.

| Check | Result |
| --- | --- |
| First call created Sales Order | `SAL-ORD-2026-00027` |
| Second call returned the same Sales Order | Yes |
| Duplicate Sales Order created | No |

## Sync State

| Field | Result |
| --- | --- |
| `erp_sync_status` | `Partially Synced` |
| `erp_sync_error` | None |
| Order payment statuses | `Posted To ERPNext` |

The order remains `Partially Synced` because this phase did not submit or allocate the Sales Invoice. This is expected for phase 1.

## Errors

No ERPNext validation errors appeared during this phase.

No ERPNext Core changes were made.

## Verification

Local checks after the controlled test:

| Check | Result |
| --- | --- |
| Backend compile | Passed |
| Flutter analyze | Passed |
| Flutter tests | Passed |

`flutter test` completed with 112 passing tests.

## Next Gate

Do not proceed to phase 2 automatically.

Recommended next phase after approval: enable `submit_payment_entry` only, with a fresh backup and a new controlled order.

---

# Phase 2 - Payment Entry Submit

Date: 2026-05-03  
Phase: 2 - `submit_payment_entry` enabled after phase 1 approval

## Scope

This phase enabled submit for Payment Entry while keeping Sales Invoice and Work Order submit disabled.

The objective was to confirm that accepted daily cash closure payments can become submitted ERPNext Payment Entries without submitting Sales Invoice or Work Order.

## Backup

A full site backup with files was taken before changing the phase 2 submit settings.

| Backup Item | Result |
| --- | --- |
| Site | `hrms.localhost` |
| Time | `2026-05-03 14:53:21` |
| Database | `20260503_145319-hrms_localhost-database.sql.gz` |
| Public files | `20260503_145319-hrms_localhost-files.tar` |
| Private files | `20260503_145319-hrms_localhost-private-files.tar` |
| Config | `20260503_145319-hrms_localhost-site_config_backup.json` |

## Submit Flags

The flags were verified after the change:

| Setting | Value |
| --- | ---: |
| `submit_sales_order` | 1 |
| `submit_payment_entry` | 1 |
| `submit_sales_invoice` | 0 |
| `submit_work_order` | 0 |

## Test Order

| Field | Value |
| --- | --- |
| Awamir order | `ORD-2026-00049` |
| Fulfillment | Pickup |
| Branch | فرع المروج |
| Product | `AWAMIR-MIX-PASTRIES` / فطائر مشكلة |
| Production department | المطبخ |
| Quantity | 2 |
| Total | 280 SAR |
| Deposit | 80 SAR by Card |
| Remaining payment | 200 SAR by Cash |
| Final operational status | Delivered |
| Cash closure | `CASH-2026-00010` |
| Cash closure status | Closed |

## Operational Flow

The order passed through the complete operating path:

1. Branch employee created the order and submitted it for approval.
2. Branch supervisor approved it.
3. Distribution assigned it to the default production department.
4. Production moved it through `In Production`, `Production Completed`, and `Ready For Pickup`.
5. Branch employee collected the remaining amount.
6. Branch employee delivered the order.
7. Cashier accepted and closed the daily cash closure.
8. Accountant created Sales Order, posted Payment Entries, created a Draft Sales Invoice, and ran Awamir allocation logic.

## Accounting Results

| Document | Result | ERPNext DocStatus |
| --- | --- | ---: |
| Sales Order | `SAL-ORD-2026-00028` | 1 |
| Payment Entry | `ACC-PAY-2026-00055` | 1 |
| Payment Entry | `ACC-PAY-2026-00056` | 1 |
| Sales Invoice | `ACC-SINV-2026-00028` | 0 |
| Work Order | Not created | n/a |

Sales Order and Payment Entries were submitted successfully. Sales Invoice remained Draft as required for phase 2.

## Idempotency

| Check | Result |
| --- | --- |
| Re-running `create_sales_order_for_order` returned the same Sales Order | Yes |
| Duplicate Sales Order created | No |
| Re-running `create_payment_entry_for_payment` for the 80 SAR payment returned `ACC-PAY-2026-00055` | Yes |
| Re-running `create_payment_entry_for_payment` for the 200 SAR payment returned `ACC-PAY-2026-00056` | Yes |
| Duplicate Payment Entry created | No |

## Allocation And Ledger Notes

Awamir allocation logic returned two allocation rows and marked the order accounting flow as synced.

Because `submit_sales_invoice = 0`, the Sales Invoice remained Draft. The current safe behavior is:

- Payment Entries can be submitted and linked against the submitted Sales Order.
- Awamir can record the intended allocation internally.
- Ledger-wise allocation against the Sales Invoice is deferred until Sales Invoice submit is activated in a later controlled phase.

ERPNext GL Entries were created for the submitted Payment Entries:

| Voucher | GL Entries |
| --- | ---: |
| `ACC-PAY-2026-00055` | 2 |
| `ACC-PAY-2026-00056` | 2 |

Total GL Entries observed for phase 2 Payment Entries: 4.

## Sync State

| Field | Result |
| --- | --- |
| `erp_sync_status` | `Synced` |
| `erp_sync_error` | None |
| Final Awamir payment statuses | `Linked To Invoice` |

## Errors And Controls

No ERPNext validation errors appeared for:

- Mode of Payment
- Mode of Payment account
- Company defaults
- Default receivable account
- Submitted Sales Order requirement
- Repeated Payment Entry posting

One operational permission control was observed during the test: the first production update attempt used a sweets production user for a kitchen order and was correctly blocked by production department scope. The order was then continued with the correct kitchen production user.

No ERPNext Core changes were made.

## Verification

Local checks after the controlled test:

| Check | Result |
| --- | --- |
| Backend compile | Passed |
| Flutter analyze | Passed |
| Flutter tests | Passed |

`flutter test` completed with 112 passing tests.

## Next Gate

Do not proceed to phase 3 automatically.

Recommended next phase after approval: enable `submit_sales_invoice` only, with a fresh backup and a new controlled order.
