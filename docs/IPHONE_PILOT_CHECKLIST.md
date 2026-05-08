# iPhone Pilot Checklist

Date: 2026-05-09

Use this checklist after installing the release build on the physical iPhone.

## Install

From the repository root:

```bash
DEVICE_ID=00008130-0014643A26F2001C \
bash scripts/install_ios_release_device.sh
```

Expected:

- Only `Awamir Plus Mobile` with bundle id `com.awamir.plus` remains installed.
- The old `Awamir` app with bundle id `com.awamirplus.awamirMobile` is removed.
- A single `Runner.app/Runner` process is running after launch.

## Login Smoke

1. Open `Awamir Plus Mobile`.
2. Log out if an old session is restored.
3. Log in with `employee@awamir.plus`.
4. Confirm the dashboard shows:
   - موظف فرع أوامر
   - موظف فرع
   - فرع المروج

## New Order Smoke

1. Open `طلب جديد`.
2. Confirm only Awamir categories appear:
   - الحلويات
   - الضيافة
   - المطبخ
   - طلبات البوفيه
   - طلبات خاصة
3. Choose `الحلويات`.
4. Confirm products and prices appear.
5. Select `كنافة`.
6. Confirm the total updates to `95 ر.س`.
7. Continue to customer details.
8. Search for phone `0500000001`.
9. Confirm `عميل أوامر التجريبي` fills automatically.

## Controlled Test Order

Create one low-risk test order only after the smoke checks above pass:

1. Product: `كنافة`.
2. Delivery type: Pickup.
3. Deposit method: Cash.
4. Save as Draft first.
5. Confirm the draft appears in `طلباتي`.
6. Send for approval only if the draft data is correct.

Record:

- Order number.
- User account used.
- Product and amount.
- Whether the order was Draft or submitted for approval.
- Any UX issue or crash.

## Stop Conditions

Stop testing and report the exact screen if any of these occur:

- The app closes unexpectedly.
- A white screen appears for more than 10 seconds.
- Login succeeds but dashboard stays empty.
- Categories include non-Awamir ERPNext groups.
- Product prices are missing.
- Customer search does not fill seeded customers.
