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
| Delivery proof capture | Delivery action accepts proof note/reference and keeps final status valid |
| Production capacity warning | Department work order shows daily capacity and warning when open load exceeds capacity |
| Delivery batch assignment | Ready delivery orders can be batched and assigned to a driver from Distribution |
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
| Full pickup pilot after iPhone launch validation | `ORD-2026-00086` | Delivered, closure closed, accounting synced |
| ERPNext invoice advance allocation retest | `ORD-2026-00091` | Delivered, synced, Sales Invoice outstanding is `0.0` |
| Full delivery pilot with driver closure | `ORD-2026-00092` | Delivered, synced, delivery fee invoiced, Sales Invoice outstanding is `0.0` |

## Latest Pilot Notes

### iOS Simulator smoke - 2026-05-08

This smoke test was run in real ERPNext mode on the local `iPhone 15 ESS` Simulator because the physical `rayan 15 pro` device was not visible to Flutter at the time of testing.

Command:

```bash
cd mobile/awamir_plus_mobile
flutter run -d 1C5D5B33-982F-4CFF-B163-467C1C07B62F \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc
```

Result:

- The app built and launched successfully.
- Flutter reported `Target native_assets required define SdkRoot but it was not provided`; this did not stop the build or launch.
- Existing persisted session restored successfully for an accountant user.
- Logout worked.
- Login worked for `employee@awamir.plus`.
- Branch employee dashboard loaded real ERPNext counts and role navigation.
- New order flow loaded only Awamir categories:
  - الحلويات
  - الضيافة
  - المطبخ
  - طلبات البوفيه
  - طلبات خاصة
- Products loaded from ERPNext for `الحلويات`, including prices.
- Selecting `كنافة` updated the selected count and total.
- Customer search for `0500000001` found the seeded customer and filled `عميل أوامر التجريبي`.

Physical iPhone note:

- `flutter devices` initially did not detect `rayan 15 pro`; Flutter reported that the device must be unlocked, attached by cable, or available wirelessly with Developer Mode enabled.
- After reconnecting/unlocking the device, `rayan 15 pro` appeared as `00008130-0014643A26F2001C`.
- The same real-mode Flutter run completed build, automatic signing, install, launch, and VM Service startup on the physical iPhone:

```bash
flutter run -d 00008130-0014643A26F2001C \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc
```

- The app launched successfully on the physical device.
- UI interaction still needs to be completed manually on the iPhone screen because the current automation tools can inspect the Simulator UI, not the physical device UI.

### iPhone 15 Pro white-screen crash fix - 2026-05-09

Issue:

- On `rayan 15 pro`, the debug build installed but stopped immediately with a white screen and native `EXC_BAD_ACCESS`.
- The crash happened before Flutter rendered the first app screen.

Fix:

- Running once with `--no-enable-impeller` confirmed the crash was renderer-related.
- `ios/Runner/Info.plist` now sets `FLTEnableImpeller` to `false` so iOS builds use the non-Impeller renderer by default.

Validation:

```bash
flutter run -d 00008130-0014643A26F2001C \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc
```

- Build, signing, install, launch, and VM Service startup completed successfully without passing `--no-enable-impeller`.
- `flutter analyze` passed.
- `flutter test` passed.
- Flutter still prints `Target native_assets required define SdkRoot but it was not provided`; this warning did not block launch.

### `ORD-2026-00086`

This order was executed after validating that the iPhone app opens successfully in real ERPNext mode.

Result:

- Order status: `Delivered`
- ERP sync status inside Awamir: `Synced`
- Cash closure: `CASH-2026-00046`
- Cash closure status: `Closed`
- Sales Order: `SAL-ORD-2026-00063`, `docstatus = 1`
- Payment Entries:
  - `ACC-PAY-2026-00092`, `docstatus = 1`, amount `100`
  - `ACC-PAY-2026-00093`, `docstatus = 1`, amount `250`
- Sales Invoice: `ACC-SINV-2026-00036`, `docstatus = 1`
- Work Order: not created, as expected while `submit_work_order = 0`

Operational note:

- The first production update attempt used a production user that was not linked to the assigned production department. The API correctly rejected the update with a permission error. Continuing with the correct production user for `قسم الطلبات الخاصة` completed the flow successfully.

Accounting note:

- Awamir marked the order as `Synced` after linking both payments internally to the invoice.
- ERPNext still showed `ACC-SINV-2026-00036` with `outstanding_amount = 350` because the Payment Entries were already submitted and the current allocation logic records the link inside Awamir instead of modifying submitted ERPNext ledger allocations.
- This was fixed and retested in `ORD-2026-00091` by adding submitted Payment Entries as Sales Invoice advances before invoice submit.

### `ORD-2026-00091`

This order retested the ERPNext invoice advance allocation after updating the accounting service.

Result:

- Order status: `Delivered`
- ERP sync status inside Awamir: `Synced`
- Cash closure: `CASH-2026-00051`
- Cash closure status: `Closed`
- Sales Order: `SAL-ORD-2026-00067`, `docstatus = 1`, grand total `350`
- Payment Entries:
  - `ACC-PAY-2026-00100`, `docstatus = 1`, amount `120`
  - `ACC-PAY-2026-00101`, `docstatus = 1`, amount `230`
- Sales Invoice: `ACC-SINV-2026-00039`, `docstatus = 1`, grand total `350`
- Sales Invoice advances count: `2`
- Sales Invoice outstanding amount: `0.0`
- Allocation statuses returned by Awamir:
  - `linked_in_sales_invoice_advances`
  - `linked_in_sales_invoice_advances`

Accounting fix:

- `create_sales_invoice_for_order` now injects already-posted Awamir Payment Entries into the ERPNext Sales Invoice `advances` table before submit.
- The advance rows include the ERPNext `Payment Entry Reference.reference_row`, which ERPNext requires to submit the invoice without the "advance entry modified after pulling" validation error.
- `allocate_advance_payment_to_invoice` now detects payments already linked through Sales Invoice advances and marks the Awamir payment allocation accordingly without trying to mutate submitted Payment Entries.

### `ORD-2026-00092`

This order retested the full delivery flow after the Sales Invoice advance allocation fix.

Result:

- Order status: `Delivered`
- ERP sync status inside Awamir: `Synced`
- Delivery fee: `25`
- Branch employee closure: `CASH-2026-00052`, `Closed`
- Driver closure: `CASH-2026-00053`, `Closed`
- Sales Order: `SAL-ORD-2026-00068`, `docstatus = 1`, grand total `375`
- Payment Entries:
  - `ACC-PAY-2026-00102`, `docstatus = 1`, amount `100`
  - `ACC-PAY-2026-00103`, `docstatus = 1`, amount `275`
- Sales Invoice: `ACC-SINV-2026-00040`, `docstatus = 1`, grand total `375`
- Sales Invoice advances count: `2`
- Sales Invoice outstanding amount: `0.0`
- Allocation statuses returned by Awamir:
  - `linked_in_sales_invoice_advances`
  - `linked_in_sales_invoice_advances`

Operational note:

- The delivery flow covered assignment to `driver@awamir.plus`, `Driver Picked Up`, `Out For Delivery`, driver collection of the remaining amount, and final `Delivered`.
- The Sales Order and Sales Invoice included the delivery fee, so the ERPNext grand total matched the collected payments.
- `CASH-2026-00052` included branch-side open cash payments at the time of submission. For production pilots, start with clean daily closures or record closure contents explicitly before submitting.

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
- Production department capacity warning state, if any.
- Delivery proof note/reference, if delivery or pickup proof was entered.
- Delivery batch number, if the order was assigned through a batch.
- Any UX issue or confusing message.

## Stop Conditions

Pause the pilot and investigate before continuing if any of these happen:

- Payment Entry allocation exceeds Sales Order or Invoice total.
- Order remains `Failed` or `Partially Synced` without a clear reason.
- Cash closure totals do not match payments.
- A user can view orders outside their branch, driver scope, or production department.
- A Work Order is submitted while `submit_work_order = 0`.
