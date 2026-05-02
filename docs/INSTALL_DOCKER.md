# Docker Installation

This document is a placeholder for running Awamir Plus with Docker.

Recommended future setup:

1. ERPNext/Frappe bench services.
2. MariaDB.
3. Redis cache, queue, and socketio.
4. Flutter build pipeline for Android/iOS/web artifacts.

The custom Frappe app is located at:

```text
backend/awamir_plus
```

Inside a bench environment, install it with:

```bash
bench get-app /path/to/awamir_plus
bench --site your-site.local install-app awamir_plus
bench --site your-site.local migrate
```

