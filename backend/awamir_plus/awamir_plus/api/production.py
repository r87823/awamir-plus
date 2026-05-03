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
from awamir_plus.utils import create_notification, get_users_with_role, make_status_log


@frappe.whitelist()
def get_production_orders():
    require_roles(["Awamir Production User", "Awamir System Admin"])
    filters = {
        "status": [
            "in",
            [
                ORDER_STATUS_SENT_TO_PRODUCTION,
                ORDER_STATUS_IN_PRODUCTION,
                ORDER_STATUS_PRODUCTION_COMPLETED,
                ORDER_STATUS_READY_FOR_PICKUP,
                ORDER_STATUS_READY_FOR_DELIVERY,
            ],
        ]
    }
    if not is_awamir_admin():
        filters["production_department"] = get_user_production_department()
    orders = frappe.get_all("Awamir Order Request", filters=filters, pluck="name", order_by="required_date asc")
    from awamir_plus.api.orders import get_order_detail

    return [get_order_detail(order) for order in orders]


@frappe.whitelist()
def update_production_status(order=None, new_status=None, status=None, notes=None, order_id=None):
    require_roles(["Awamir Production User", "Awamir System Admin"])
    order = order or order_id
    new_status = new_status or status
    if not order:
        frappe.throw(_("Order is required."))
    if not new_status:
        frappe.throw(_("Production status is required."))
    allowed = {
        ORDER_STATUS_SENT_TO_PRODUCTION: [ORDER_STATUS_IN_PRODUCTION],
        ORDER_STATUS_IN_PRODUCTION: [ORDER_STATUS_PRODUCTION_COMPLETED],
        ORDER_STATUS_PRODUCTION_COMPLETED: [ORDER_STATUS_READY_FOR_PICKUP, ORDER_STATUS_READY_FOR_DELIVERY],
    }
    doc = frappe.get_doc("Awamir Order Request", order)
    if not is_awamir_admin() and doc.production_department != get_user_production_department():
        frappe.throw(_("You can only update orders assigned to your production department."), frappe.PermissionError)
    if doc.status == new_status:
        return _production_response(doc, _("Order is already in this production status."))
    if new_status not in allowed.get(doc.status, []):
        frappe.throw(_("Invalid production status transition."))
    if new_status == ORDER_STATUS_READY_FOR_PICKUP and doc.delivery_type != "Pickup":
        frappe.throw(_("Delivery orders must become Ready For Delivery."))
    if new_status == ORDER_STATUS_READY_FOR_DELIVERY and doc.delivery_type != "Delivery":
        frappe.throw(_("Pickup orders must become Ready For Pickup."))
    old_status = doc.status
    doc.status = new_status
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, new_status, notes or _status_log_note(new_status))
    _create_production_notifications(doc, new_status)
    return _production_response(doc, _("Production status updated successfully."))


def _create_production_notifications(doc, new_status):
    if new_status == ORDER_STATUS_IN_PRODUCTION:
        create_notification(
            doc.created_by_user,
            _("Production Started"),
            _("Production started for order {0}.").format(doc.order_number),
            doc.name,
            "production_started",
        )
        return

    if new_status == ORDER_STATUS_PRODUCTION_COMPLETED:
        create_notification(
            doc.created_by_user,
            _("Production Completed"),
            _("Production completed for order {0}.").format(doc.order_number),
            doc.name,
            "production_completed",
        )
        for user in get_users_with_role("Awamir Distribution Manager"):
            create_notification(
                user,
                _("Production Completed"),
                _("Order {0} production is completed.").format(doc.order_number),
                doc.name,
                "production_completed",
            )
        return

    if new_status == ORDER_STATUS_READY_FOR_PICKUP:
        create_notification(
            doc.created_by_user,
            _("Ready For Pickup"),
            _("Order {0} is ready for pickup.").format(doc.order_number),
            doc.name,
            "ready_for_pickup",
        )
        return

    if new_status == ORDER_STATUS_READY_FOR_DELIVERY:
        for user in get_users_with_role("Awamir Distribution Manager"):
            create_notification(
                user,
                _("Ready For Delivery"),
                _("Order {0} is ready for delivery and needs driver assignment.").format(doc.order_number),
                doc.name,
                "ready_for_delivery",
            )


def _status_log_note(new_status):
    if new_status == ORDER_STATUS_IN_PRODUCTION:
        return _("Production started.")
    if new_status == ORDER_STATUS_PRODUCTION_COMPLETED:
        return _("Production completed.")
    if new_status == ORDER_STATUS_READY_FOR_PICKUP:
        return _("Order is ready for pickup.")
    if new_status == ORDER_STATUS_READY_FOR_DELIVERY:
        return _("Order is ready for delivery.")
    return _("Production status updated.")


def _production_response(doc, message):
    from awamir_plus.api.orders import get_order_detail

    return {
        "order_id": doc.name,
        "order_number": doc.order_number,
        "status": doc.status,
        "message": message,
        "order": get_order_detail(doc.name),
    }
