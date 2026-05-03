# Work Order Readiness

Date: 2026-05-03

This readiness pass prepared one Awamir Plus product for a safe Work Order test without enabling Work Order submit.

## Scope

- ERPNext core was not changed.
- `submit_work_order` stayed disabled.
- Only one Awamir product was prepared for BOM testing.
- Work Order creation was tested as Draft only.
- The test confirmed that orders are not blocked permanently when Work Order creation fails because the product has no BOM.

## Settings

| Setting | Value |
| --- | --- |
| `submit_sales_order` | `1` |
| `submit_payment_entry` | `1` |
| `submit_sales_invoice` | `1` |
| `submit_work_order` | `0` |
| Default company | `test awamir` |
| Default price list | `Standard Selling` |
| Default warehouse | `البضائع في العبور - TA` |

## Backup

A site backup with files was taken before the Work Order readiness changes.

| Backup time | Result |
| --- | --- |
| 2026-05-03 15:31 | Completed successfully |

## Product And BOM

| Field | Value |
| --- | --- |
| Product | `AWAMIR-SPECIAL-DESSERT` |
| Product name | `طبق حلى خاص` |
| Item group | `طلبات خاصة` |
| Production department | `قسم الطلبات الخاصة` |
| Work Order required by mapping | `1` |

The selected product had no previous Sales Order Item, Sales Invoice Item, or Awamir Order Request Item transactions before this readiness test, so it was the safest existing Awamir product to prepare.

The product was enabled as a stock/manufacturing item for this single readiness scenario. Two demo raw materials were added:

| Raw item | Name |
| --- | --- |
| `AWAMIR-RAW-WO-SUGAR` | `سكر تجريبي لمنتج Work Order` |
| `AWAMIR-RAW-WO-CREAM` | `كريمة تجريبية لمنتج Work Order` |

BOM created and submitted so ERPNext can use it for draft Work Order creation:

| Field | Value |
| --- | --- |
| BOM | `BOM-AWAMIR-SPECIAL-DESSERT-001` |
| BOM item | `AWAMIR-SPECIAL-DESSERT` |
| Active | `1` |
| Default | `1` |
| BOM docstatus | `1` |

## Test Order

| Field | Value |
| --- | --- |
| Awamir order | `ORD-2026-00052` |
| Customer | `عميل جاهزية أمر العمل` |
| Product | `AWAMIR-SPECIAL-DESSERT` |
| Delivery type | `Pickup` |
| Final operational status | `Ready For Pickup` |
| ERP sync status | `Partially Synced` |
| ERP sync error | empty |

Flow executed:

1. Created order and sent it for supervisor approval.
2. Approved the order to `Sent To Distribution`.
3. Assigned it to `قسم الطلبات الخاصة`, moving it to `Sent To Production`.
4. Created submitted Sales Order.
5. Tested Work Order creation before BOM existed.
6. Created and submitted the product BOM.
7. Created Work Order as Draft.
8. Re-ran Work Order creation to verify idempotency.
9. Updated production status through `In Production`, `Production Completed`, and `Ready For Pickup`.

## Sales Order

| Field | Value |
| --- | --- |
| Sales Order | `SAL-ORD-2026-00030` |
| docstatus | `1` |

## No-BOM Failure Test

Before creating the BOM, `create_work_order_for_order` returned the expected Awamir error:

```text
لا يمكن إنشاء Work Order لأن المنتج لا يحتوي BOM
```

This set the order sync error temporarily. After the BOM was created and Work Order creation succeeded, the order sync error was cleared.

## Work Order Draft Test

| Field | Value |
| --- | --- |
| Work Order | `MFG-WO-2026-00001` |
| Production item | `AWAMIR-SPECIAL-DESSERT` |
| BOM | `BOM-AWAMIR-SPECIAL-DESSERT-001` |
| Sales Order | `SAL-ORD-2026-00030` |
| Quantity | `1` |
| docstatus | `0` |
| Status | `Draft` |

Because `submit_work_order = 0`, the Work Order stayed Draft as intended.

## Idempotency

Re-running `create_work_order_for_order` for `ORD-2026-00052` returned the same Work Order:

```text
MFG-WO-2026-00001
```

Only one Work Order exists for the test Sales Order/product pair.

## Notes And Constraints

- Work Order submit remains disabled.
- Only `AWAMIR-SPECIAL-DESSERT` was prepared with a BOM.
- Other products without BOM continue to return the clear no-BOM error.
- Full Work Order submit should not be activated until more real BOMs, warehouses, and manufacturing settings are reviewed.
