import frappe
from frappe import _

from awamir_plus.constants import (
    CLOSURE_STATUS_OPEN,
    CLOSURE_STATUS_RETURNED,
    DELIVERY_BATCH_STATUS_DELIVERED,
    DELIVERY_BATCH_STATUS_OUT_FOR_DELIVERY,
    DELIVERY_BATCH_STATUS_PARTIALLY_DELIVERED,
    DELIVERY_BATCH_STATUS_PICKED_UP,
    DELIVERY_BATCH_STATUS_RETURNED,
    DELIVERY_FLOW_STATUS_DELIVERED,
    DELIVERY_FLOW_STATUS_OUT_FOR_DELIVERY,
    DELIVERY_FLOW_STATUS_PICKED_UP,
    DELIVERY_FLOW_STATUS_RETURNED,
    ORDER_FLOW_STATUS_DELIVERED,
    ORDER_PAYMENT_FLOW_STATUS_PAID,
    ORDER_STATUS_ASSIGNED_TO_DRIVER,
    ORDER_STATUS_DELIVERED,
    ORDER_STATUS_DELIVERY_FAILED,
    ORDER_STATUS_DRIVER_PICKED_UP,
    ORDER_STATUS_OUT_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_PICKUP,
    PAYMENT_STATUS_IN_DAILY_CLOSURE,
    PAYMENT_STATUS_RECORDED,
    PERMISSION_DELIVERY_BATCH_ASSIGN_DRIVER,
    PERMISSION_DELIVERY_BATCH_CREATE,
    PERMISSION_DELIVERY_BATCH_VIEW,
    PERMISSION_DELIVERY_BATCH_VIEW_ASSIGNED,
    PERMISSION_DELIVERY_COLLECT_CASH,
    PERMISSION_DELIVERY_CONFIRM_DELIVERED,
    PERMISSION_DELIVERY_UPDATE_STATUS,
    PERMISSION_DELIVERY_VIEW_ASSIGNED,
    PERMISSION_ORDER_DELIVER_BRANCH,
    PERMISSION_PAYMENT_COLLECT_BRANCH,
)
from awamir_plus.permissions import get_user_branch, has_permission, is_awamir_admin, require_any_permissions, require_branch_scope, require_permissions
from awamir_plus.services.delivery_batch import (
    assign_batch_to_driver,
    create_batches_for_ready_delivery_orders,
    get_delivery_batches as get_delivery_batches_for_user,
)
from awamir_plus.utils import assert_required, create_notification, get_awamir_settings, get_pagination, make_audit_log, make_status_log, now, run_idempotent, to_float


@frappe.whitelist()
def get_pickup_orders(limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_ORDER_DELIVER_BRANCH)
    filters = {"status": ORDER_STATUS_READY_FOR_PICKUP}
    if not is_awamir_admin():
        filters["pickup_branch"] = get_user_branch()
    orders = frappe.get_all(
        "Awamir Order Request",
        filters=filters,
        pluck="name",
        order_by="required_date asc",
        **get_pagination(limit_start, limit_page_length),
    )
    return [_order_detail(order) for order in orders]


@frappe.whitelist()
def mark_pickup_order_delivered(
    order=None,
    order_id=None,
    received_by_name=None,
    proof_image_url=None,
    signature_url=None,
    qr_scanned=0,
):
    require_permissions(PERMISSION_ORDER_DELIVER_BRANCH)
    order = order or order_id
    assert_required(order, "Order is required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    require_branch_scope(doc.pickup_branch)
    if doc.status == ORDER_STATUS_DELIVERED:
        response = _order_response(doc, _("Order is already delivered."))
        make_audit_log("pickup_delivery_skipped", status="skipped", reference_doctype="Awamir Order Request", reference_name=doc.name, method="mark_pickup_order_delivered", response=response)
        return response
    if doc.status != ORDER_STATUS_READY_FOR_PICKUP:
        frappe.throw(_("Only Ready For Pickup orders can be delivered from branch."))
    doc.save(ignore_permissions=True)
    doc.reload()
    if to_float(doc.remaining_amount) > 0 and not (is_awamir_admin() or get_awamir_settings().allow_delivery_without_full_payment):
        frappe.throw(_("Remaining amount must be collected before delivery."))
    old_status = doc.status
    doc.status = ORDER_STATUS_DELIVERED
    doc.received_by_name = received_by_name
    doc.proof_image_url = proof_image_url
    doc.signature_url = signature_url
    doc.qr_scanned = 1 if _as_bool(qr_scanned) else 0
    doc.delivered_at = now()
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, doc.status, _("Delivered to customer from branch."))
    create_notification(
        doc.created_by_user,
        _("Order Delivered"),
        _("Order {0} was delivered.").format(doc.order_number),
        doc.name,
        "order_delivered",
    )
    response = _order_response(doc, _("Order delivered successfully."))
    make_audit_log("pickup_order_delivered", reference_doctype="Awamir Order Request", reference_name=doc.name, method="mark_pickup_order_delivered", response=response)
    return response


@frappe.whitelist()
def collect_remaining_payment(
    order=None,
    amount=0,
    payment_method="Cash",
    payment_reference=None,
    receipt_attachment=None,
    order_id=None,
):
    require_any_permissions([PERMISSION_PAYMENT_COLLECT_BRANCH, PERMISSION_DELIVERY_COLLECT_CASH])
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

    receiver_role = (
        "driver"
        if has_permission(PERMISSION_DELIVERY_COLLECT_CASH) and not is_awamir_admin()
        else "branch_employee"
    )
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
    response = _payment_response(payment, doc, _("Payment collected successfully."))
    make_audit_log("remaining_payment_collected", reference_doctype="Awamir Order Request", reference_name=doc.name, method="collect_remaining_payment", payload={"amount": amount, "payment_method": payment_method, "payment_reference": payment_reference}, response=response)
    return response


@frappe.whitelist()
def get_available_drivers(branch_id=None):
    require_permissions(PERMISSION_DELIVERY_BATCH_ASSIGN_DRIVER)
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
def create_delivery_batches(branch_id=None, idempotency_key=None):
    require_permissions(PERMISSION_DELIVERY_BATCH_CREATE)
    payload = {"branch_id": branch_id}

    def _execute():
        branch = branch_id
        if not is_awamir_admin():
            branch = branch or get_user_branch()
        return {
            "batches": create_batches_for_ready_delivery_orders(branch=branch),
            "message": _("Delivery batches are ready."),
        }

    return run_idempotent("create_delivery_batches", payload, _execute, idempotency_key=idempotency_key)


@frappe.whitelist()
def get_delivery_batches(status=None, destination_branch=None):
    require_any_permissions([PERMISSION_DELIVERY_BATCH_VIEW, PERMISSION_DELIVERY_BATCH_VIEW_ASSIGNED])
    statuses = [status] if status else None
    driver = None
    if not is_awamir_admin() and has_permission(PERMISSION_DELIVERY_BATCH_VIEW_ASSIGNED):
        driver = frappe.session.user
    if not is_awamir_admin() and has_permission(PERMISSION_DELIVERY_BATCH_VIEW):
        destination_branch = destination_branch or get_user_branch()
    return get_delivery_batches_for_user(
        statuses=statuses,
        driver=driver,
        destination_branch=destination_branch,
    )


@frappe.whitelist()
def assign_delivery_batch(batch=None, driver=None, batch_id=None, driver_id=None, idempotency_key=None):
    require_permissions(PERMISSION_DELIVERY_BATCH_ASSIGN_DRIVER)
    batch = batch or batch_id
    driver = driver or driver_id
    assert_required(batch, "Delivery batch is required.")
    assert_required(driver, "Driver is required.")
    payload = {"batch": batch, "driver": driver}

    def _execute():
        doc = assign_batch_to_driver(batch, driver)
        response = {
            "batch": doc.as_dict(),
            "message": _("Delivery batch assigned successfully."),
        }
        make_audit_log("delivery_batch_assigned", reference_doctype="Awamir Delivery Batch", reference_name=doc.name, method="assign_delivery_batch", payload={"driver": driver}, response=response)
        return response

    return run_idempotent("assign_delivery_batch", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Delivery Batch", reference_name=batch)


@frappe.whitelist()
def assign_driver_to_order(order=None, driver=None, order_id=None, driver_id=None):
    require_permissions(PERMISSION_DELIVERY_BATCH_ASSIGN_DRIVER)
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
        response = _order_response(doc, _("Order is already assigned to this driver."))
        make_audit_log("driver_assignment_skipped", status="skipped", reference_doctype="Awamir Order Request", reference_name=doc.name, method="assign_driver_to_order", payload={"driver": driver}, response=response)
        return response
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
        response = _order_response(doc, _("Order is already assigned to this driver."))
        make_audit_log("driver_assignment_skipped", status="skipped", reference_doctype="Awamir Order Request", reference_name=doc.name, method="assign_driver_to_order", payload={"driver": driver}, response=response)
        return response
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
    response = _order_response(doc, _("Order assigned to driver successfully."))
    make_audit_log("driver_assigned", reference_doctype="Awamir Order Request", reference_name=doc.name, method="assign_driver_to_order", payload={"driver": driver}, response=response)
    return response


@frappe.whitelist()
def get_driver_orders(status=None, limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_DELIVERY_VIEW_ASSIGNED)
    allowed_statuses = [
        ORDER_STATUS_ASSIGNED_TO_DRIVER,
        ORDER_STATUS_DRIVER_PICKED_UP,
        ORDER_STATUS_OUT_FOR_DELIVERY,
        ORDER_STATUS_DELIVERY_FAILED,
        ORDER_STATUS_DELIVERED,
    ]
    filters = {
        "status": status if status in allowed_statuses else ["in", allowed_statuses]
    }
    if not is_awamir_admin():
        filters["assigned_driver"] = frappe.session.user
    orders = frappe.get_all(
        "Awamir Order Request",
        filters=filters,
        pluck="name",
        order_by="required_date asc",
        **get_pagination(limit_start, limit_page_length),
    )
    return [_order_detail(order) for order in orders]


@frappe.whitelist()
def update_delivery_status(
    order=None,
    new_status=None,
    proof_image=None,
    driver_notes=None,
    status=None,
    order_id=None,
    received_by_name=None,
    signature_url=None,
    qr_scanned=0,
):
    require_any_permissions([PERMISSION_DELIVERY_UPDATE_STATUS, PERMISSION_DELIVERY_CONFIRM_DELIVERED])
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
    if new_status == ORDER_STATUS_DELIVERED:
        doc.received_by_name = received_by_name
        doc.proof_image_url = proof_image
        doc.signature_url = signature_url
        doc.qr_scanned = 1 if _as_bool(qr_scanned) else 0
        doc.delivered_at = now()
    _sync_delivery_flow_status(doc, new_status)
    doc.save(ignore_permissions=True)
    _update_assignment(
        doc,
        new_status,
        proof_image=proof_image,
        driver_notes=driver_notes,
        received_by_name=received_by_name,
        signature_url=signature_url,
        qr_scanned=qr_scanned,
    )
    _sync_delivery_batch_order_status(doc)
    make_status_log(doc.name, old_status, new_status, driver_notes)
    _create_delivery_notifications(doc, new_status)
    response = _order_response(doc, _("Delivery status updated successfully."))
    make_audit_log("delivery_status_updated", reference_doctype="Awamir Order Request", reference_name=doc.name, method="update_delivery_status", payload={"new_status": new_status, "driver_notes": driver_notes}, response=response)
    return response


@frappe.whitelist()
def mark_delivery_failed(order=None, reason=None, failure_reason=None, order_id=None):
    require_permissions(PERMISSION_DELIVERY_UPDATE_STATUS)
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
    doc.delivery_status = DELIVERY_FLOW_STATUS_RETURNED
    doc.save(ignore_permissions=True)
    _update_assignment(doc, ORDER_STATUS_DELIVERY_FAILED, failure_reason=reason)
    _sync_delivery_batch_order_status(doc)
    make_status_log(doc.name, old_status, doc.status, reason)
    _create_delivery_notifications(doc, ORDER_STATUS_DELIVERY_FAILED, failure_reason=reason)
    response = _order_response(doc, _("Delivery failure recorded successfully."))
    make_audit_log("delivery_failed", reference_doctype="Awamir Order Request", reference_name=doc.name, method="mark_delivery_failed", payload={"reason": reason}, response=response)
    return response


@frappe.whitelist()
def collect_delivery_payment(order=None, amount=0, payment_method="Cash", payment_reference=None, receipt_attachment=None, order_id=None):
    require_permissions(PERMISSION_DELIVERY_COLLECT_CASH)
    return collect_remaining_payment(
        order=order or order_id,
        amount=amount,
        payment_method=payment_method,
        payment_reference=payment_reference,
        receipt_attachment=receipt_attachment,
    )


def _update_assignment(
    order_doc,
    status,
    proof_image=None,
    driver_notes=None,
    failure_reason=None,
    received_by_name=None,
    signature_url=None,
    qr_scanned=0,
):
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
        assignment.received_by_name = received_by_name
        assignment.signature_url = signature_url
        assignment.qr_scanned = 1 if _as_bool(qr_scanned) else 0
    elif status == ORDER_STATUS_DELIVERY_FAILED:
        assignment.failed_at = now()
        assignment.failure_reason = failure_reason
    if driver_notes:
        assignment.driver_notes = driver_notes
    assignment.save(ignore_permissions=True)


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in ("1", "true", "yes", "y")


def _sync_delivery_flow_status(order_doc, status):
    if status == ORDER_STATUS_DRIVER_PICKED_UP:
        order_doc.delivery_status = DELIVERY_FLOW_STATUS_PICKED_UP
    elif status == ORDER_STATUS_OUT_FOR_DELIVERY:
        order_doc.delivery_status = DELIVERY_FLOW_STATUS_OUT_FOR_DELIVERY
    elif status == ORDER_STATUS_DELIVERED:
        order_doc.delivery_status = DELIVERY_FLOW_STATUS_DELIVERED
        order_doc.order_status = ORDER_FLOW_STATUS_DELIVERED
        if to_float(order_doc.remaining_amount) <= 0:
            order_doc.payment_status = ORDER_PAYMENT_FLOW_STATUS_PAID


def _sync_delivery_batch_order_status(order_doc):
    rows = frappe.get_all(
        "Awamir Delivery Batch Order",
        filters={"order": order_doc.name},
        fields=["name", "parent"],
    )
    for row in rows:
        batch = frappe.get_doc("Awamir Delivery Batch", row.parent)
        changed = False
        for batch_order in batch.orders:
            if batch_order.name == row.name and batch_order.status != order_doc.status:
                batch_order.status = order_doc.status
                changed = True
        if changed:
            _sync_batch_status(batch)
            batch.save(ignore_permissions=True)


def _sync_batch_status(batch):
    statuses = {row.status for row in batch.orders}
    if not statuses:
        return
    if statuses == {ORDER_STATUS_DELIVERED}:
        batch.status = DELIVERY_BATCH_STATUS_DELIVERED
        batch.delivered_at = batch.delivered_at or now()
    elif statuses == {ORDER_STATUS_DELIVERY_FAILED}:
        batch.status = DELIVERY_BATCH_STATUS_RETURNED
        batch.returned_at = batch.returned_at or now()
    elif ORDER_STATUS_DELIVERED in statuses or ORDER_STATUS_DELIVERY_FAILED in statuses:
        batch.status = DELIVERY_BATCH_STATUS_PARTIALLY_DELIVERED
    elif ORDER_STATUS_OUT_FOR_DELIVERY in statuses:
        batch.status = DELIVERY_BATCH_STATUS_OUT_FOR_DELIVERY
        batch.out_for_delivery_at = batch.out_for_delivery_at or now()
    elif ORDER_STATUS_DRIVER_PICKED_UP in statuses:
        batch.status = DELIVERY_BATCH_STATUS_PICKED_UP
        batch.picked_up_at = batch.picked_up_at or now()


def _ensure_payment_scope(doc):
    if is_awamir_admin():
        return
    if has_permission(PERMISSION_DELIVERY_COLLECT_CASH):
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
