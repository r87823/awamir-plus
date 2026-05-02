# Project Plan

## Completed Foundations

- Native Flutter UI based on the original design reference.
- Repository and service layers with mock mode.
- Authentication, users, roles, and permissions.
- Create order flow.
- Supervisor approvals.
- Distribution and production workflow.
- Delivery, drivers, and pickup workflow.
- Daily cash closures and cashier review.
- Accounting integration preparation.
- Custom Frappe app structure for ERPNext backend.

## Next Phases

1. Install `backend/awamir_plus` inside a real ERPNext bench.
2. Run Frappe migrations and fix site-specific DocType or permission issues.
3. Add integration tests inside Frappe bench.
4. Connect Flutter `ErpnextService` to the real APIs.
5. Add environment configuration for staging and production.
6. Prepare CI checks for Flutter and backend structure.
7. Add deployment automation and secrets management.

