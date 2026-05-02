import frappe
from frappe import _

from awamir_plus.constants import (
    ERP_SYNC_FAILED,
    ERP_SYNC_PARTIALLY_SYNCED,
    ERP_SYNC_SYNCED,
    ORDER_STATUS_DRAFT,
    ORDER_STATUS_PENDING_APPROVAL,
    ORDER_STATUS_REJECTED,
    ORDER_STATUS_RETURNED,
    PAYMENT_STATUS_CASHIER_ACCEPTED,
    PAYMENT_STATUS_LINKED_TO_INVOICE,
    PAYMENT_STATUS_POSTED_TO_ERP,
    PAYMENT_STATUS_READY_FOR_ERP,
)
from awamir_plus.utils import create_notification, get_awamir_settings, make_status_log, now


BLOCKED_SALES_ORDER_STATUSES = {
    ORDER_STATUS_DRAFT,
    ORDER_STATUS_PENDING_APPROVAL,
    ORDER_STATUS_RETURNED,
    ORDER_STATUS_REJECTED,
}


def create_customer_if_missing(order):
    if order.customer:
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
        customer_doc.insert(ignore_permissions=True)
        customer = customer_doc.name

    order.customer = customer
    order.erpnext_customer_id = customer
    order.save(ignore_permissions=True)
    return customer


def create_sales_order_for_order(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    if order.erpnext_sales_order:
        return order.erpnext_sales_order
    if order.status in BLOCKED_SALES_ORDER_STATUSES:
        _mark_order_sync_failed(order, _("Sales Order cannot be created for status {0}.").format(order.status))

    customer = create_customer_if_missing(order)
    settings = get_awamir_settings()

    sales_order = frappe.get_doc(
        {
            "doctype": "Sales Order",
            "customer": customer,
            "company": settings.default_company,
            "currency": settings.default_currency,
            "selling_price_list": settings.default_price_list,
            "delivery_date": order.required_date,
            "transaction_date": frappe.utils.today(),
            "items": [
                {
                    "item_code": item.item_code,
                    "item_name": item.item_name,
                    "description": item.description,
                    "qty": item.qty,
                    "rate": item.rate,
                    "amount": item.amount,
                    "warehouse": settings.default_warehouse,
                }
                for item in order.items
            ],
        }
    )
    sales_order.insert(ignore_permissions=True)

    order.erpnext_sales_order = sales_order.name
    order.erp_sync_status = ERP_SYNC_PARTIALLY_SYNCED
    order.erp_sync_error = None
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    make_status_log(order.name, order.status, order.status, _("Sales Order created: {0}").format(sales_order.name))
    create_notification(order.created_by_user, _("Sales Order Created"), _("Sales Order {0} created for order {1}.").format(sales_order.name, order.order_number), order.name, "sales_order_created")
    return sales_order.name


def create_work_order_for_order(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    if order.erpnext_work_order:
        return order.erpnext_work_order
    if not order.erpnext_sales_order:
        _mark_order_sync_failed(order, _("Work Order requires an existing Sales Order."))
    if not any(item.requires_work_order for item in order.items):
        return None

    item = next(row for row in order.items if row.requires_work_order)
    work_order = frappe.get_doc(
        {
            "doctype": "Work Order",
            "production_item": item.item_code,
            "qty": item.qty,
            "sales_order": order.erpnext_sales_order,
            "company": get_awamir_settings().default_company,
        }
    )
    work_order.insert(ignore_permissions=True)

    order.erpnext_work_order = work_order.name
    order.erp_sync_status = ERP_SYNC_PARTIALLY_SYNCED
    order.erp_sync_error = None
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    make_status_log(order.name, order.status, order.status, _("Work Order created: {0}").format(work_order.name))
    create_notification(order.created_by_user, _("Work Order Created"), _("Work Order {0} created for order {1}.").format(work_order.name, order.order_number), order.name, "work_order_created")
    return work_order.name


def create_payment_entry_for_payment(payment_name):
    payment = frappe.get_doc("Awamir Order Payment", payment_name)
    if payment.erpnext_payment_entry:
        return payment.erpnext_payment_entry
    if payment.status not in (PAYMENT_STATUS_CASHIER_ACCEPTED, PAYMENT_STATUS_READY_FOR_ERP):
        _mark_payment_sync_failed(payment, _("Payment must be cashier accepted before ERPNext posting."))

    order = frappe.get_doc("Awamir Order Request", payment.order)
    customer = create_customer_if_missing(order)

    payment_entry = frappe.get_doc(
        {
            "doctype": "Payment Entry",
            "payment_type": "Receive",
            "party_type": "Customer",
            "party": customer,
            "posting_date": frappe.utils.today(),
            "mode_of_payment": payment.payment_method,
            "paid_amount": payment.amount,
            "received_amount": payment.amount,
            "reference_no": payment.payment_reference,
            "reference_date": frappe.utils.today(),
            "references": [
                {
                    "reference_doctype": "Sales Order",
                    "reference_name": order.erpnext_sales_order,
                    "allocated_amount": payment.amount,
                }
            ]
            if order.erpnext_sales_order
            else [],
        }
    )
    payment_entry.insert(ignore_permissions=True)

    payment.erpnext_payment_entry = payment_entry.name
    payment.status = PAYMENT_STATUS_POSTED_TO_ERP
    payment.save(ignore_permissions=True)

    order.erp_sync_status = ERP_SYNC_PARTIALLY_SYNCED
    order.erp_sync_error = None
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    make_status_log(order.name, order.status, order.status, _("Payment Entry created: {0}").format(payment_entry.name))
    create_notification(order.created_by_user, _("Payment Posted"), _("Payment {0} posted to ERPNext.").format(payment_entry.name), order.name, "payment_entry_posted")
    return payment_entry.name


def post_accepted_payments_to_erpnext(closure_name):
    payments = frappe.get_all(
        "Awamir Order Payment",
        filters={
            "cash_closure": closure_name,
            "status": ["in", [PAYMENT_STATUS_CASHIER_ACCEPTED, PAYMENT_STATUS_READY_FOR_ERP]],
        },
        pluck="name",
    )
    return [create_payment_entry_for_payment(payment) for payment in payments]


def create_sales_invoice_for_order(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    if order.erpnext_sales_invoice:
        return order.erpnext_sales_invoice
    if not order.erpnext_sales_order:
        _mark_order_sync_failed(order, _("Sales Invoice requires an existing Sales Order."))

    settings = get_awamir_settings()
    invoice = frappe.get_doc(
        {
            "doctype": "Sales Invoice",
            "customer": create_customer_if_missing(order),
            "company": settings.default_company,
            "currency": settings.default_currency,
            "posting_date": frappe.utils.today(),
            "items": [
                {
                    "item_code": item.item_code,
                    "item_name": item.item_name,
                    "description": item.description,
                    "qty": item.qty,
                    "rate": item.rate,
                    "amount": item.amount,
                    "sales_order": order.erpnext_sales_order,
                }
                for item in order.items
            ],
        }
    )
    invoice.insert(ignore_permissions=True)

    order.erpnext_sales_invoice = invoice.name
    order.erp_sync_status = ERP_SYNC_PARTIALLY_SYNCED
    order.erp_sync_error = None
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    make_status_log(order.name, order.status, order.status, _("Sales Invoice created: {0}").format(invoice.name))
    create_notification(order.created_by_user, _("Sales Invoice Created"), _("Sales Invoice {0} created for order {1}.").format(invoice.name, order.order_number), order.name, "sales_invoice_created")
    return invoice.name


def allocate_advance_payment_to_invoice(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    if not order.erpnext_sales_invoice:
        _mark_order_sync_failed(order, _("Advance allocation requires an existing Sales Invoice."))

    payments = frappe.get_all(
        "Awamir Order Payment",
        filters={"order": order.name, "status": PAYMENT_STATUS_POSTED_TO_ERP},
        fields=["name", "amount", "erpnext_payment_entry"],
    )
    if not payments:
        _mark_order_sync_failed(order, _("There are no posted Payment Entries to allocate."))

    allocated = 0
    for payment in payments:
        allocated += frappe.utils.flt(payment.amount)
        frappe.db.set_value("Awamir Order Payment", payment.name, "status", PAYMENT_STATUS_LINKED_TO_INVOICE)

    order.remaining_amount = max(frappe.utils.flt(order.total_amount) + frappe.utils.flt(order.delivery_fee) - allocated, 0)
    order.erp_sync_status = ERP_SYNC_SYNCED if order.remaining_amount == 0 else ERP_SYNC_PARTIALLY_SYNCED
    order.erp_sync_error = None
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    make_status_log(order.name, order.status, order.status, _("Advance payments allocated to invoice {0}.").format(order.erpnext_sales_invoice))
    create_notification(order.created_by_user, _("Advance Allocated"), _("Advance payments allocated to invoice {0}.").format(order.erpnext_sales_invoice), order.name, "advance_payment_allocated")
    return {"allocated_amount": allocated, "remaining_amount": order.remaining_amount}


def sync_order_accounting_status(order_name):
    order = frappe.get_doc("Awamir Order Request", order_name)
    if order.erpnext_sales_order and order.erpnext_sales_invoice and order.remaining_amount == 0:
        order.erp_sync_status = ERP_SYNC_SYNCED
    elif order.erpnext_sales_order or order.erpnext_sales_invoice:
        order.erp_sync_status = ERP_SYNC_PARTIALLY_SYNCED
    else:
        order.erp_sync_status = "Not Synced"
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    return order.erp_sync_status


def _mark_order_sync_failed(order, message):
    order.erp_sync_status = ERP_SYNC_FAILED
    order.erp_sync_error = message
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    create_notification(order.created_by_user, _("ERPNext Sync Failed"), message, order.name, "erp_sync_failed")
    frappe.throw(message)


def _mark_payment_sync_failed(payment, message):
    payment.status = payment.status
    payment.save(ignore_permissions=True)
    order = frappe.get_doc("Awamir Order Request", payment.order)
    order.erp_sync_status = ERP_SYNC_FAILED
    order.erp_sync_error = message
    order.erp_synced_at = now()
    order.save(ignore_permissions=True)
    create_notification(order.created_by_user, _("ERPNext Payment Failed"), message, order.name, "payment_entry_failed")
    frappe.throw(message)

