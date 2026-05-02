# Deployment

Awamir Plus is split into two deployable parts:

1. Flutter mobile app in `mobile/awamir_plus_mobile`.
2. Frappe backend app in `backend/awamir_plus`.

Backend deployment flow:

```bash
bench get-app /path/to/awamir_plus
bench --site your-site.local install-app awamir_plus
bench --site your-site.local migrate
```

Mobile deployment flow:

```bash
cd mobile/awamir_plus_mobile
flutter analyze
flutter test
flutter build apk
```

Production deployments must configure environment-specific API URLs, ERPNext credentials/session handling, and app signing outside the repository.

