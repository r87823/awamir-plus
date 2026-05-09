import frappe
from frappe import _

from awamir_plus.constants import EXCEPTION_REASON_CATEGORIES, EXCEPTION_REASONS
from awamir_plus.permissions import require_login


@frappe.whitelist()
def get_exception_reasons(category=None):
    require_login()
    normalized_category = (category or "").strip()
    if normalized_category and normalized_category not in EXCEPTION_REASON_CATEGORIES:
        frappe.throw(_("Unknown exception reason category."))

    categories = [normalized_category] if normalized_category else EXCEPTION_REASON_CATEGORIES
    reasons = []
    for reason_category in categories:
        for reason in EXCEPTION_REASONS.get(reason_category, []):
            row = dict(reason)
            row["category"] = reason_category
            reasons.append(row)
    return reasons
