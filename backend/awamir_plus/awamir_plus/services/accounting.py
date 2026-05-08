import re

import frappe
from frappe import _

from awamir_plus.constants import (
    CLOSURE_STATUS_ACCEPTED,
    CLOSURE_STATUS_CLOSED,
    CLOSURE_STATUS_HAS_DIFFERENCE,
    ERP_SYNC_FAILED,
    ERP_SYNC_NOT_SYNCED,
    ERP_SYNC_PARTIALLY_SYNCED,
    ERP_SYNC_SYNCED,
    ORDER_STATUS_CANCELLED,
    ORDER_STATUS_DELIVERED,
    ORDER_STATUS_DRAFT,
    ORDER_STATUS_PENDING_APPROVAL,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_PICKUP,
    ORDER_STATUS_REJECTED,
    ORDER_STATUS_RETURNED,
    PAYMENT_STATUS_CASHIER_ACCEPTED,
    PAYMENT_STATUS_LINKED_TO_INVOICE,
    PAYMENT_STATUS_POSTED_TO_ERP,
    PAYMENT_STATUS_READY_FOR_ERP,
)
from awamir_plus.utils import create_notification, get_awamir_settings, get_pagination, make_status_log, now


BLOCKED_SALES_ORDER_STATUSES = {
    ORDER_STATUS_DRAFT,
    ORDER_STATUS_PENDING_APPROVAL,
    ORDER_STATUS_RETURNED,
    ORDER_STATUS_REJECTED,
    ORDER_STATUS_CANCELLED,
}
BLOCKED_INVOICE_STATUSES = {ORDER_STATUS_REJECTED, ORDER_STATUS_CANCELLED}
INVOICE_READY_STATUSES = {
    ORDER_STATUS_READY_FOR_PICKUP,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_DELIVERED,
}
POSTABLE_PAYMENT_STATUSES = {
    PAYMENT_STATUS_CASHIER_ACCEPTED,
    PAYMENT_STATUS_READY_FOR_ERP,
}
ACCEPTED_CLOSURE_STATUSES = {
    CLOSURE_STATUS_ACCEPTED,
    CLOSURE_STATUS_CLOSED,
    CLOSURE_STATUS_HAS_DIFFERENCE,
}
MODE_OF_PAYMENT_LABELS = {
    "Cash": ["Cash", "نقدي"],
    "Card": ["Credit Card", "Card", "شبكة"],
    "Transfer": ["Bank Transfer", "Transfer", "تحويل"],
    "Other": ["Other", "أخرى"],
}


def create_customer_if_missing(order):
    if order.customer:
        if hasattr(order, "erpnext_customer_id"):
            order.erpnext_customer_id = order.customer
            order.save(ignore_permissions=True)
        return order.customer

    customer = None
    if order.customer_phone:
        customer = frappe.db.get_value("Customer", {"mobile_no": order.customer_phone}, "name")

    if not customer:
        customer_doc = frappe.get_doc(
            {
                "doctype": "Customer",
                "customer_name": order.customer_name or order.company_name or order.customer_phone,
                "customer_type": "Company" if order.customer_type == "Company" else "Individual",
                "mobile_no": order.customer_phone,
                "tax_id": order.tax_id,
            }
        )
        _insert_with_system_permissions(customer_doc)
        customer = customer_doc.name

    order.customer = customer
    if hasattr(order, "erpnext_customer_id"):
        order.erpnext_customer_id = customer
    order.save(ignore_permissions=True)
    return customer


def create_sales_order_for_order(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    if order.erpnext_sales_order:
        return _order_action_response(order, _("Sales Order already exists."))

    if order.status in BLOCKED_SALES_ORDER_STATUSES:
        _mark_order_sync_failed(order, _("لا يمكن إنشاء Sales Order للطلب بالحالة {0}.").format(order.status))

    if not order.items:
        _mark_order_sync_failed(order, _("لا يمكن إنشاء Sales Order لأن الطلب لا يحتوي منتجات."))

    settings = _validated_settings(["default_company", "default_price_list", "default_warehouse", "default_currency"])
    customer = create_customer_if_missing(order)

    try:
        sales_order = frappe.get_doc(
            {
                "doctype": "Sales Order",
                "customer": customer,
                "company": settings.default_company,
                "currency": settings.default_currency,
                "selling_price_list": settings.default_price_list,
                "delivery_date": order.required_date,
                "transaction_date": frappe.utils.today(),
                "items": _sales_order_items(order, settings),
            }
        )
        _insert_with_system_permissions(sales_order)
        _maybe_submit(sales_order, settings, "submit_sales_order", order, _("تعذر اعتماد Sales Order: {0}"))
    except Exception as exc:
        _mark_order_sync_failed(order, _("تعذر إنشاء Sales Order: {0}").format(_clean_error(exc)))

    order.erpnext_sales_order = sales_order.name
    _mark_order_partially_synced(order)
    make_status_log(order.name, order.status, order.status, _("Sales Order created: {0}").format(sales_order.name))
    create_notification(
        order.created_by_user,
        _("Sales Order Created"),
        _("Sales Order {0} created for order {1}.").format(sales_order.name, order.order_number),
        order.name,
        "sales_order_created",
    )
    return _order_action_response(order, _("Sales Order created."))


def create_work_order_for_order(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    if order.erpnext_work_order:
        return _order_action_response(order, _("Work Order already exists."))

    if not order.erpnext_sales_order:
        _mark_order_sync_failed(order, _("لا يمكن إنشاء Work Order قبل وجود Sales Order."))

    required_items = [row for row in order.items if frappe.utils.cint(row.requires_work_order)]
    if not required_items:
        return _order_action_response(order, _("This order does not require a Work Order."))

    settings = _validated_settings(["default_company"])
    item = required_items[0]
    bom = frappe.db.get_value(
        "BOM",
        {"item": item.item_code, "is_active": 1, "is_default": 1},
        "name",
    )
    if not bom:
        _mark_order_sync_failed(order, _("لا يمكن إنشاء Work Order لأن المنتج لا يحتوي BOM"))

    try:
        work_order = frappe.get_doc(
            {
                "doctype": "Work Order",
                "production_item": item.item_code,
                "bom_no": bom,
                "qty": item.qty,
                "sales_order": order.erpnext_sales_order,
                "company": settings.default_company,
            }
        )
        _insert_with_system_permissions(work_order)
        _maybe_submit(work_order, settings, "submit_work_order", order, _("تعذر اعتماد Work Order: {0}"))
    except Exception as exc:
        _mark_order_sync_failed(order, _("تعذر إنشاء Work Order: {0}").format(_clean_error(exc)))

    order.erpnext_work_order = work_order.name
    _mark_order_partially_synced(order)
    make_status_log(order.name, order.status, order.status, _("Work Order created: {0}").format(work_order.name))
    create_notification(
        order.created_by_user,
        _("Work Order Created"),
        _("Work Order {0} created for order {1}.").format(work_order.name, order.order_number),
        order.name,
        "work_order_created",
    )
    return _order_action_response(order, _("Work Order created."))


def create_payment_entry_for_payment(payment_name):
    payment = frappe.get_doc("Awamir Order Payment", payment_name)
    if payment.erpnext_payment_entry:
        return _payment_action_response(payment, _("Payment Entry already exists."))

    if payment.status not in POSTABLE_PAYMENT_STATUSES:
        _mark_payment_sync_failed(payment, _("لا يمكن ترحيل الدفعة قبل قبول العهدة من أمين الصندوق."))

    _assert_payment_closure_is_accepted(payment)

    order = frappe.get_doc("Awamir Order Request", payment.order)
    if order.status in BLOCKED_SALES_ORDER_STATUSES:
        _mark_payment_sync_failed(
            payment,
            _("لا يمكن ترحيل دفعة لطلب بالحالة {0}.").format(order.status),
        )
    settings = _validated_settings(["default_company", "default_currency"])
    customer = create_customer_if_missing(order)
    mode_of_payment = _get_or_create_mode_of_payment(payment.payment_method, settings)
    paid_to = _get_paid_to_account(mode_of_payment, payment.payment_method, settings)
    paid_from = _get_receivable_account(customer, settings.default_company)

    references = []
    if order.erpnext_sales_order and frappe.db.get_value("Sales Order", order.erpnext_sales_order, "docstatus") == 1:
        references.append(
            {
                "reference_doctype": "Sales Order",
                "reference_name": order.erpnext_sales_order,
                "allocated_amount": payment.amount,
            }
        )

    try:
        payment_entry = frappe.get_doc(
            {
                "doctype": "Payment Entry",
                "payment_type": "Receive",
                "party_type": "Customer",
                "party": customer,
                "company": settings.default_company,
                "posting_date": frappe.utils.today(),
                "mode_of_payment": mode_of_payment,
                "paid_from": paid_from,
                "paid_to": paid_to,
                "paid_amount": payment.amount,
                "received_amount": payment.amount,
                "reference_no": payment.payment_reference or payment.name,
                "reference_date": frappe.utils.today(),
                "references": references,
            }
        )
        _insert_with_system_permissions(payment_entry)
        _maybe_submit(payment_entry, settings, "submit_payment_entry", order, _("تعذر اعتماد Payment Entry: {0}"))
    except Exception as exc:
        _mark_payment_sync_failed(payment, _("تعذر إنشاء Payment Entry: {0}").format(_clean_error(exc)))

    frappe.db.set_value(
        "Awamir Order Payment",
        payment.name,
        {
            "erpnext_payment_entry": payment_entry.name,
            "status": PAYMENT_STATUS_POSTED_TO_ERP,
        },
    )
    payment.reload()

    _mark_order_partially_synced(order)
    make_status_log(order.name, order.status, order.status, _("Payment Entry created: {0}").format(payment_entry.name))
    create_notification(
        order.created_by_user,
        _("Payment Posted"),
        _("Payment {0} posted to ERPNext.").format(payment_entry.name),
        order.name,
        "payment_entry_posted",
    )
    return _payment_action_response(payment, _("Payment Entry created."))


def post_accepted_payments_to_erpnext(closure=None, order=None):
    filters = {"status": ["in", list(POSTABLE_PAYMENT_STATUSES)]}
    if closure:
        filters["cash_closure"] = closure
    if order:
        filters["order"] = order

    payments = frappe.get_all("Awamir Order Payment", filters=filters, pluck="name", order_by="created_at asc")
    return [create_payment_entry_for_payment(payment)["payment"] for payment in payments]


def create_sales_invoice_for_order(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    if order.erpnext_sales_invoice:
        return _invoice_action_response(order, _("Sales Invoice already exists."))

    if not order.erpnext_sales_order:
        _mark_order_sync_failed(order, _("لا يمكن إنشاء Sales Invoice قبل وجود Sales Order."))

    if order.status in BLOCKED_INVOICE_STATUSES:
        _mark_order_sync_failed(order, _("لا يمكن إنشاء Sales Invoice للطلب بالحالة {0}.").format(order.status))

    settings = _validated_settings(["default_company", "default_price_list", "default_currency"])
    if frappe.utils.cint(settings.create_invoice_on_delivery) and order.status != ORDER_STATUS_DELIVERED:
        _mark_order_sync_failed(order, _("حسب الإعدادات الحالية، لا يمكن إنشاء Sales Invoice إلا بعد التسليم."))
    if not frappe.utils.cint(settings.create_invoice_on_delivery) and order.status not in INVOICE_READY_STATUSES:
        _mark_order_sync_failed(order, _("لا يمكن إنشاء Sales Invoice إلا للطلبات الجاهزة أو المسلّمة."))

    try:
        invoice = frappe.get_doc(
            {
                "doctype": "Sales Invoice",
                "customer": create_customer_if_missing(order),
                "company": settings.default_company,
                "currency": settings.default_currency,
                "selling_price_list": settings.default_price_list,
                "posting_date": frappe.utils.today(),
                "due_date": frappe.utils.today(),
                "items": _sales_invoice_items(order),
                "advances": _sales_invoice_advances(order),
            }
        )
        _insert_with_system_permissions(invoice)
        _maybe_submit(invoice, settings, "submit_sales_invoice", order, _("تعذر اعتماد Sales Invoice: {0}"))
    except Exception as exc:
        _mark_order_sync_failed(order, _("تعذر إنشاء Sales Invoice: {0}").format(_clean_error(exc)))

    order.erpnext_sales_invoice = invoice.name
    _mark_order_partially_synced(order)
    make_status_log(order.name, order.status, order.status, _("Sales Invoice created: {0}").format(invoice.name))
    create_notification(
        order.created_by_user,
        _("Sales Invoice Created"),
        _("Sales Invoice {0} created for order {1}.").format(invoice.name, order.order_number),
        order.name,
        "sales_invoice_created",
    )
    return _invoice_action_response(order, _("Sales Invoice created."))


def allocate_advance_payment_to_invoice(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    if not order.erpnext_sales_invoice:
        _mark_order_sync_failed(order, _("لا يمكن ربط الدفعات قبل وجود Sales Invoice."))

    payments = frappe.get_all(
        "Awamir Order Payment",
        filters={"order": order.name, "status": PAYMENT_STATUS_POSTED_TO_ERP},
        fields=["name", "amount", "erpnext_payment_entry"],
        order_by="created_at asc",
    )
    existing_linked = frappe.get_all(
        "Awamir Order Payment",
        filters={"order": order.name, "status": PAYMENT_STATUS_LINKED_TO_INVOICE},
        fields=["name", "amount", "erpnext_payment_entry"],
        order_by="created_at asc",
    )
    invoice = frappe.get_doc("Sales Invoice", order.erpnext_sales_invoice)
    invoice_total = frappe.utils.flt(invoice.get("grand_total") or order.total_amount)

    if not payments:
        if existing_linked:
            return {
                "order": _serialize_order(order.name),
                "allocations": _allocation_rows(order, existing_linked, invoice_total),
            }
        _mark_order_sync_failed(order, _("لا توجد دفعات مرحلة إلى ERPNext قابلة للربط."))

    already_linked = frappe.utils.flt(
        frappe.db.sql(
            """
            select sum(amount)
            from `tabAwamir Order Payment`
            where `order`=%s and status=%s
            """,
            (order.name, PAYMENT_STATUS_LINKED_TO_INVOICE),
        )[0][0]
    )
    remaining_to_allocate = max(invoice_total - already_linked, 0)
    allocations = []

    for payment in payments:
        if remaining_to_allocate <= 0:
            break
        amount = min(frappe.utils.flt(payment.amount), remaining_to_allocate)
        if amount <= 0:
            continue
        erp_link_status = _link_payment_entry_to_invoice(payment.erpnext_payment_entry, order.erpnext_sales_invoice, amount)
        frappe.db.set_value("Awamir Order Payment", payment.name, "status", PAYMENT_STATUS_LINKED_TO_INVOICE)
        allocations.append(
            {
                "id": "{0}-{1}".format(payment.name, order.erpnext_sales_invoice),
                "order_id": order.name,
                "payment_id": payment.name,
                "sales_invoice_id": order.erpnext_sales_invoice,
                "payment_entry_id": payment.erpnext_payment_entry,
                "allocated_amount": amount,
                "allocated_at": now(),
                "status": "allocated",
                "erp_link_status": erp_link_status,
            }
        )
        remaining_to_allocate -= amount

    if not allocations:
        if existing_linked:
            return {
                "order": _serialize_order(order.name),
                "allocations": _allocation_rows(order, existing_linked, invoice_total),
            }
        else:
            _mark_order_sync_failed(order, _("لا توجد دفعات مرحلة غير مربوطة."))

    allocated_total = already_linked + sum(frappe.utils.flt(item["allocated_amount"]) for item in allocations)
    order.remaining_amount = max(invoice_total - allocated_total, 0)
    order.erp_sync_status = ERP_SYNC_SYNCED if order.remaining_amount == 0 else ERP_SYNC_PARTIALLY_SYNCED
    order.erp_sync_error = None
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    make_status_log(order.name, order.status, order.status, _("Advance payments allocated to invoice {0}.").format(order.erpnext_sales_invoice))
    create_notification(
        order.created_by_user,
        _("Advance Allocated"),
        _("Advance payments allocated to invoice {0}.").format(order.erpnext_sales_invoice),
        order.name,
        "advance_payment_allocated",
    )
    return {"order": _serialize_order(order.name), "allocations": allocations}


def _allocation_rows(order, payments, invoice_total):
    remaining = frappe.utils.flt(invoice_total)
    rows = []
    for payment in payments:
        if remaining <= 0:
            break
        amount = min(frappe.utils.flt(payment.amount), remaining)
        rows.append(
            {
                "id": "{0}-{1}".format(payment.name, order.erpnext_sales_invoice),
                "order_id": order.name,
                "payment_id": payment.name,
                "sales_invoice_id": order.erpnext_sales_invoice,
                "payment_entry_id": payment.erpnext_payment_entry,
                "allocated_amount": amount,
                "allocated_at": now(),
                "status": "allocated",
                "erp_link_status": "recorded_previously",
            }
        )
        remaining -= amount
    return rows


def get_orders_needing_sales_order(limit_start=0, limit_page_length=None):
    orders = frappe.get_all(
        "Awamir Order Request",
        filters={
            "status": ["not in", list(BLOCKED_SALES_ORDER_STATUSES)],
            "erpnext_sales_order": ["in", ("", None)],
        },
        pluck="name",
        order_by="modified desc",
        **get_pagination(limit_start, limit_page_length),
    )
    return [_serialize_order(order) for order in orders if frappe.db.count("Awamir Order Request Item", {"parent": order})]


def get_payments_ready_for_erp_posting(limit_start=0, limit_page_length=None):
    rows = frappe.get_all(
        "Awamir Order Payment",
        filters={"status": ["in", list(POSTABLE_PAYMENT_STATUSES)]},
        fields=["name", "order", "cash_closure"],
        order_by="created_at asc",
        **get_pagination(limit_start, limit_page_length),
    )
    payments = []
    for row in rows:
        if not row.cash_closure:
            continue
        order_status = frappe.db.get_value("Awamir Order Request", row.order, "status")
        if order_status in BLOCKED_SALES_ORDER_STATUSES:
            continue
        closure_status = frappe.db.get_value("Awamir Daily Cash Closure", row.cash_closure, "status")
        if closure_status in ACCEPTED_CLOSURE_STATUSES:
            payments.append(_serialize_payment(row.name))
    return payments


def get_orders_needing_sales_invoice(limit_start=0, limit_page_length=None):
    filters = {
        "erpnext_sales_order": ["not in", ("", None)],
        "erpnext_sales_invoice": ["in", ("", None)],
        "status": ["not in", list(BLOCKED_INVOICE_STATUSES)],
    }
    orders = frappe.get_all(
        "Awamir Order Request",
        filters=filters,
        pluck="name",
        order_by="modified desc",
        **get_pagination(limit_start, limit_page_length),
    )
    return [_serialize_order(order) for order in orders if _invoice_status_is_allowed(frappe.get_doc("Awamir Order Request", order))]


def get_invoices_needing_advance_allocation(limit_start=0, limit_page_length=None):
    orders = frappe.get_all(
        "Awamir Order Request",
        filters={"erpnext_sales_invoice": ["not in", ("", None)]},
        pluck="name",
        order_by="modified desc",
        **get_pagination(limit_start, limit_page_length),
    )
    result = []
    for order in orders:
        if frappe.db.exists("Awamir Order Payment", {"order": order, "status": PAYMENT_STATUS_POSTED_TO_ERP}):
            result.append(_serialize_order(order))
    return result


def get_accounting_sync_errors(limit_start=0, limit_page_length=None):
    orders = frappe.get_all(
        "Awamir Order Request",
        filters={"erp_sync_status": ERP_SYNC_FAILED},
        pluck="name",
        order_by="modified desc",
        **get_pagination(limit_start, limit_page_length),
    )
    return [_serialize_order(order) for order in orders]


def get_customer_invoices(customer):
    return frappe.get_all(
        "Sales Invoice",
        filters={"customer": customer},
        fields=["name", "posting_date", "grand_total", "outstanding_amount", "status"],
        order_by="posting_date desc",
    )


def sync_order_accounting_status(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    linked_payments = frappe.db.count("Awamir Order Payment", {"order": order.name, "status": PAYMENT_STATUS_LINKED_TO_INVOICE})
    posted_payments = frappe.db.count("Awamir Order Payment", {"order": order.name, "status": PAYMENT_STATUS_POSTED_TO_ERP})
    if order.erpnext_sales_order and order.erpnext_sales_invoice and linked_payments and frappe.utils.flt(order.remaining_amount) == 0:
        order.erp_sync_status = ERP_SYNC_SYNCED
    elif order.erpnext_sales_order or order.erpnext_sales_invoice or posted_payments or linked_payments:
        order.erp_sync_status = ERP_SYNC_PARTIALLY_SYNCED
    else:
        order.erp_sync_status = ERP_SYNC_NOT_SYNCED
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    return _order_action_response(order, _("Accounting status synced."))


def _validated_settings(required_fields):
    settings = get_awamir_settings()
    missing = [field for field in required_fields if not getattr(settings, field, None)]
    if missing:
        frappe.throw(_("إعدادات Awamir App Settings ناقصة للحقول المحاسبية التالية: {0}").format(", ".join(missing)))
    return settings


def _maybe_submit(doc, settings, setting_field, order, error_template):
    if not frappe.utils.cint(getattr(settings, setting_field, 0)):
        return
    try:
        previous = getattr(frappe.flags, "ignore_permissions", False)
        previous_user = frappe.session.user
        frappe.flags.ignore_permissions = True
        _set_local_session_user("Administrator")
        try:
            doc.submit()
        finally:
            frappe.flags.ignore_permissions = previous
            _set_local_session_user(previous_user)
    except Exception as exc:
        _mark_order_sync_failed(order, error_template.format(_clean_error(exc)))


def _insert_with_system_permissions(doc):
    previous = getattr(frappe.flags, "ignore_permissions", False)
    previous_user = frappe.session.user
    frappe.flags.ignore_permissions = True
    _set_local_session_user("Administrator")
    try:
        return doc.insert(ignore_permissions=True)
    finally:
        frappe.flags.ignore_permissions = previous
        _set_local_session_user(previous_user)


def _set_local_session_user(user):
    if getattr(frappe.local, "session", None):
        frappe.local.session.user = user


def _sales_order_item(row, settings):
    return {
        "item_code": row.item_code,
        "item_name": row.item_name,
        "description": row.description,
        "qty": row.qty,
        "rate": row.rate,
        "amount": row.amount,
        "warehouse": settings.default_warehouse,
    }


def _sales_order_items(order, settings):
    items = [_sales_order_item(row, settings) for row in order.items]
    delivery_fee_item = _delivery_fee_item(order, settings=settings)
    if delivery_fee_item:
        items.append(delivery_fee_item)
    return items


def _sales_invoice_item(row, order):
    return {
        "item_code": row.item_code,
        "item_name": row.item_name,
        "description": row.description,
        "qty": row.qty,
        "rate": row.rate,
        "amount": row.amount,
        "sales_order": order.erpnext_sales_order,
    }


def _sales_invoice_items(order):
    items = [_sales_invoice_item(row, order) for row in order.items]
    delivery_fee_item = _delivery_fee_item(order)
    if delivery_fee_item:
        delivery_fee_item["sales_order"] = order.erpnext_sales_order
        items.append(delivery_fee_item)
    return items


def _sales_invoice_advances(order):
    invoice_total = frappe.utils.flt(order.total_amount) + frappe.utils.flt(order.delivery_fee)
    if invoice_total <= 0:
        return []

    rows = []
    remaining = invoice_total
    payments = frappe.get_all(
        "Awamir Order Payment",
        filters={
            "order": order.name,
            "status": ["in", [PAYMENT_STATUS_POSTED_TO_ERP, PAYMENT_STATUS_LINKED_TO_INVOICE]],
        },
        fields=["name", "amount", "erpnext_payment_entry"],
        order_by="created_at asc",
    )
    for payment in payments:
        if remaining <= 0:
            break
        if not payment.erpnext_payment_entry:
            continue
        reference_row = _payment_entry_sales_order_reference_row(
            payment.erpnext_payment_entry,
            order.erpnext_sales_order,
        )
        if not reference_row:
            continue
        allocated_amount = min(frappe.utils.flt(payment.amount), remaining)
        if allocated_amount <= 0:
            continue
        rows.append(
            {
                "reference_type": "Payment Entry",
                "reference_name": payment.erpnext_payment_entry,
                "reference_row": reference_row,
                "remarks": _("Advance payment for Awamir order {0}").format(order.order_number),
                "advance_amount": frappe.utils.flt(payment.amount),
                "allocated_amount": allocated_amount,
                "ref_exchange_rate": 1,
            }
        )
        remaining -= allocated_amount
    return rows


def _payment_entry_sales_order_reference_row(payment_entry_name, sales_order):
    if not payment_entry_name:
        return None
    if frappe.db.get_value("Payment Entry", payment_entry_name, "docstatus") != 1:
        return None
    if not sales_order:
        return None
    return frappe.db.get_value(
        "Payment Entry Reference",
        {
            "parent": payment_entry_name,
            "reference_doctype": "Sales Order",
            "reference_name": sales_order,
        },
        "name",
    )


def _delivery_fee_item(order, settings=None):
    delivery_fee = frappe.utils.flt(order.delivery_fee)
    if delivery_fee <= 0:
        return None
    item_code = _get_or_create_delivery_fee_item()
    item = {
        "item_code": item_code,
        "item_name": _("Delivery Fee"),
        "description": _("Delivery Fee for Awamir order {0}").format(order.order_number),
        "qty": 1,
        "rate": delivery_fee,
        "amount": delivery_fee,
    }
    if settings and getattr(settings, "default_warehouse", None):
        item["warehouse"] = settings.default_warehouse
    return item


def _get_or_create_delivery_fee_item():
    item_code = "AWAMIR-DELIVERY-FEE"
    if frappe.db.exists("Item", item_code):
        return item_code

    item_group = "Services" if frappe.db.exists("Item Group", "Services") else "All Item Groups"
    item = frappe.get_doc(
        {
            "doctype": "Item",
            "item_code": item_code,
            "item_name": _("Delivery Fee"),
            "item_group": item_group,
            "stock_uom": "Nos",
            "is_stock_item": 0,
            "include_item_in_manufacturing": 0,
            "disabled": 0,
        }
    )
    _insert_with_system_permissions(item)
    return item_code


def _get_or_create_mode_of_payment(payment_method, settings):
    labels = MODE_OF_PAYMENT_LABELS.get(payment_method) or [payment_method]
    for label in labels:
        if frappe.db.exists("Mode of Payment", label):
            return label

    default_label = labels[0]
    account = _preferred_payment_account(payment_method, settings)
    if not account:
        frappe.throw(_("لا يوجد حساب افتراضي لطريقة الدفع {0}.").format(payment_method))

    mode = frappe.get_doc({"doctype": "Mode of Payment", "mode_of_payment": default_label})
    if mode.meta.has_field("type"):
        mode.type = "Cash" if payment_method in ("Cash", "Other") else "Bank"
    if mode.meta.has_field("accounts"):
        mode.append("accounts", {"company": settings.default_company, "default_account": account})
        _insert_with_system_permissions(mode)
    return mode.name


def _get_paid_to_account(mode_of_payment, payment_method, settings):
    account = frappe.db.get_value(
        "Mode of Payment Account",
        {"parent": mode_of_payment, "company": settings.default_company},
        "default_account",
    )
    if account:
        return account
    account = _preferred_payment_account(payment_method, settings)
    if account:
        return account
    frappe.throw(_("لا يوجد حساب افتراضي لطريقة الدفع {0}.").format(mode_of_payment))


def _preferred_payment_account(payment_method, settings):
    company = frappe.get_doc("Company", settings.default_company)
    if payment_method in ("Card", "Transfer"):
        return company.get("default_bank_account") or company.get("default_cash_account")
    return company.get("default_cash_account") or company.get("default_bank_account")


def _get_receivable_account(customer, company):
    try:
        from erpnext.accounts.party import get_party_account

        account = get_party_account("Customer", customer, company)
        if account:
            return account
    except Exception:
        pass
    account = frappe.db.get_value("Company", company, "default_receivable_account")
    if account:
        return account
    frappe.throw(_("لا يوجد حساب ذمم مدينة للعميل {0}.").format(customer))


def _assert_payment_closure_is_accepted(payment):
    if not payment.cash_closure:
        _mark_payment_sync_failed(payment, _("الدفعة غير مرتبطة بعهدة يومية."))
    closure_status = frappe.db.get_value("Awamir Daily Cash Closure", payment.cash_closure, "status")
    if closure_status not in ACCEPTED_CLOSURE_STATUSES:
        _mark_payment_sync_failed(payment, _("لا يمكن ترحيل الدفعة قبل قبول العهدة اليومية."))


def _invoice_status_is_allowed(order):
    settings = get_awamir_settings()
    if frappe.utils.cint(settings.create_invoice_on_delivery):
        return order.status == ORDER_STATUS_DELIVERED
    return order.status in INVOICE_READY_STATUSES


def _link_payment_entry_to_invoice(payment_entry_name, sales_invoice, amount):
    if not payment_entry_name:
        frappe.throw(_("الدفعة المرحلة لا تحتوي رقم Payment Entry من ERPNext."))
    if frappe.db.get_value("Sales Invoice", sales_invoice, "docstatus") != 1:
        return "invoice_not_submitted"
    invoice = frappe.get_doc("Sales Invoice", sales_invoice)
    for advance in invoice.get("advances") or []:
        if advance.reference_type == "Payment Entry" and advance.reference_name == payment_entry_name:
            return "linked_in_sales_invoice_advances"
    payment_entry = frappe.get_doc("Payment Entry", payment_entry_name)
    for reference in payment_entry.references:
        if reference.reference_doctype == "Sales Invoice" and reference.reference_name == sales_invoice:
            return "already_linked_to_invoice"
    if payment_entry.docstatus == 1:
        return "deferred_submitted_payment_entry"
    payment_entry.append(
        "references",
        {
            "reference_doctype": "Sales Invoice",
            "reference_name": sales_invoice,
            "allocated_amount": amount,
        },
    )
    payment_entry.save(ignore_permissions=True)
    return "linked_to_invoice"


def _mark_order_partially_synced(order):
    order.erp_sync_status = ERP_SYNC_PARTIALLY_SYNCED
    order.erp_sync_error = None
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)


def _mark_order_sync_failed(order, message):
    order.erp_sync_status = ERP_SYNC_FAILED
    order.erp_sync_error = message
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    create_notification(order.created_by_user, _("ERPNext Sync Failed"), message, order.name, "erp_sync_failed")
    frappe.throw(message)


def _mark_payment_sync_failed(payment, message):
    order = frappe.get_doc("Awamir Order Request", payment.order)
    order.erp_sync_status = ERP_SYNC_FAILED
    order.erp_sync_error = message
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    create_notification(order.created_by_user, _("ERPNext Payment Failed"), message, order.name, "payment_entry_failed")
    frappe.throw(message)


def _order_action_response(order, message):
    if isinstance(order, str):
        order = frappe.get_doc("Awamir Order Request", order)
    return {
        "order_id": order.name,
        "order_number": order.order_number,
        "status": order.status,
        "sales_order": order.erpnext_sales_order,
        "work_order": order.erpnext_work_order,
        "sales_invoice": order.erpnext_sales_invoice,
        "message": message,
        "order": _serialize_order(order.name),
    }


def _invoice_action_response(order, message):
    response = _order_action_response(order, message)
    invoice = frappe.get_doc("Sales Invoice", order.erpnext_sales_invoice)
    response.update(
        {
            "sales_invoice": invoice.name,
            "grand_total": invoice.grand_total,
            "outstanding_amount": invoice.outstanding_amount,
        }
    )
    return response


def _payment_action_response(payment, message):
    if isinstance(payment, str):
        payment = frappe.get_doc("Awamir Order Payment", payment)
    return {
        "payment_id": payment.name,
        "payment_entry": payment.erpnext_payment_entry,
        "status": payment.status,
        "message": message,
        "payment": _serialize_payment(payment.name),
    }


def _serialize_order(order_name):
    from awamir_plus.api.orders import get_order_detail

    return get_order_detail(order_name)


def _serialize_payment(payment_name):
    payment = frappe.get_doc("Awamir Order Payment", payment_name).as_dict()
    payment["order_number"] = frappe.db.get_value("Awamir Order Request", payment.order, "order_number")
    payment["customer_name"] = frappe.db.get_value("Customer", payment.customer, "customer_name") if payment.customer else None
    payment["erpnext_payment_entry_docstatus"] = (
        frappe.db.get_value("Payment Entry", payment.erpnext_payment_entry, "docstatus")
        if payment.erpnext_payment_entry and frappe.db.exists("Payment Entry", payment.erpnext_payment_entry)
        else None
    )
    return payment


def _clean_error(error):
    if isinstance(error, frappe.PermissionError):
        return _("لا توجد صلاحية كافية لإنشاء مستند ERPNext من داخل عملية المحاسبة. تحقق من صلاحيات الدور أو نفذ العملية كمدير نظام.")
    text = frappe.as_unicode(error)
    return re.sub(r"<[^>]*>", "", text).strip()
