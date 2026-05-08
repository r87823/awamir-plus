import json
import re
import hashlib
from datetime import datetime

import frappe
from frappe import _


def parse_json(value, default=None):
    if value is None:
        return default
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, str) and value.strip():
        return json.loads(value)
    return default


def now():
    return frappe.utils.now_datetime()


def today():
    return frappe.utils.today()


def to_float(value):
    return frappe.utils.flt(value or 0)


_LOCALIZED_DIGIT_MAP = str.maketrans(
    "٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹",
    "01234567890123456789",
)


def normalize_localized_digits(value):
    if value is None:
        return ""
    return str(value).translate(_LOCALIZED_DIGIT_MAP)


def normalize_phone_input(value):
    normalized = normalize_localized_digits(value).strip()
    return re.sub(r"[\s\-\(\)\u200e\u200f]", "", normalized)


def get_pagination(limit_start=0, limit_page_length=None, limit=None, default_page_length=50, max_page_length=200):
    try:
        start = max(int(limit_start or 0), 0)
    except (TypeError, ValueError):
        start = 0
    requested_length = limit_page_length if limit_page_length not in (None, "") else limit
    try:
        page_length = int(requested_length or default_page_length)
    except (TypeError, ValueError):
        page_length = default_page_length
    return {
        "start": start,
        "page_length": max(1, min(page_length, max_page_length)),
    }


def extract_coordinates_from_google_maps_url(location_url):
    if not location_url:
        return None

    patterns = [
        r"[?&]q=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)",
        r"@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)",
        r"ll=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)",
    ]
    for pattern in patterns:
        match = re.search(pattern, location_url)
        if match:
            return {
                "latitude": float(match.group(1)),
                "longitude": float(match.group(2)),
            }
    return None


def generate_series(prefix):
    return frappe.model.naming.make_autoname(f"{prefix}-.YYYY.-.#####")


def get_awamir_settings():
    if frappe.db.exists("Awamir App Settings", "Awamir App Settings"):
        return frappe.get_single("Awamir App Settings")
    frappe.throw(_("Awamir App Settings is not configured."))


def make_status_log(order, old_status, new_status, notes=None, changed_by=None):
    return frappe.get_doc(
        {
            "doctype": "Awamir Order Status Log",
            "order": order,
            "old_status": old_status,
            "new_status": new_status,
            "changed_by": changed_by or frappe.session.user,
            "changed_at": now(),
            "notes": notes,
        }
    ).insert(ignore_permissions=True)


def make_cash_closure_log(closure, old_status, new_status, notes=None, changed_by=None):
    return frappe.get_doc(
        {
            "doctype": "Awamir Cash Closure Log",
            "closure": closure,
            "old_status": old_status,
            "new_status": new_status,
            "changed_by": changed_by or frappe.session.user,
            "notes": notes,
            "created_at": now(),
        }
    ).insert(ignore_permissions=True)


def create_notification(user, title, message, related_order=None, notification_type="general"):
    if not user:
        return None
    return frappe.get_doc(
        {
            "doctype": "Awamir Notification",
            "user": user,
            "title": title,
            "message": message,
            "related_order": related_order,
            "notification_type": notification_type,
            "is_read": 0,
            "created_at": now(),
        }
    ).insert(ignore_permissions=True)


def get_cashier_users():
    return [row.parent for row in frappe.get_all("Has Role", filters={"role": "Awamir Cashier"}, fields=["parent"])]


def get_users_with_role(role):
    return [row.parent for row in frappe.get_all("Has Role", filters={"role": role}, fields=["parent"])]


def serialize_doc(doc):
    if hasattr(doc, "as_dict"):
        return doc.as_dict()
    return doc


def json_dumps(value):
    return json.dumps(value, ensure_ascii=False, default=str, sort_keys=True)


def request_hash(value):
    return hashlib.sha256(json_dumps(value or {}).encode("utf-8")).hexdigest()


def make_audit_log(
    event_type,
    status="success",
    reference_doctype=None,
    reference_name=None,
    method=None,
    payload=None,
    response=None,
    error=None,
    idempotency_key=None,
    changed_by=None,
):
    if not frappe.db.exists("DocType", "Awamir Audit Log"):
        return None
    return frappe.get_doc(
        {
            "doctype": "Awamir Audit Log",
            "event_type": event_type,
            "status": status,
            "user": changed_by or frappe.session.user,
            "reference_doctype": reference_doctype,
            "reference_name": reference_name,
            "method": method,
            "idempotency_key": idempotency_key,
            "request_hash": request_hash(payload),
            "created_at": now(),
            "payload": json_dumps(payload or {}),
            "response": json_dumps(response or {}),
            "error": error,
        }
    ).insert(ignore_permissions=True)


def get_idempotent_response(key, method=None, payload=None):
    if not key or not frappe.db.exists("DocType", "Awamir Idempotency Key"):
        return None
    name = frappe.db.get_value("Awamir Idempotency Key", {"key": key, "method": method}, "name")
    if not name:
        return None
    doc = frappe.get_doc("Awamir Idempotency Key", name)
    if payload is not None and doc.request_hash and doc.request_hash != request_hash(payload):
        frappe.throw(_("Idempotency key was reused with a different payload."))
    if doc.status == "completed" and doc.response:
        return parse_json(doc.response, {})
    return None


def get_request_idempotency_key(explicit_key=None):
    if explicit_key:
        return explicit_key
    try:
        return (
            frappe.get_request_header("Idempotency-Key")
            or frappe.get_request_header("X-Idempotency-Key")
        )
    except Exception:
        return None


def save_idempotent_response(
    key,
    method,
    payload=None,
    response=None,
    reference_doctype=None,
    reference_name=None,
    error=None,
):
    if not key or not frappe.db.exists("DocType", "Awamir Idempotency Key"):
        return None
    existing = frappe.db.get_value("Awamir Idempotency Key", {"key": key, "method": method}, "name")
    values = {
        "request_hash": request_hash(payload),
        "status": "failed" if error else "completed",
        "reference_doctype": reference_doctype,
        "reference_name": reference_name,
        "response": json_dumps(response or {}),
        "error": error,
    }
    if existing:
        frappe.db.set_value("Awamir Idempotency Key", existing, values)
        return existing
    return frappe.get_doc(
        {
            "doctype": "Awamir Idempotency Key",
            "key": key,
            "method": method,
            "created_at": now(),
            **values,
        }
    ).insert(ignore_permissions=True).name


def run_idempotent(method, payload, executor, idempotency_key=None, reference_doctype=None, reference_name=None):
    key = get_request_idempotency_key(idempotency_key)
    cached = get_idempotent_response(key, method, payload=payload)
    if cached is not None:
        return cached
    try:
        response = executor()
    except Exception as exc:
        save_idempotent_response(
            key,
            method,
            payload=payload,
            reference_doctype=reference_doctype,
            reference_name=reference_name,
            error=str(exc),
        )
        raise
    save_idempotent_response(
        key,
        method,
        payload=payload,
        response=response,
        reference_doctype=reference_doctype,
        reference_name=reference_name,
    )
    return response


def assert_required(value, message):
    if value in (None, "", []):
        frappe.throw(_(message))


def parse_datetime(date_value, time_value):
    if not date_value or not time_value:
        return None
    return datetime.fromisoformat(f"{date_value} {time_value}")
