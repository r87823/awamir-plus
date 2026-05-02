import json
import re
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


def assert_required(value, message):
    if value in (None, "", []):
        frappe.throw(_(message))


def parse_datetime(date_value, time_value):
    if not date_value or not time_value:
        return None
    return datetime.fromisoformat(f"{date_value} {time_value}")

