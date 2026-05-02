# Awamir Plus

Awamir Plus is an end-to-end order management platform for branch sales, supervisor approvals, distribution, production, delivery, daily cash closures, and ERPNext accounting integration.

The repository is organized as a monorepo so the mobile app, Frappe backend, design reference, and documentation can evolve together without mixing responsibilities.

## Project Structure

```text
awamir-plus/
  mobile/
    awamir_plus_mobile/
  backend/
    awamir_plus/
  design-reference/
    sales-classic.html
  docs/
    INSTALL_DOCKER.md
    API.md
    DEPLOYMENT.md
    PROJECT_PLAN.md
```

## Components

### mobile/

Contains the Flutter native application:

```text
mobile/awamir_plus_mobile/
```

The app currently runs in mock mode and includes Arabic RTL screens for order creation, approvals, distribution, production, delivery, cash closures, notifications, and accounting preparation.

### backend/

Contains the custom Frappe app:

```text
backend/awamir_plus/
```

This app is designed to be installed into ERPNext as a separate app without modifying ERPNext Core. It contains DocTypes, roles, permissions, and whitelisted APIs that the Flutter app can call later.

### design-reference/

Contains the original HTML design reference:

```text
design-reference/sales-classic.html
```

This file is kept as a visual reference only. The Flutter app uses native widgets, not WebView.

### docs/

Contains project documentation:

- `INSTALL_DOCKER.md`: local Docker setup notes.
- `API.md`: backend API reference.
- `DEPLOYMENT.md`: deployment notes.
- `PROJECT_PLAN.md`: phased roadmap and implementation plan.

## Quick Checks

Flutter:

```bash
cd mobile/awamir_plus_mobile
flutter analyze
flutter test
```

Frappe app structure:

```bash
cd backend/awamir_plus
python3 scripts/verify_structure.py
python3 -m compileall awamir_plus
```

## GitHub

This repository is prepared to be pushed to:

```text
https://github.com/r87823/awamir-plus.git
```

No secrets, environment files, generated Flutter build outputs, or Frappe runtime files should be committed.

