import frappe
from frappe import _

from awamir_plus.constants import (
    ORDER_STATUS_ASSIGNED_TO_DRIVER,
    ORDER_STATUS_DELIVERED,
    ORDER_STATUS_DELIVERY_FAILED,
    ORDER_STATUS_DRIVER_PICKED_UP,
    ORDER_STATUS_OUT_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_PICKUP,
    PAYMENT_STATUS_RECORDED,
)
from awamir_plus.permissions import get_user_branch, is_awamir_admin, require_branch_scope, require_roles
from awamir_plus.utils import assert_required, create_notification, get_awamir_settings, make_status_log, now, to_float


@frappe.whitelist()
def get_pickup_orders():
    require_roles(["Awamir Branch Employee", "Awamir Branch Supervisor", "Awamir System Admin"])
    filters = {"status": ORDER_STATUS_READY_FOR_PICKUP}
    if not is_awamir_admin():
        filters["pickup_branch"] = get_user_branch()
    return frappe.get_all("Awamir Order Request", filters=filters, fields=["*"], order_by="required_date asc")


@frappe.whitelist()
def mark_pickup_order_delivered(order):
    require_roles(["Awamir Branch Employee", "Awamir Branch Supervisor", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Order Request", order)
    require_branch_scope(doc.pickup_branch)
    if to_float(doc.remaining_amount) > 0 and not (is_awamir_admin() or get_awamir_settings().allow_delivery_without_full_payment):
        frappe.throw(_("Remaining amount must be collected before delivery."))
    old_status = doc.status
    doc.status = ORDER_STATUS_DELIVERED
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, doc.status, _("Delivered to customer from branch."))
    create_notification(doc.created_by_user, _("Order Delivered"), _("Order {0} was delivered.").format(doc.order_number), doc.name, "order_delivered")
    return doc.as_dict()


@frappe.whitelist()
def collect_remaining_payment(order, amount, payment_method="Cash", payment_reference=None, receipt_attachment=None):
    require_roles(["Awamir Branch Employee", "Awamir Driver", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Order Request", order)
    amount = to_float(amount)
    if amount <= 0:
        frappe.throw(_("Payment amount must be greater than zero."))
    payment = frappe.get_doc(
        {
            "doctype": "Awamir Order Payment",
            "order": doc.name,
            "customer": doc.customer,
            "amount": amount,
            "payment_method": payment_method,
            "payment_reference": payment_reference,
            "receipt_attachment": receipt_attachment,
            "received_by_user": frappe.session.user,
            "received_by_role": "driver" if "Awamir Driver" in frappe.get_roles() else "branch_employee",
            "status": PAYMENT_STATUS_RECORDED,
        }
    ).insert(ignore_permissions=True)
    doc.remaining_amount = max(to_float(doc.remaining_amount) - amount, 0)
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, doc.status, doc.status, _("Remaining payment collected: {0}.").format(amount))
    return payment.as_dict()


@frappe.whitelist()
def get_available_drivers():
    require_roles(["Awamir Distribution Manager", "Awamir System Admin"])
    drivers = []
    for row in frappe.get_all("Has Role", filters={"role": "Awamir Driver"}, fields=["parent"]):
        user = frappe.get_doc("User", row.parent)
        count = frappe.db.count(
            "Awamir Delivery Assignment",
            filters={"driver": row.parent, "status": ["in", [ORDER_STATUS_ASSIGNED_TO_DRIVER, ORDER_STATUS_DRIVER_PICKED_UP, ORDER_STATUS_OUT_FOR_DELIVERY]]},
        )
        drivers.append({"user": user.name, "full_name": user.full_name, "email": user.email, "assigned_orders_count": count})
    return drivers


@frappe.whitelist()
def assign_driver_to_order(order, driver):
    require_roles(["Awamir Distribution Manager", "Awamir System Admin"])
    assert_required(driver, "Driver is required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    if doc.status != ORDER_STATUS_READY_FOR_DELIVERY:
        frappe.throw(_("Only Ready For Delivery orders can be assigned to a driver."))
    existing_assignment = frappe.db.get_value(
        "Awamir Delivery Assignment",
        {"order": doc.name, "driver": driver, "status": ["!=", ORDER_STATUS_DELIVERY_FAILED]},
        "name",
    )
    if existing_assignment:
        return frappe.get_doc("Awamir Delivery Assignment", existing_assignment).as_dict()
    old_status = doc.status
    doc.status = ORDER_STATUS_ASSIGNED_TO_DRIVER
    doc.assigned_driver = driver
    doc.save(ignore_permissions=True)
    assignment = frappe.get_doc(
        {
            "doctype": "Awamir Delivery Assignment",
            "order": doc.name,
            "driver": driver,
            "assigned_by": frappe.session.user,
            "assigned_at": now(),
            "status": ORDER_STATUS_ASSIGNED_TO_DRIVER,
        }
    ).insert(ignore_permissions=True)
    make_status_log(doc.name, old_status, doc.status, _("Assigned to driver {0}.").format(driver))
    create_notification(driver, _("New Delivery Order"), _("Order {0} assigned to you.").format(doc.order_number), doc.name, "driver_assigned")
    create_notification(doc.created_by_user, _("Driver Assigned"), _("Order {0} assigned to driver {1}.").format(doc.order_number, driver), doc.name, "driver_assigned")
    return assignment.as_dict()


@frappe.whitelist()
def get_driver_orders():
    require_roles(["Awamir Driver", "Awamir System Admin"])
    filters = {"status": ["in", [ORDER_STATUS_ASSIGNED_TO_DRIVER, ORDER_STATUS_DRIVER_PICKED_UP, ORDER_STATUS_OUT_FOR_DELIVERY, ORDER_STATUS_DELIVERY_FAILED]]}
    if not is_awamir_admin():
        filters["assigned_driver"] = frappe.session.user
    return frappe.get_all("Awamir Order Request", filters=filters, fields=["*"], order_by="required_date asc")


@frappe.whitelist()
def update_delivery_status(order, new_status, proof_image=None, driver_notes=None):
    require_roles(["Awamir Driver", "Awamir System Admin"])
    transitions = {
        ORDER_STATUS_ASSIGNED_TO_DRIVER: [ORDER_STATUS_DRIVER_PICKED_UP],
        ORDER_STATUS_DRIVER_PICKED_UP: [ORDER_STATUS_OUT_FOR_DELIVERY],
        ORDER_STATUS_OUT_FOR_DELIVERY: [ORDER_STATUS_DELIVERED],
    }
    doc = frappe.get_doc("Awamir Order Request", order)
    if not is_awamir_admin() and doc.assigned_driver != frappe.session.user:
        frappe.throw(_("You can only update your assigned delivery orders."), frappe.PermissionError)
    if new_status not in transitions.get(doc.status, []):
        frappe.throw(_("Invalid delivery status transition."))
    if new_status == ORDER_STATUS_DELIVERED and to_float(doc.remaining_amount) > 0 and not get_awamir_settings().allow_delivery_without_full_payment:
        frappe.throw(_("Remaining amount must be collected before delivery."))
    old_status = doc.status
    doc.status = new_status
    doc.save(ignore_permissions=True)
    _update_assignment(doc, new_status, proof_image=proof_image, driver_notes=driver_notes)
    make_status_log(doc.name, old_status, new_status, driver_notes)
    create_notification(doc.created_by_user, _("Delivery Updated"), _("Order {0} status changed to {1}.").format(doc.order_number, new_status), doc.name, "delivery_status")
    return doc.as_dict()


@frappe.whitelist()
def mark_delivery_failed(order, reason):
    require_roles(["Awamir Driver", "Awamir System Admin"])
    assert_required(reason, "Failure reason is required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    if not is_awamir_admin() and doc.assigned_driver != frappe.session.user:
        frappe.throw(_("You can only update your assigned delivery orders."), frappe.PermissionError)
    old_status = doc.status
    doc.status = ORDER_STATUS_DELIVERY_FAILED
    doc.save(ignore_permissions=True)
    _update_assignment(doc, ORDER_STATUS_DELIVERY_FAILED, failure_reason=reason)
    make_status_log(doc.name, old_status, doc.status, reason)
    create_notification(doc.created_by_user, _("Delivery Failed"), _("Delivery failed for order {0}: {1}").format(doc.order_number, reason), doc.name, "delivery_failed")
    return doc.as_dict()


@frappe.whitelist()
def collect_delivery_payment(order, amount, payment_method="Cash", payment_reference=None, receipt_attachment=None):
    require_roles(["Awamir Driver", "Awamir System Admin"])
    return collect_remaining_payment(order, amount, payment_method, payment_reference, receipt_attachment)


def _update_assignment(order_doc, status, proof_image=None, driver_notes=None, failure_reason=None):
    assignment_name = frappe.db.get_value("Awamir Delivery Assignment", {"order": order_doc.name, "driver": order_doc.assigned_driver}, "name")
    if not assignment_name:
        return
    assignment = frappe.get_doc("Awamir Delivery Assignment", assignment_name)
    assignment.status = status
    if status == ORDER_STATUS_DRIVER_PICKED_UP:
        assignment.picked_up_at = now()
    elif status == ORDER_STATUS_OUT_FOR_DELIVERY:
        assignment.out_for_delivery_at = now()
    elif status == ORDER_STATUS_DELIVERED:
        assignment.delivered_at = now()
        assignment.proof_image = proof_image
    elif status == ORDER_STATUS_DELIVERY_FAILED:
        assignment.failed_at = now()
        assignment.failure_reason = failure_reason
    if driver_notes:
        assignment.driver_notes = driver_notes
    assignment.save(ignore_permissions=True)
