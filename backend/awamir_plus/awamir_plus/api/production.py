import frappe
from frappe import _

from awamir_plus.constants import (
    ORDER_STATUS_IN_PRODUCTION,
    ORDER_STATUS_PRODUCTION_COMPLETED,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_PICKUP,
    ORDER_STATUS_SENT_TO_PRODUCTION,
)
from awamir_plus.permissions import get_user_production_department, is_awamir_admin, require_roles
from awamir_plus.utils import create_notification, make_status_log


@frappe.whitelist()
def get_production_orders():
    require_roles(["Awamir Production User", "Awamir System Admin"])
    filters = {"status": ["in", [ORDER_STATUS_SENT_TO_PRODUCTION, ORDER_STATUS_IN_PRODUCTION, ORDER_STATUS_PRODUCTION_COMPLETED]]}
    if not is_awamir_admin():
        filters["production_department"] = get_user_production_department()
    return frappe.get_all("Awamir Order Request", filters=filters, fields=["*"], order_by="required_date asc")


@frappe.whitelist()
def update_production_status(order, new_status, notes=None):
    require_roles(["Awamir Production User", "Awamir System Admin"])
    allowed = {
        ORDER_STATUS_SENT_TO_PRODUCTION: [ORDER_STATUS_IN_PRODUCTION],
        ORDER_STATUS_IN_PRODUCTION: [ORDER_STATUS_PRODUCTION_COMPLETED],
        ORDER_STATUS_PRODUCTION_COMPLETED: [ORDER_STATUS_READY_FOR_PICKUP, ORDER_STATUS_READY_FOR_DELIVERY],
    }
    doc = frappe.get_doc("Awamir Order Request", order)
    if not is_awamir_admin() and doc.production_department != get_user_production_department():
        frappe.throw(_("You can only update orders assigned to your production department."), frappe.PermissionError)
    if new_status not in allowed.get(doc.status, []):
        frappe.throw(_("Invalid production status transition."))
    if new_status == ORDER_STATUS_READY_FOR_PICKUP and doc.delivery_type != "Pickup":
        frappe.throw(_("Delivery orders must become Ready For Delivery."))
    if new_status == ORDER_STATUS_READY_FOR_DELIVERY and doc.delivery_type != "Delivery":
        frappe.throw(_("Pickup orders must become Ready For Pickup."))
    old_status = doc.status
    doc.status = new_status
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, new_status, notes)
    create_notification(doc.created_by_user, _("Production Updated"), _("Order {0} status changed to {1}.").format(doc.order_number, new_status), doc.name, "production_status")
    return doc.as_dict()

