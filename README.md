# Awamir Plus

Awamir Plus is an Arabic RTL order operations platform for branch sales, supervisor approvals, distribution, production, delivery, daily cash closures, and ERPNext accounting preparation.

The repository is a monorepo. Flutter, Frappe, design references, and docs are kept together while each layer stays isolated.

## Structure

```text
awamir-plus/
  mobile/
    awamir_plus_mobile/      # Flutter native app
  backend/
    awamir_plus/             # Custom Frappe app, no ERPNext Core edits
  design-reference/
    sales-classic.html       # Visual reference only
  docs/
    RELEASE_V0_1.md
    DEVICE_PILOT_RUNBOOK.md
    V0_2_OPERATIONS_WORKFLOW_PROGRESS.md
    V0_2_DEPLOYMENT_CHECKLIST.md
    API_OVERVIEW.md
    MVP_TEST_SCENARIO.md
    PILOT_TEST_REPORT.md
    DEPLOY_DOCKER.md
    INSTALL_DOCKER.md
    API.md
    DEPLOYMENT.md
    PROJECT_PLAN.md
```

## Mobile

Mock mode:

```bash
cd mobile/awamir_plus_mobile
flutter run --dart-define=USE_MOCK_DATA=true
```

Real ERPNext mode:

```bash
cd mobile/awamir_plus_mobile
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc
```

Run checks:

```bash
cd mobile/awamir_plus_mobile
flutter analyze
flutter test
```

## Backend

The backend is a standalone Frappe app installed into ERPNext:

```text
backend/awamir_plus
```

It defines Awamir DocTypes, roles, permissions, services, and whitelisted APIs. It must be deployed as a custom app only; ERPNext Core is not modified.

Run local Python checks:

```bash
python3 -m compileall backend/awamir_plus/awamir_plus
```

## Pilot Release

The current pilot release notes are documented in [Awamir Plus Pilot Release v0.1](docs/RELEASE_V0_1.md).

The real-device pilot checklist is documented in [Device Pilot Runbook](docs/DEVICE_PILOT_RUNBOOK.md).

The expanded operations workflow progress for v0.2 is tracked in [v0.2 Operations Workflow Progress](docs/V0_2_OPERATIONS_WORKFLOW_PROGRESS.md).

Deployment and smoke-test steps for v0.2 are documented in [v0.2 Deployment Checklist](docs/V0_2_DEPLOYMENT_CHECKLIST.md).

## MVP Accounting Notes

Current pilot accounting behavior is controlled through `Awamir App Settings`:

- Sales Order submit is enabled in the pilot environment.
- Payment Entry submit is enabled in the pilot environment.
- Sales Invoice submit is enabled in the pilot environment.
- Work Order submit is not enabled.
- Payment allocation is tracked inside Awamir.
- ERPNext ledger posting happens only for the submitted ERPNext documents enabled by settings.
- Work Order requires valid BOM setup in ERPNext.
- Awamir product categories are filtered using `custom_is_awamir_category` or active Product Department Mapping.
- No external payment gateway is integrated.
- Notifications are in-system only; push notifications are not enabled yet.

Future submit settings exist in `Awamir App Settings` and default to false:

- `submit_sales_order`
- `submit_payment_entry`
- `submit_sales_invoice`
- `submit_work_order`

## Demo Accounts

Mock mode uses usernames like `employee`, `supervisor`, `distribution`, `production`, `driver`, `cashier`, `accountant`, and `admin` with password `123456`.

Real ERPNext demo users are created by the seed script and use the configured demo password for the site.

## Documentation

- [Pilot Release v0.1](docs/RELEASE_V0_1.md)
- [Device Pilot Runbook](docs/DEVICE_PILOT_RUNBOOK.md)
- [v0.2 Operations Workflow Progress](docs/V0_2_OPERATIONS_WORKFLOW_PROGRESS.md)
- [v0.2 Deployment Checklist](docs/V0_2_DEPLOYMENT_CHECKLIST.md)
- [API Overview](docs/API_OVERVIEW.md)
- [MVP Test Scenario](docs/MVP_TEST_SCENARIO.md)
- [Pilot Test Report](docs/PILOT_TEST_REPORT.md)
- [Docker Deployment](docs/DEPLOY_DOCKER.md)
- [Project Plan](docs/PROJECT_PLAN.md)

## Safety

Do not commit secrets, `.env`, `site_config.json`, backups, build output, or generated runtime files. Use `.env.example` for sample configuration only.
