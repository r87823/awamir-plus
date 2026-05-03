import frappe
from frappe import _

from awamir_plus.constants import (
    CLOSURE_STATUS_OPEN,
    CLOSURE_STATUS_RETURNED,
    ORDER_STATUS_ASSIGNED_TO_DRIVER,
    ORDER_STATUS_DELIVERED,
    ORDER_STATUS_DELIVERY_FAILED,
    ORDER_STATUS_DRIVER_PICKED_UP,
    ORDER_STATUS_OUT_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_PICKUP,
    PAYMENT_STATUS_IN_DAILY_CLOSURE,
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
    orders = frappe.get_all("Awamir Order Request", filters=filters, pluck="name", order_by="required_date asc")
    return [_order_detail(order) for order in orders]


@frappe.whitelist()
def mark_pickup_order_delivered(order=None, order_id=None):
    require_roles(["Awamir Branch Employee", "Awamir Branch Supervisor", "Awamir System Admin"])
    order = order or order_id
    assert_required(order, "Order is required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    require_branch_scope(doc.pickup_branch)
    if doc.status == ORDER_STATUS_DELIVERED:
        return _order_response(doc, _("Order is already delivered."))
    if doc.status != ORDER_STATUS_READY_FOR_PICKUP:
        frappe.throw(_("Only Ready For Pickup orders can be delivered from branch."))
    doc.save(ignore_permissions=True)
    doc.reload()
    if to_float(doc.remaining_amount) > 0 and not (is_awamir_admin() or get_awamir_settings().allow_delivery_without_full_payment):
        frappe.throw(_("Remaining amount must be collected before delivery."))
    old_status = doc.status
    doc.status = ORDER_STATUS_DELIVERED
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, doc.status, _("Delivered to customer from branch."))
    create_notification(
        doc.created_by_user,
        _("Order Delivered"),
        _("Order {0} was delivered.").format(doc.order_number),
        doc.name,
        "order_delivered",
    )
    return _order_response(doc, _("Order delivered successfully."))


@frappe.whitelist()
def collect_remaining_payment(
    order=None,
    amount=0,
    payment_method="Cash",
    payment_reference=None,
    receipt_attachment=None,
    order_id=None,
):
    require_roles(["Awamir Branch Employee", "Awamir Branch Supervisor", "Awamir Driver", "Awamir System Admin"])
    order = order or order_id
    assert_required(order, "Order is required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    _ensure_payment_scope(doc)
    doc.save(ignore_permissions=True)
    doc.reload()
    amount = to_float(amount)
    if amount <= 0:
        frappe.throw(_("Payment amount must be greater than zero."))
    if amount > to_float(doc.remaining_amount):
        frappe.throw(_("Payment amount cannot exceed remaining amount."))

    receiver_role = "driver" if "Awamir Driver" in frappe.get_roles() and not is_awamir_admin() else "branch_employee"
    cash_closure = _get_or_create_open_cash_closure(frappe.session.user, receiver_role)
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
            "received_by_role": receiver_role,
            "cash_closure": cash_closure,
            "status": PAYMENT_STATUS_IN_DAILY_CLOSURE if cash_closure else PAYMENT_STATUS_RECORDED,
            "created_at": now(),
        }
    ).insert(ignore_permissions=True)
    doc.remaining_amount = max(to_float(doc.remaining_amount) - amount, 0)
    doc.save(ignore_permissions=True)
    if cash_closure:
        _recalculate_closure_totals(cash_closure)
    make_status_log(doc.name, doc.status, doc.status, _("Remaining payment collected: {0}.").format(amount))
    create_notification(
        doc.created_by_user,
        _("Payment Collected"),
        _("Payment collected for order {0}.").format(doc.order_number),
        doc.name,
        "payment_collected",
    )
    return _payment_response(payment, doc, _("Payment collected successfully."))


@frappe.whitelist()
def get_available_drivers(branch_id=None):
    require_roles(["Awamir Distribution Manager", "Awamir System Admin"])
    drivers = []
    for row in frappe.get_all("Has Role", filters={"role": "Awamir Driver"}, fields=["parent"]):
        user = frappe.get_doc("User", row.parent)
        branch = get_user_branch(row.parent)
        if branch_id and branch and branch != branch_id:
            continue
        count = frappe.db.count(
            "Awamir Delivery Assignment",
            filters={"driver": row.parent, "status": ["in", [ORDER_STATUS_ASSIGNED_TO_DRIVER, ORDER_STATUS_DRIVER_PICKED_UP, ORDER_STATUS_OUT_FOR_DELIVERY]]},
        )
        drivers.append(
            {
                "id": user.name,
                "user_id": user.name,
                "user": user.name,
                "full_name": user.full_name or user.name,
                "phone": _user_phone(user),
                "email": user.email,
                "branch_id": branch,
                "branch": branch,
                "branch_name": branch,
                "current_assigned_orders_count": count,
                "assigned_orders_count": count,
                "is_active": 1 if user.enabled else 0,
            }
        )
    return drivers


@frappe.whitelist()
def assign_driver_to_order(order=None, driver=None, order_id=None, driver_id=None):
    require_roles(["Awamir Distribution Manager", "Awamir System Admin"])
    order = order or order_id
    driver = driver or driver_id
    assert_required(order, "Order is required.")
    assert_required(driver, "Driver is required.")
    if not frappe.db.exists("User", driver) or "Awamir Driver" not in frappe.get_roles(driver):
        frappe.throw(_("Driver is not active or does not exist."))
    doc = frappe.get_doc("Awamir Order Request", order)
    if not is_awamir_admin() and get_user_branch() and doc.created_branch != get_user_branch():
        frappe.throw(_("You can only assign drivers for orders in your branch."), frappe.PermissionError)
    if doc.status == ORDER_STATUS_ASSIGNED_TO_DRIVER and doc.assigned_driver == driver:
        return _order_response(doc, _("Order is already assigned to this driver."))
    if doc.status != ORDER_STATUS_READY_FOR_DELIVERY:
        frappe.throw(_("Only Ready For Delivery orders can be assigned to a driver."))
    existing_assignment = frappe.db.get_value(
        "Awamir Delivery Assignment",
        {"order": doc.name, "driver": driver, "status": ["!=", ORDER_STATUS_DELIVERY_FAILED]},
        "name",
    )
    if existing_assignment:
        doc.assigned_driver = driver
        doc.status = ORDER_STATUS_ASSIGNED_TO_DRIVER
        doc.save(ignore_permissions=True)
        return _order_response(doc, _("Order is already assigned to this driver."))
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
    driver_name = frappe.db.get_value("User", driver, "full_name") or driver
    create_notification(
        driver,
        _("New Delivery Order"),
        _("Order {0} assigned to you.").format(doc.order_number),
        doc.name,
        "driver_assigned",
    )
    create_notification(
        doc.created_by_user,
        _("Driver Assigned"),
        _("Order {0} assigned to driver {1}.").format(doc.order_number, driver_name),
        doc.name,
        "driver_assigned",
    )
    return _order_response(doc, _("Order assigned to driver successfully."))


@frappe.whitelist()
def get_driver_orders():
    require_roles(["Awamir Driver", "Awamir System Admin"])
    filters = {
        "status": [
            "in",
            [
                ORDER_STATUS_ASSIGNED_TO_DRIVER,
                ORDER_STATUS_DRIVER_PICKED_UP,
                ORDER_STATUS_OUT_FOR_DELIVERY,
                ORDER_STATUS_DELIVERY_FAILED,
                ORDER_STATUS_DELIVERED,
            ],
        ]
    }
    if not is_awamir_admin():
        filters["assigned_driver"] = frappe.session.user
    orders = frappe.get_all("Awamir Order Request", filters=filters, pluck="name", order_by="required_date asc")
    return [_order_detail(order) for order in orders]


@frappe.whitelist()
def update_delivery_status(order=None, new_status=None, proof_image=None, driver_notes=None, status=None, order_id=None):
    require_roles(["Awamir Driver", "Awamir System Admin"])
    order = order or order_id
    new_status = new_status or status
    assert_required(order, "Order is required.")
    assert_required(new_status, "Delivery status is required.")
    transitions = {
        ORDER_STATUS_ASSIGNED_TO_DRIVER: [ORDER_STATUS_DRIVER_PICKED_UP],
        ORDER_STATUS_DRIVER_PICKED_UP: [ORDER_STATUS_OUT_FOR_DELIVERY],
        ORDER_STATUS_OUT_FOR_DELIVERY: [ORDER_STATUS_DELIVERED],
    }
    doc = frappe.get_doc("Awamir Order Request", order)
    if not is_awamir_admin() and doc.assigned_driver != frappe.session.user:
        frappe.throw(_("You can only update your assigned delivery orders."), frappe.PermissionError)
    if doc.status == new_status:
        return _order_response(doc, _("Delivery status is already updated."))
    if new_status not in transitions.get(doc.status, []):
        frappe.throw(_("Invalid delivery status transition."))
    if new_status == ORDER_STATUS_DELIVERED:
        doc.save(ignore_permissions=True)
        doc.reload()
    if new_status == ORDER_STATUS_DELIVERED and to_float(doc.remaining_amount) > 0 and not get_awamir_settings().allow_delivery_without_full_payment:
        frappe.throw(_("Remaining amount must be collected before delivery."))
    old_status = doc.status
    doc.status = new_status
    doc.save(ignore_permissions=True)
    _update_assignment(doc, new_status, proof_image=proof_image, driver_notes=driver_notes)
    make_status_log(doc.name, old_status, new_status, driver_notes)
    _create_delivery_notifications(doc, new_status)
    return _order_response(doc, _("Delivery status updated successfully."))


@frappe.whitelist()
def mark_delivery_failed(order=None, reason=None, failure_reason=None, order_id=None):
    require_roles(["Awamir Driver", "Awamir System Admin"])
    order = order or order_id
    reason = (reason or failure_reason or "").strip()
    assert_required(order, "Order is required.")
    assert_required(reason, "Failure reason is required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    if not is_awamir_admin() and doc.assigned_driver != frappe.session.user:
        frappe.throw(_("You can only update your assigned delivery orders."), frappe.PermissionError)
    if doc.status == ORDER_STATUS_DELIVERY_FAILED:
        return _order_response(doc, _("Delivery is already marked as failed."))
    if doc.status not in (ORDER_STATUS_ASSIGNED_TO_DRIVER, ORDER_STATUS_DRIVER_PICKED_UP, ORDER_STATUS_OUT_FOR_DELIVERY):
        frappe.throw(_("Invalid delivery status transition."))
    old_status = doc.status
    doc.status = ORDER_STATUS_DELIVERY_FAILED
    doc.save(ignore_permissions=True)
    _update_assignment(doc, ORDER_STATUS_DELIVERY_FAILED, failure_reason=reason)
    make_status_log(doc.name, old_status, doc.status, reason)
    _create_delivery_notifications(doc, ORDER_STATUS_DELIVERY_FAILED, failure_reason=reason)
    return _order_response(doc, _("Delivery failure recorded successfully."))


@frappe.whitelist()
def collect_delivery_payment(order=None, amount=0, payment_method="Cash", payment_reference=None, receipt_attachment=None, order_id=None):
    require_roles(["Awamir Driver", "Awamir System Admin"])
    return collect_remaining_payment(
        order=order or order_id,
        amount=amount,
        payment_method=payment_method,
        payment_reference=payment_reference,
        receipt_attachment=receipt_attachment,
    )


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


def _ensure_payment_scope(doc):
    if is_awamir_admin():
        return
    roles = frappe.get_roles()
    if "Awamir Driver" in roles:
        if doc.assigned_driver != frappe.session.user:
            frappe.throw(_("You can only collect payment for your assigned delivery orders."), frappe.PermissionError)
        return
    require_branch_scope(doc.pickup_branch or doc.created_branch)


def _get_or_create_open_cash_closure(user, closure_type):
    closure_name = frappe.db.get_value(
        "Awamir Daily Cash Closure",
        {
            "user": user,
            "date": frappe.utils.today(),
            "closure_type": closure_type,
            "status": ["in", [CLOSURE_STATUS_OPEN, CLOSURE_STATUS_RETURNED]],
        },
        "name",
    )
    if closure_name:
        return closure_name
    closure = frappe.get_doc(
        {
            "doctype": "Awamir Daily Cash Closure",
            "closure_type": closure_type,
            "user": user,
            "branch": get_user_branch(user),
            "date": frappe.utils.today(),
            "status": CLOSURE_STATUS_OPEN,
        }
    ).insert(ignore_permissions=True)
    return closure.name


def _recalculate_closure_totals(closure_name):
    closure = frappe.get_doc("Awamir Daily Cash Closure", closure_name)
    totals = {"Cash": 0, "Card": 0, "Transfer": 0, "Other": 0}
    for payment in frappe.get_all("Awamir Order Payment", filters={"cash_closure": closure.name}, fields=["payment_method", "amount"]):
        method = payment.payment_method if payment.payment_method in totals else "Other"
        totals[method] += to_float(payment.amount)
    closure.total_cash = totals["Cash"]
    closure.total_card = totals["Card"]
    closure.total_transfer = totals["Transfer"]
    closure.total_other = totals["Other"]
    closure.save(ignore_permissions=True)


def _create_delivery_notifications(doc, status, failure_reason=None):
    notification_type = {
        ORDER_STATUS_DRIVER_PICKED_UP: "driver_picked_up",
        ORDER_STATUS_OUT_FOR_DELIVERY: "out_for_delivery",
        ORDER_STATUS_DELIVERED: "order_delivered",
        ORDER_STATUS_DELIVERY_FAILED: "delivery_failed",
    }.get(status, "delivery_status")
    title = {
        ORDER_STATUS_DRIVER_PICKED_UP: _("Driver Picked Up Order"),
        ORDER_STATUS_OUT_FOR_DELIVERY: _("Order Out For Delivery"),
        ORDER_STATUS_DELIVERED: _("Order Delivered"),
        ORDER_STATUS_DELIVERY_FAILED: _("Delivery Failed"),
    }.get(status, _("Delivery Updated"))
    message = _("Order {0} status changed to {1}.").format(doc.order_number, status)
    if failure_reason:
        message = _("Delivery failed for order {0}: {1}").format(doc.order_number, failure_reason)
    create_notification(doc.created_by_user, title, message, doc.name, notification_type)
    for row in frappe.get_all("Has Role", filters={"role": "Awamir Distribution Manager"}, fields=["parent"]):
        create_notification(row.parent, title, message, doc.name, notification_type)


def _order_response(doc, message):
    return {
        "order_id": doc.name,
        "order_number": doc.order_number,
        "status": doc.status,
        "message": message,
        "order": _order_detail(doc.name),
    }


def _payment_response(payment, order_doc, message):
    return {
        "payment_id": payment.name,
        "order_id": order_doc.name,
        "order_number": order_doc.order_number,
        "remaining_amount": order_doc.remaining_amount,
        "message": message,
        "payment": payment.as_dict(),
        "order": _order_detail(order_doc.name),
    }


def _order_detail(order):
    from awamir_plus.api.orders import get_order_detail

    return get_order_detail(order)


def _user_phone(user_doc):
    return (getattr(user_doc, "mobile_no", None) or getattr(user_doc, "phone", None) or "").strip()
