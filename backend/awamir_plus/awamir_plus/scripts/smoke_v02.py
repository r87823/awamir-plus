import frappe
from frappe import _

from awamir_plus.constants import (
    ORDER_FLOW_STATUSES,
    ROLE_BRANCH_EMPLOYEE,
    ROLE_DISTRIBUTION_MANAGER,
    ROLE_SYSTEM_ADMIN,
)


REQUIRED_DOCTYPES = [
    "Awamir Audit Log",
    "Awamir Idempotency Key",
    "Awamir Department Work Order",
    "Awamir Department Work Order Item",
    "Awamir Delivery Batch",
    "Awamir Delivery Batch Order",
]

ORDER_SPLIT_STATUS_FIELDS = [
    "order_status",
    "production_status",
    "delivery_status",
    "payment_status",
    "accounting_status",
]

REQUIRED_SETTINGS_FLAGS = [
    "submit_sales_order",
    "submit_payment_entry",
    "submit_sales_invoice",
    "submit_work_order",
]


def run():
    """Read-only v0.2 smoke check for bench execute."""
    results = {
        "ok": True,
        "missing_doctypes": [],
        "missing_order_fields": [],
        "missing_roles": [],
        "settings": {},
        "warnings": [],
    }

    _check_doctypes(results)
    _check_order_fields(results)
    _check_roles(results)
    _check_settings(results)

    results["ok"] = not (
        results["missing_doctypes"]
        or results["missing_order_fields"]
        or results["missing_roles"]
    )
    if not results["ok"]:
        frappe.throw(_("Awamir Plus v0.2 smoke check failed. See returned details."))
    return results


def _check_doctypes(results):
    for doctype in REQUIRED_DOCTYPES:
        if not frappe.db.exists("DocType", doctype):
            results["missing_doctypes"].append(doctype)


def _check_order_fields(results):
    meta = frappe.get_meta("Awamir Order Request")
    fieldnames = {field.fieldname for field in meta.fields}
    for fieldname in ORDER_SPLIT_STATUS_FIELDS:
        if fieldname not in fieldnames:
            results["missing_order_fields"].append(fieldname)

    order_status = meta.get_field("order_status")
    options = (order_status.options or "").splitlines() if order_status else []
    if order_status and options != ORDER_FLOW_STATUSES:
        results["warnings"].append("order_status options differ from constants.ORDER_FLOW_STATUSES")


def _check_roles(results):
    for role in [ROLE_BRANCH_EMPLOYEE, ROLE_DISTRIBUTION_MANAGER, ROLE_SYSTEM_ADMIN]:
        if not frappe.db.exists("Role", role):
            results["missing_roles"].append(role)


def _check_settings(results):
    if not frappe.db.exists("DocType", "Awamir App Settings"):
        results["warnings"].append("Awamir App Settings DocType is missing")
        return
    if not frappe.db.exists("Awamir App Settings", "Awamir App Settings"):
        results["warnings"].append("Awamir App Settings is not configured")
        return
    settings = frappe.get_single("Awamir App Settings")
    for flag in REQUIRED_SETTINGS_FLAGS:
        results["settings"][flag] = bool(getattr(settings, flag, 0))
