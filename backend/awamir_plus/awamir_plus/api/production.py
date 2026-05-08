import frappe
from frappe import _

from awamir_plus.constants import (
    DEPARTMENT_WORK_ORDER_STATUS_ACCEPTED,
    DEPARTMENT_WORK_ORDER_STATUS_DELAYED,
    DEPARTMENT_WORK_ORDER_STATUS_IN_PRODUCTION,
    DEPARTMENT_WORK_ORDER_STATUS_PENDING,
    DEPARTMENT_WORK_ORDER_STATUS_READY,
    DEPARTMENT_WORK_ORDER_STATUS_REJECTED,
    ORDER_STATUS_IN_PRODUCTION,
    ORDER_STATUS_PRODUCTION_COMPLETED,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_PICKUP,
    ORDER_STATUS_SENT_TO_PRODUCTION,
    PERMISSION_PRODUCTION_MARK_READY,
    PERMISSION_WORK_ORDER_UPDATE_STATUS,
    PERMISSION_WORK_ORDER_VIEW_DEPARTMENT,
)
from awamir_plus.permissions import get_user_production_department, is_awamir_admin, require_any_permissions, require_permissions
from awamir_plus.services.fulfillment import (
    get_department_work_orders as get_department_work_orders_for_order,
    update_department_work_order_status,
)
from awamir_plus.utils import create_notification, get_pagination, get_users_with_role, make_audit_log, make_status_log, run_idempotent


@frappe.whitelist()
def get_production_orders(status=None, limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_WORK_ORDER_VIEW_DEPARTMENT)
    allowed_statuses = [
        ORDER_STATUS_SENT_TO_PRODUCTION,
        ORDER_STATUS_IN_PRODUCTION,
        ORDER_STATUS_PRODUCTION_COMPLETED,
        ORDER_STATUS_READY_FOR_PICKUP,
        ORDER_STATUS_READY_FOR_DELIVERY,
    ]
    filters = {
        "status": status if status in allowed_statuses else ["in", allowed_statuses]
    }
    if not is_awamir_admin():
        department = get_user_production_department()
        filters["production_department"] = department
    orders = frappe.get_all("Awamir Order Request", filters=filters, pluck="name", order_by="required_date asc")
    if not is_awamir_admin() and department:
        work_order_orders = frappe.get_all(
            "Awamir Department Work Order",
            filters={
                "department": department,
                "status": ["in", [
                    DEPARTMENT_WORK_ORDER_STATUS_PENDING,
                    DEPARTMENT_WORK_ORDER_STATUS_ACCEPTED,
                    DEPARTMENT_WORK_ORDER_STATUS_IN_PRODUCTION,
                    DEPARTMENT_WORK_ORDER_STATUS_DELAYED,
                    DEPARTMENT_WORK_ORDER_STATUS_READY,
                ]],
            },
            pluck="order",
        )
        orders = [
            order
            for order in sorted(set(orders).union(work_order_orders))
            if frappe.db.get_value("Awamir Order Request", order, "status") in allowed_statuses
        ]
    pagination = get_pagination(limit_start, limit_page_length)
    orders = orders[pagination["start"]: pagination["start"] + pagination["page_length"]]
    from awamir_plus.api.orders import get_order_detail

    return [get_order_detail(order) for order in orders]


@frappe.whitelist()
def update_production_status(order=None, new_status=None, status=None, notes=None, order_id=None, idempotency_key=None):
    require_any_permissions([PERMISSION_WORK_ORDER_UPDATE_STATUS, PERMISSION_PRODUCTION_MARK_READY])
    order = order or order_id
    new_status = new_status or status
    if not order:
        frappe.throw(_("Order is required."))
    if not new_status:
        frappe.throw(_("Production status is required."))
    payload = {"order": order, "new_status": new_status, "notes": notes}

    def _execute():
        allowed = {
            ORDER_STATUS_SENT_TO_PRODUCTION: [ORDER_STATUS_IN_PRODUCTION],
            ORDER_STATUS_IN_PRODUCTION: [ORDER_STATUS_PRODUCTION_COMPLETED],
            ORDER_STATUS_PRODUCTION_COMPLETED: [ORDER_STATUS_READY_FOR_PICKUP, ORDER_STATUS_READY_FOR_DELIVERY],
        }
        doc = frappe.get_doc("Awamir Order Request", order)
        user_department = get_user_production_department()
        if not is_awamir_admin() and not _can_update_order_for_department(doc, user_department):
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
        _update_related_work_orders(doc, new_status, notes)
        make_status_log(doc.name, old_status, new_status, notes or _status_log_note(new_status))
        _create_production_notifications(doc, new_status)
        response = _production_response(doc, _("Production status updated successfully."))
        make_audit_log("production_status_updated", reference_doctype="Awamir Order Request", reference_name=doc.name, method="update_production_status", payload={"new_status": new_status, "notes": notes}, response=response)
        return response

    return run_idempotent("update_production_status", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Order Request", reference_name=order)


@frappe.whitelist()
def get_department_work_orders(order=None):
    require_permissions(PERMISSION_WORK_ORDER_VIEW_DEPARTMENT)
    department = None if is_awamir_admin() else get_user_production_department()
    return get_department_work_orders_for_order(order=order, department=department)


@frappe.whitelist()
def update_work_order_status(work_order=None, status=None, notes=None, delay_reason=None, rejection_reason=None, idempotency_key=None):
    require_any_permissions([PERMISSION_WORK_ORDER_UPDATE_STATUS, PERMISSION_PRODUCTION_MARK_READY])
    if not work_order:
        frappe.throw(_("Work order is required."))
    if not status:
        frappe.throw(_("Work order status is required."))
    payload = {"work_order": work_order, "status": status, "notes": notes or delay_reason or rejection_reason}

    def _execute():
        doc = frappe.get_doc("Awamir Department Work Order", work_order)
        if not is_awamir_admin() and doc.department != get_user_production_department():
            frappe.throw(_("You can only update work orders for your department."), frappe.PermissionError)
        if status == DEPARTMENT_WORK_ORDER_STATUS_REJECTED and not (notes or rejection_reason):
            frappe.throw(_("Rejection reason is required."))
        if status == DEPARTMENT_WORK_ORDER_STATUS_DELAYED and not (notes or delay_reason):
            frappe.throw(_("Delay reason is required."))
        updated = update_department_work_order_status(
            work_order,
            status,
            notes or delay_reason or rejection_reason,
            user=frappe.session.user,
        )
        response = {
            "work_order": updated.as_dict(),
            "order": _order_detail(updated.order),
            "message": _("Work order updated successfully."),
        }
        make_audit_log("department_work_order_updated", reference_doctype="Awamir Department Work Order", reference_name=updated.name, method="update_work_order_status", payload={"status": status, "notes": notes or delay_reason or rejection_reason}, response=response)
        return response

    return run_idempotent("update_work_order_status", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Department Work Order", reference_name=work_order)


def _can_update_order_for_department(doc, department):
    if doc.production_department == department:
        return True
    return bool(
        frappe.db.exists(
            "Awamir Department Work Order",
            {"order": doc.name, "department": department},
        )
    )


def _update_related_work_orders(doc, new_status, notes):
    department = None if is_awamir_admin() else get_user_production_department()
    filters = {"order": doc.name}
    if department:
        filters["department"] = department
    work_orders = frappe.get_all("Awamir Department Work Order", filters=filters, pluck="name")
    if not work_orders:
        return
    if new_status == ORDER_STATUS_IN_PRODUCTION:
        target_status = DEPARTMENT_WORK_ORDER_STATUS_IN_PRODUCTION
    elif new_status in (ORDER_STATUS_READY_FOR_PICKUP, ORDER_STATUS_READY_FOR_DELIVERY):
        target_status = DEPARTMENT_WORK_ORDER_STATUS_READY
    else:
        return
    for work_order in work_orders:
        update_department_work_order_status(work_order, target_status, notes, user=frappe.session.user)


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


def _order_detail(order):
    from awamir_plus.api.orders import get_order_detail

    return get_order_detail(order)
