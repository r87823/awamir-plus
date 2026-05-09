import frappe
from frappe import _
from frappe.utils import getdate, now_datetime

from awamir_plus.constants import (
    DEPARTMENT_WORK_ORDER_STATUS_CANCELLED,
    ORDER_STATUS_CANCELLED,
    ORDER_STATUS_DELIVERED,
    ORDER_STATUS_DRAFT,
    ORDER_STATUS_PENDING_APPROVAL,
    PAYMENT_STATUS_RECORDED,
    PERMISSION_ACCOUNTING_VIEW_FINANCIALS,
    PERMISSION_CASHBOX_VIEW_ALL,
    PERMISSION_CASHBOX_VIEW_OWN,
    PERMISSION_DELIVERY_VIEW_ALL,
    PERMISSION_DELIVERY_VIEW_ASSIGNED,
    PERMISSION_FULFILLMENT_VIEW_QUEUE,
    PERMISSION_ORDER_CANCEL,
    PERMISSION_ORDER_CREATE,
    PERMISSION_ORDER_VIEW_BRANCH,
    PERMISSION_ORDER_VIEW_OWN,
    PERMISSION_WORK_ORDER_VIEW_DEPARTMENT,
    PAYMENT_STATUS_IN_DAILY_CLOSURE,
    ROLE_BRANCH_SUPERVISOR,
)
from awamir_plus.permissions import (
    get_user_branch,
    get_user_production_department,
    has_permission,
    is_awamir_admin,
    require_any_permissions,
    require_branch_scope,
    require_permissions,
)
from awamir_plus.utils import (
    assert_required,
    create_notification,
    extract_coordinates_from_google_maps_url,
    get_idempotent_response,
    get_pagination,
    get_request_idempotency_key,
    make_audit_log,
    make_status_log,
    normalize_phone_input,
    parse_json,
    run_idempotent,
    save_idempotent_response,
    serialize_doc,
    to_float,
)


@frappe.whitelist()
def create_order(order_data=None, idempotency_key=None, **kwargs):
    data = _parse_order_data(order_data, kwargs)
    key = get_request_idempotency_key(idempotency_key or data.get("idempotency_key"))
    cached = get_idempotent_response(key, "create_order", payload=data)
    if cached:
        return cached
    status = ORDER_STATUS_PENDING_APPROVAL if _as_bool(data.get("submit_for_approval")) else ORDER_STATUS_DRAFT
    response = _save_order(data, status)
    save_idempotent_response(
        key,
        "create_order",
        payload=data,
        response=response,
        reference_doctype="Awamir Order Request",
        reference_name=response.get("order_id"),
    )
    return response


@frappe.whitelist()
def save_order_as_draft(order_data=None, idempotency_key=None, **kwargs):
    data = _parse_order_data(order_data, kwargs)

    def _execute():
        return _save_order(data, ORDER_STATUS_DRAFT)

    return run_idempotent(
        "save_order_as_draft",
        data,
        _execute,
        idempotency_key=idempotency_key or data.get("idempotency_key"),
    )


@frappe.whitelist()
def submit_order_for_approval(order_data=None, order=None, order_id=None, idempotency_key=None, **kwargs):
    existing_order = order or order_id or kwargs.get("order") or kwargs.get("order_id")
    parsed_data = parse_json(order_data, None)
    if existing_order and not isinstance(parsed_data, dict):
        payload = {"order": existing_order}

        def _execute_existing():
            return _submit_existing_order_for_approval(existing_order)

        return run_idempotent(
            "submit_existing_order_for_approval",
            payload,
            _execute_existing,
            idempotency_key=idempotency_key,
            reference_doctype="Awamir Order Request",
            reference_name=existing_order,
        )

    data = _parse_order_data(order_data, kwargs)

    def _execute():
        return _save_order(data, ORDER_STATUS_PENDING_APPROVAL)

    return run_idempotent(
        "submit_order_for_approval",
        data,
        _execute,
        idempotency_key=idempotency_key or data.get("idempotency_key"),
    )


def _submit_existing_order_for_approval(order):
    require_permissions(PERMISSION_ORDER_CREATE)
    assert_required(order, "Order is required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    require_branch_scope(doc.created_branch)

    if doc.status == ORDER_STATUS_PENDING_APPROVAL:
        response = _order_response(doc)
        response["message"] = _("Order is already waiting for supervisor approval.")
        make_audit_log(
            "order_submit_for_approval_skipped",
            status="skipped",
            reference_doctype="Awamir Order Request",
            reference_name=doc.name,
            method="submit_order_for_approval",
            payload={"order": order},
            response=response,
        )
        return response

    if doc.status != ORDER_STATUS_DRAFT:
        frappe.throw(_("Only draft orders can be sent for supervisor approval."))

    old_status = doc.status
    doc.status = ORDER_STATUS_PENDING_APPROVAL
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, doc.status, _("Order sent for supervisor approval."))
    for supervisor in _get_branch_supervisors():
        create_notification(
            supervisor,
            _("New Order Approval"),
            _("Order {0} is waiting for approval.").format(doc.order_number),
            doc.name,
            "order_submitted",
        )

    response = _order_response(doc)
    response["message"] = _("Order sent for supervisor approval.")
    make_audit_log(
        "order_submitted_for_approval",
        reference_doctype="Awamir Order Request",
        reference_name=doc.name,
        method="submit_order_for_approval",
        payload={"order": order},
        response=response,
    )
    return response


@frappe.whitelist()
def cancel_order(order=None, order_id=None, reason=None, idempotency_key=None):
    require_permissions(PERMISSION_ORDER_CANCEL)
    order = order or order_id
    reason = (reason or "").strip()
    assert_required(order, "Order is required.")
    assert_required(reason, "Cancellation reason is required.")
    payload = {"order": order, "reason": reason}

    def _execute():
        doc = frappe.get_doc("Awamir Order Request", order)
        require_branch_scope(doc.created_branch)
        if doc.status == ORDER_STATUS_CANCELLED:
            response = {"order": get_order_detail(doc.name), "message": _("Order is already cancelled.")}
            make_audit_log("order_cancel_skipped", status="skipped", reference_doctype="Awamir Order Request", reference_name=doc.name, method="cancel_order", payload=payload, response=response)
            return response
        if doc.status == ORDER_STATUS_DELIVERED:
            frappe.throw(_("Delivered orders cannot be cancelled."))
        old_status = doc.status
        doc.status = ORDER_STATUS_CANCELLED
        doc.is_cancelled = 1
        doc.cancelled_at = now_datetime()
        doc.cancelled_by = frappe.session.user
        doc.cancellation_reason = reason
        doc.save(ignore_permissions=True)
        _cancel_related_work_orders(doc.name)
        make_status_log(doc.name, old_status, doc.status, reason)
        create_notification(
            doc.created_by_user,
            _("Order Cancelled"),
            _("Order {0} was cancelled.").format(doc.order_number),
            doc.name,
            "order_cancelled",
        )
        response = {"order": get_order_detail(doc.name), "message": _("Order cancelled successfully.")}
        make_audit_log("order_cancelled", reference_doctype="Awamir Order Request", reference_name=doc.name, method="cancel_order", payload=payload, response=response)
        return response

    return run_idempotent("cancel_order", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Order Request", reference_name=order)


def _save_order(order_data, status):
    require_permissions(PERMISSION_ORDER_CREATE)
    data = order_data if isinstance(order_data, dict) else parse_json(order_data, {})
    data["customer_phone"] = normalize_phone_input(data.get("customer_phone"))
    items = data.get("items") or []
    assert_required(items, "At least one item is required.")
    assert_required(data.get("customer_phone"), "Customer phone is required.")
    assert_required(data.get("required_date"), "Required date is required.")
    assert_required(data.get("required_time"), "Required time is required.")

    requested_branch = data.get("created_branch")
    user_branch = get_user_branch()
    branch = requested_branch or user_branch
    if not is_awamir_admin() and user_branch and requested_branch and requested_branch != user_branch:
        frappe.throw(_("Created branch must match your branch."))
    assert_required(branch, "Created branch is required.")

    required_date = getdate(data.get("required_date"))
    if required_date < getdate():
        frappe.throw(_("Required date cannot be in the past."))

    delivery_type = data.get("delivery_type") or "Pickup"
    pickup_branch = data.get("pickup_branch") or (branch if delivery_type == "Pickup" else None)

    if delivery_type == "Delivery" and not (data.get("delivery_address") or data.get("delivery_location_url")):
        frappe.throw(_("Delivery address or location URL is required."))

    customer = _get_or_create_customer(data)
    if customer and not data.get("customer_name"):
        data["customer_name"] = frappe.db.get_value("Customer", customer, "customer_name")

    coordinates = extract_coordinates_from_google_maps_url(data.get("delivery_location_url"))
    latitude = data.get("latitude") or (coordinates or {}).get("latitude")
    longitude = data.get("longitude") or (coordinates or {}).get("longitude")
    total_amount = sum(to_float(item.get("amount")) or to_float(item.get("qty")) * to_float(item.get("rate")) for item in items)
    delivery_fee = to_float(data.get("delivery_fee"))
    deposit_amount = to_float(data.get("deposit_amount"))
    if deposit_amount > total_amount + delivery_fee:
        frappe.throw(_("Deposit cannot exceed order total plus delivery fee."))

    doc = frappe.get_doc(
        {
            "doctype": "Awamir Order Request",
            "customer": customer,
            "customer_name": data.get("customer_name"),
            "customer_phone": data.get("customer_phone"),
            "customer_type": data.get("customer_type") or "Individual",
            "company_name": data.get("company_name"),
            "tax_id": data.get("tax_id"),
            "company_address": data.get("company_address"),
            "company_email": data.get("company_email"),
            "contact_person": data.get("contact_person"),
            "created_branch": branch,
            "pickup_branch": pickup_branch,
            "delivery_type": delivery_type,
            "delivery_address": data.get("delivery_address"),
            "delivery_location_url": data.get("delivery_location_url"),
            "latitude": latitude,
            "longitude": longitude,
            "delivery_notes": data.get("delivery_notes"),
            "delivery_fee": delivery_fee,
            "priority": data.get("priority") or "normal",
            "scheduled_at": data.get("scheduled_at"),
            "required_date": data.get("required_date"),
            "required_time": data.get("required_time"),
            "pickup_time": data.get("pickup_time"),
            "delivery_window_start": data.get("delivery_window_start"),
            "delivery_window_end": data.get("delivery_window_end"),
            "order_notes": data.get("order_notes") or data.get("order_details"),
            "customer_notes": data.get("customer_notes"),
            "status": status,
            "total_amount": total_amount,
            "deposit_amount": deposit_amount,
            "remaining_amount": total_amount + delivery_fee - deposit_amount,
            "created_by_user": frappe.session.user,
            "items": [_make_item(item) for item in items],
            "attachments": data.get("attachments") or [],
        }
    ).insert()

    if delivery_type == "Delivery":
        _ensure_customer_address(customer, data, latitude, longitude)

    make_status_log(doc.name, None, status, _("Order created."))
    if deposit_amount > 0:
        _record_deposit(doc, deposit_amount, data)
    if status == ORDER_STATUS_PENDING_APPROVAL:
        for supervisor in _get_branch_supervisors():
            create_notification(
                supervisor,
                _("New Order Approval"),
                _("Order {0} is waiting for approval.").format(doc.order_number),
                doc.name,
                "order_submitted",
            )
    response = _order_response(doc)
    make_audit_log(
        "order_created",
        reference_doctype="Awamir Order Request",
        reference_name=doc.name,
        method="_save_order",
        payload=data,
        response=response,
    )
    return response


def _parse_order_data(order_data, kwargs):
    data = parse_json(order_data, None)
    if isinstance(data, dict):
        return data
    if "order_data" in kwargs:
        data = parse_json(kwargs.get("order_data"), None)
        if isinstance(data, dict):
            return data
    return kwargs or {}


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in ("1", "true", "yes", "y")


def _get_or_create_customer(data):
    phone = (data.get("customer_phone") or "").strip()
    customer = data.get("customer")
    if customer and frappe.db.exists("Customer", customer):
        return customer

    if phone:
        customer = frappe.db.get_value("Customer", {"mobile_no": phone}, "name")
        if customer:
            _update_existing_customer(customer, data)
            return customer

    customer_type = "Company" if data.get("customer_type") == "Company" else "Individual"
    customer_name = (
        data.get("company_name")
        if customer_type == "Company"
        else data.get("customer_name")
    ) or data.get("customer_name") or phone
    assert_required(customer_name, "Customer name is required.")

    doc = frappe.get_doc(
        {
            "doctype": "Customer",
            "customer_name": customer_name,
            "customer_type": customer_type,
            "mobile_no": phone,
            "tax_id": data.get("tax_id") if customer_type == "Company" else None,
        }
    ).insert(ignore_permissions=True)
    return doc.name


def _update_existing_customer(customer, data):
    doc = frappe.get_doc("Customer", customer)
    changed = False
    if data.get("customer_name") and not doc.customer_name:
        doc.customer_name = data.get("customer_name")
        changed = True
    if data.get("customer_type") == "Company":
        if doc.customer_type != "Company":
            doc.customer_type = "Company"
            changed = True
        if data.get("company_name") and doc.customer_name != data.get("company_name"):
            doc.customer_name = data.get("company_name")
            changed = True
        if data.get("tax_id") and not doc.tax_id:
            doc.tax_id = data.get("tax_id")
            changed = True
    if changed:
        doc.save(ignore_permissions=True)


def _ensure_customer_address(customer, data, latitude=None, longitude=None):
    if not customer:
        return None
    address_line1 = data.get("delivery_address") or data.get("company_address")
    location_url = data.get("delivery_location_url")
    if not (address_line1 or location_url):
        return None

    existing = frappe.get_all(
        "Dynamic Link",
        filters={"link_doctype": "Customer", "link_name": customer, "parenttype": "Address"},
        pluck="parent",
    )
    for address in existing:
        address_doc = frappe.get_doc("Address", address)
        if location_url and getattr(address_doc, "custom_google_maps_url", None) == location_url:
            return address_doc.name
        if address_line1 and address_doc.address_line1 == address_line1:
            return address_doc.name

    doc = {
        "doctype": "Address",
        "address_title": frappe.db.get_value("Customer", customer, "customer_name") or customer,
        "address_type": "Shipping",
        "address_line1": address_line1 or _("Google Maps Location"),
        "city": data.get("city") or _("Unknown"),
        "pincode": data.get("postal_code"),
        "links": [{"link_doctype": "Customer", "link_name": customer}],
    }
    if frappe.get_meta("Address").has_field("custom_google_maps_url"):
        doc["custom_google_maps_url"] = location_url
    if frappe.get_meta("Address").has_field("custom_latitude"):
        doc["custom_latitude"] = latitude
    if frappe.get_meta("Address").has_field("custom_longitude"):
        doc["custom_longitude"] = longitude
    return frappe.get_doc(doc).insert(ignore_permissions=True).name


def _order_response(doc):
    detail = get_order_detail(doc.name)
    return {
        "order_id": doc.name,
        "order_number": doc.order_number,
        "status": doc.status,
        "order": detail,
    }


def _make_item(item):
    assert_required(item.get("item_code"), "Item code is required.")
    qty = to_float(item.get("qty")) or 1
    rate = to_float(item.get("rate"))
    return {
        "item_code": item.get("item_code"),
        "item_name": item.get("item_name") or frappe.db.get_value("Item", item.get("item_code"), "item_name"),
        "description": item.get("description"),
        "qty": qty,
        "rate": rate,
        "amount": to_float(item.get("amount")) or qty * rate,
        "product_category": item.get("product_category") or item.get("item_group"),
        "requires_work_order": item.get("requires_work_order") or 0,
    }


def _record_deposit(order, amount, data):
    from awamir_plus.api.delivery import _get_or_create_open_cash_closure, _recalculate_closure_totals

    cash_closure = _get_or_create_open_cash_closure(frappe.session.user, "branch_employee")
    frappe.get_doc(
        {
            "doctype": "Awamir Order Payment",
            "order": order.name,
            "customer": order.customer,
            "amount": amount,
            "payment_method": data.get("payment_method") or "Cash",
            "payment_reference": data.get("payment_reference"),
            "receipt_attachment": data.get("receipt_attachment"),
            "received_by_user": frappe.session.user,
            "received_by_role": "branch_employee",
            "cash_closure": cash_closure,
            "status": PAYMENT_STATUS_IN_DAILY_CLOSURE if cash_closure else PAYMENT_STATUS_RECORDED,
            "created_at": now_datetime(),
        }
    ).insert(ignore_permissions=True)
    if cash_closure:
        _recalculate_closure_totals(cash_closure)


def _get_branch_supervisors():
    return [
        row.parent
        for row in frappe.get_all("Has Role", filters={"role": ROLE_BRANCH_SUPERVISOR}, fields=["parent"])
        if not get_user_branch(row.parent) or get_user_branch(row.parent) == get_user_branch()
    ]


def _cancel_related_work_orders(order):
    if not frappe.db.exists("DocType", "Awamir Department Work Order"):
        return
    for work_order in frappe.get_all(
        "Awamir Department Work Order",
        filters={"order": order, "status": ["!=", DEPARTMENT_WORK_ORDER_STATUS_CANCELLED]},
        pluck="name",
    ):
        frappe.db.set_value(
            "Awamir Department Work Order",
            work_order,
            {
                "status": DEPARTMENT_WORK_ORDER_STATUS_CANCELLED,
                "notes": _("Cancelled with order {0}.").format(order),
            },
        )


@frappe.whitelist()
def get_my_orders(status=None, limit_start=0, limit_page_length=None):
    require_any_permissions([PERMISSION_ORDER_VIEW_OWN, PERMISSION_ORDER_VIEW_BRANCH])
    filters = {}
    if status:
        filters["status"] = status
    if not is_awamir_admin():
        filters["created_branch"] = get_user_branch()
        if has_permission(PERMISSION_ORDER_VIEW_OWN) and not has_permission(PERMISSION_ORDER_VIEW_BRANCH):
            filters["created_by_user"] = frappe.session.user
    orders = frappe.get_all(
        "Awamir Order Request",
        filters=filters,
        pluck="name",
        order_by="modified desc",
        **get_pagination(limit_start, limit_page_length),
    )
    return [get_order_detail(order) for order in orders]


@frappe.whitelist()
def get_order_detail(order):
    require_any_permissions(
        [
            PERMISSION_ORDER_VIEW_OWN,
            PERMISSION_ORDER_VIEW_BRANCH,
            PERMISSION_FULFILLMENT_VIEW_QUEUE,
            PERMISSION_WORK_ORDER_VIEW_DEPARTMENT,
            PERMISSION_DELIVERY_VIEW_ALL,
            PERMISSION_DELIVERY_VIEW_ASSIGNED,
            PERMISSION_CASHBOX_VIEW_OWN,
            PERMISSION_CASHBOX_VIEW_ALL,
            PERMISSION_ACCOUNTING_VIEW_FINANCIALS,
        ]
    )
    doc = frappe.get_doc("Awamir Order Request", order)
    user_production_department = get_user_production_department()
    production_scope = has_permission(PERMISSION_WORK_ORDER_VIEW_DEPARTMENT) and (
        doc.production_department == user_production_department
        or _has_department_work_order(doc.name, user_production_department)
    )
    driver_scope = (
        has_permission(PERMISSION_DELIVERY_VIEW_ASSIGNED)
        and doc.assigned_driver == frappe.session.user
    )
    if not is_awamir_admin() and not driver_scope and not production_scope:
        require_branch_scope(doc.created_branch)
    data = doc.as_dict()
    if doc.production_department:
        data["production_department_name"] = frappe.db.get_value(
            "Awamir Production Department",
            doc.production_department,
            "department_name",
        )
        data["production_department_code"] = frappe.db.get_value(
            "Awamir Production Department",
            doc.production_department,
            "department_code",
        )
    if doc.assigned_driver:
        driver = frappe.get_doc("User", doc.assigned_driver)
        data["assigned_driver_name"] = driver.full_name or doc.assigned_driver
        data["assigned_driver_phone"] = _user_phone(driver)
    data["erpnext_sales_order_docstatus"] = _linked_docstatus("Sales Order", doc.erpnext_sales_order)
    data["erpnext_work_order_docstatus"] = _linked_docstatus("Work Order", doc.erpnext_work_order)
    data["erpnext_sales_invoice_docstatus"] = _linked_docstatus("Sales Invoice", doc.erpnext_sales_invoice)
    data["status_logs"] = frappe.get_all("Awamir Order Status Log", filters={"order": doc.name}, fields=["*"], order_by="changed_at asc")
    data["payments"] = frappe.get_all("Awamir Order Payment", filters={"order": doc.name}, fields=["*"], order_by="created_at asc")
    for payment in data["payments"]:
        payment["erpnext_payment_entry_docstatus"] = _linked_docstatus(
            "Payment Entry",
            payment.get("erpnext_payment_entry"),
        )
    if frappe.db.exists("DocType", "Awamir Department Work Order"):
        data["department_work_orders"] = frappe.get_all(
            "Awamir Department Work Order",
            filters={"order": doc.name},
            fields=["*"],
            order_by="creation asc",
        )
    else:
        data["department_work_orders"] = []
    data["delivery_assignment"] = frappe.get_all("Awamir Delivery Assignment", filters={"order": doc.name}, fields=["*"], limit=1)
    for assignment in data["delivery_assignment"]:
        driver = frappe.get_doc("User", assignment.driver)
        assignment["driver_name"] = driver.full_name or assignment.driver
        assignment["driver_phone"] = _user_phone(driver)
    if frappe.db.exists("DocType", "Awamir Delivery Batch"):
        batch_names = frappe.get_all(
            "Awamir Delivery Batch Order",
            filters={"order": doc.name},
            pluck="parent",
        )
        if batch_names:
            from awamir_plus.services.delivery_batch import delivery_batch_response

            data["delivery_batches"] = [
                delivery_batch_response(batch_name)
                for batch_name in batch_names
            ]
            data["delivery_batches"].sort(key=lambda row: row.modified, reverse=True)
        else:
            data["delivery_batches"] = []
    else:
        data["delivery_batches"] = []
    return data


def _has_department_work_order(order, department):
    if not department or not frappe.db.exists("DocType", "Awamir Department Work Order"):
        return False
    return bool(
        frappe.db.exists(
            "Awamir Department Work Order",
            {"order": order, "department": department},
        )
    )


def _linked_docstatus(doctype, name):
    if not name:
        return None
    if not frappe.db.exists(doctype, name):
        return None
    return frappe.db.get_value(doctype, name, "docstatus")


def _user_phone(user_doc):
    return (getattr(user_doc, "mobile_no", None) or getattr(user_doc, "phone", None) or "").strip()


@frappe.whitelist()
def upload_order_attachment(order, file, file_type="Other", notes=None):
    require_permissions(PERMISSION_ORDER_CREATE)
    doc = frappe.get_doc("Awamir Order Request", order)
    require_branch_scope(doc.created_branch)
    doc.append("attachments", {"file": file, "file_type": file_type, "uploaded_by": frappe.session.user, "notes": notes})
    doc.save(ignore_permissions=True)
    return serialize_doc(doc)
