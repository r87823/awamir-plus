# Device Pilot Runbook

Date: 2026-05-08

This runbook is for the next real-device pilot of Awamir Plus after the submitted accounting validation.

## Current Safe Settings

Keep these settings during the device pilot:

| Setting | Value |
| --- | ---: |
| `submit_sales_order` | `1` |
| `submit_payment_entry` | `1` |
| `submit_sales_invoice` | `1` |
| `submit_work_order` | `0` |

Do not enable `submit_work_order` during this pilot.

## iOS Build

The iOS release build was verified with:

```bash
cd mobile/awamir_plus_mobile
flutter build ios --release --no-codesign \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc
```

Result:

- Build target: `com.awamir.plus`
- Output: `build/ios/iphoneos/Runner.app`
- Size observed during validation: about `19 MB`
- Code signing was intentionally disabled for the build check.

For a real iPhone install from Xcode:

1. Open `mobile/awamir_plus_mobile/ios/Runner.xcworkspace`.
2. Set the signing Team.
3. Confirm Bundle Identifier is `com.awamir.plus`.
4. Use the same Dart defines in the Flutter run command or Xcode build configuration.
5. Do not add any API key or secret to the app.

## Real iPhone Debug Timeout Workaround

If `flutter run` builds successfully but fails with:

```text
Timed out waiting for CONFIGURATION_BUILD_DIR to update.
Error launching application on rayan 15 pro.
```

the app build is usually valid, but Xcode failed to attach the debugger. Use a signed debug build and launch it without the debugger:

```bash
cd mobile/awamir_plus_mobile

flutter build ios --debug \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc

xcrun devicectl device install app \
  --device 00008130-0014643A26F2001C \
  build/ios/iphoneos/Runner.app

xcrun devicectl device process launch \
  --device 00008130-0014643A26F2001C \
  com.awamir.plus
```

Validation result on `rayan 15 pro`:

- Signed debug build completed.
- `objective_c.framework` and `Runner.app` were signed by Team `675UQLLXXG`.
- App installed successfully on the device.
- App launched successfully with bundle id `com.awamir.plus`.

If an install fails with `The executable contains an invalid signature`, rebuild without `--no-codesign`; that error usually means the app bundle was produced by a previous unsigned release build.

## Pilot Users

Use one user per role:

| Role | User |
| --- | --- |
| Branch Employee | `employee@awamir.plus` |
| Branch Supervisor | `supervisor@awamir.plus` |
| Distribution Manager | `distribution@awamir.plus` |
| Production User | `production@awamir.plus` |
| Driver | `driver@awamir.plus` |
| Cashier | `cashier@awamir.plus` |
| Accountant | `accountant@awamir.plus` |
| System Admin | `admin@awamir.plus` or Administrator |

Use the site-configured demo password. Do not write passwords in pilot notes or screenshots.

## Required Device Scenarios

Run these on a real iPhone or the iOS Simulator in real ERPNext mode:

| Scenario | Expected Result |
| --- | --- |
| Branch employee login | Dashboard shows name, role, branch |
| Category loading | Only Awamir categories appear |
| Product loading | Products and prices load from ERPNext |
| Customer phone search | Existing seeded customer auto-fills |
| Pickup order with Cash | Delivered, closure accepted, accounting synced |
| Pickup order with Card | Payment reference saved, closure totals include Card |
| Pickup order with Transfer | Payment reference saved, closure totals include Transfer |
| Delivery order with driver | Assigned, picked up, out for delivery, delivered |
| Delivery failed | Requires reason and ends in `Delivery Failed` |
| Supervisor reject | Requires reason and creates status log |
| Supervisor return for edit | Requires note and creates status log |
| Cashier accept no difference | Payments become accepted/ready for posting |
| Accountant sync | Sales Order, Payment Entries, Sales Invoice submitted and order `Synced` |

## Recently Validated Server Orders

| Scenario | Order | Result |
| --- | --- | --- |
| Full pickup E2E | `ORD-2026-00078` | Delivered and `Synced` |
| Card payment | `ORD-2026-00080` | Delivered and `Synced` |
| Transfer payment | `ORD-2026-00081` | Delivered and `Synced` |
| Rejected order | `ORD-2026-00082` | `Rejected` |
| Returned order | `ORD-2026-00083` | `Returned For Edit` |
| Delivery failed | `ORD-2026-00084` | `Delivery Failed` |
| Delivery fee retest | `ORD-2026-00085` | Delivered and `Synced` |

## Delivery Fee Accounting Check

For any delivery order with a delivery fee:

- Sales Order must include product rows plus `AWAMIR-DELIVERY-FEE`.
- Sales Invoice must include product rows plus `AWAMIR-DELIVERY-FEE`.
- Payment Entries should not exceed the Sales Order outstanding amount.
- Final Awamir order status should become `Synced`.

## Evidence To Capture

For each pilot order, capture:

- Order number.
- User role performing each step.
- Payment method and reference if Card or Transfer.
- Cash closure number.
- Sales Order number.
- Payment Entry numbers.
- Sales Invoice number.
- Final `erp_sync_status`.
- Any UX issue or confusing message.

## Stop Conditions

Pause the pilot and investigate before continuing if any of these happen:

- Payment Entry allocation exceeds Sales Order or Invoice total.
- Order remains `Failed` or `Partially Synced` without a clear reason.
- Cash closure totals do not match payments.
- A user can view orders outside their branch, driver scope, or production department.
- A Work Order is submitted while `submit_work_order = 0`.
