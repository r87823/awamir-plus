import frappe

from awamir_plus.permissions import is_awamir_admin, require_login
from awamir_plus.utils import get_pagination


@frappe.whitelist()
def get_notifications(unread_only=False, limit_start=0, limit_page_length=None):
    require_login()
    filters = {} if is_awamir_admin() else {"user": frappe.session.user}
    if unread_only:
        filters["is_read"] = 0
    return frappe.get_all(
        "Awamir Notification",
        filters=filters,
        fields=["*"],
        order_by="created_at desc",
        **get_pagination(limit_start, limit_page_length),
    )


@frappe.whitelist()
def mark_notification_as_read(notification):
    require_login()
    doc = frappe.get_doc("Awamir Notification", notification)
    if not is_awamir_admin() and doc.user != frappe.session.user:
        frappe.throw("You can only update your notifications.", frappe.PermissionError)
    doc.is_read = 1
    doc.save(ignore_permissions=True)
    return doc.as_dict()


@frappe.whitelist()
def mark_all_notifications_as_read():
    require_login()
    filters = {} if is_awamir_admin() else {"user": frappe.session.user}
    for notification in frappe.get_all("Awamir Notification", filters=filters, pluck="name"):
        frappe.db.set_value("Awamir Notification", notification, "is_read", 1)
    return {"updated": True}
