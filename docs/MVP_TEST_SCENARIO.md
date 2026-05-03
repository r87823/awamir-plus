# MVP Test Scenario

This document records the operating scenario used to validate the current MVP.

## Flow

1. Branch employee creates a pickup order.
2. Employee selects customer, items, pickup date/time, and deposit.
3. Employee submits the order for supervisor approval.
4. Branch supervisor approves the order.
5. Distribution manager assigns the production department.
6. Production user moves the order through:
   - `In Production`
   - `Production Completed`
   - `Ready For Pickup` or `Ready For Delivery`
7. Branch employee or driver collects remaining payment.
8. Order is delivered to the customer.
9. Employee or driver submits daily cash closure.
10. Cashier accepts and closes the cash closure.
11. Accountant creates:
    - Sales Order
    - Payment Entry records
    - Sales Invoice
12. Accountant allocates Awamir payments to the invoice inside Awamir.
13. Order accounting sync status becomes `Synced`.

## Expected Final State

- Order status: `Delivered`
- ERP sync status: `Synced`
- Payments: `Linked To Invoice`
- Cash closure: `Closed` or `Has Difference`
- Sales Order: present
- Payment Entries: present
- Sales Invoice: present
- Status logs: complete
- Notifications: complete

## Current MVP Limitations

- ERPNext documents are created as Draft.
- ERPNext ledger posting is not active.
- Payment allocation is tracked in Awamir.
- Work Order requires ERPNext BOM setup.
- During the pilot, Work Order remains disabled. If a user attempts to create it for an item without BOM, the expected message is: `لا يمكن إنشاء Work Order لأن المنتج لا يحتوي BOM`.
- Non-cash payment methods must be tested before rollout: Card and Transfer payments should save `payment_reference` and appear in separated cash closure totals.
- No Payment Gateway.
- Notifications are in-system only.

## Latest Real Test

| Field | Value |
| --- | --- |
| Date | 2026-05-03 |
| Order | `ORD-2026-00008` |
| Order Status | `Delivered` |
| Cash Closure | `CASH-2026-00003` / `Closed` |
| Sales Order | `SAL-ORD-2026-00002` / Draft |
| Payment Entries | `ACC-PAY-2026-00003`, `ACC-PAY-2026-00004` / Draft |
| Sales Invoice | `ACC-SINV-2026-00002` / Draft |
| Payments | `Linked To Invoice` |
| Final Sync | `Synced` |
| Status Logs | 13 |
| Notifications | 16 related notifications |
