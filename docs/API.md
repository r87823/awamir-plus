# API Reference

The backend app exposes whitelisted Frappe APIs under:

```text
awamir_plus.api
```

Main modules:

- `auth.py`
- `products.py`
- `customers.py`
- `orders.py`
- `approvals.py`
- `distribution.py`
- `production.py`
- `delivery.py`
- `cash_closure.py`
- `accounting.py`
- `notifications.py`

Example:

```http
GET /api/method/awamir_plus.api.auth.get_current_user
```

Flutter integration should call these endpoints from `ErpnextService` after disabling mock mode.

