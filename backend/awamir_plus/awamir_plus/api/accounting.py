import frappe

from awamir_plus.constants import (
    PERMISSION_ACCOUNTING_RECONCILE_PAYMENTS,
    PERMISSION_ACCOUNTING_REVIEW_INVOICE,
    PERMISSION_ACCOUNTING_REVIEW_PAYMENT,
    PERMISSION_ACCOUNTING_SUBMIT_INVOICE,
    PERMISSION_ACCOUNTING_SUBMIT_PAYMENT,
    PERMISSION_ACCOUNTING_VIEW_FINANCIALS,
    PERMISSION_FULFILLMENT_CREATE_WORK_ORDERS,
)
from awamir_plus.permissions import require_any_permissions, require_permissions
from awamir_plus.services import accounting as accounting_service
from awamir_plus.utils import run_idempotent


@frappe.whitelist()
def create_sales_order_for_order(order, idempotency_key=None):
    require_permissions(PERMISSION_ACCOUNTING_REVIEW_INVOICE)
    payload = {"order": order}
    return run_idempotent(
        "create_sales_order_for_order",
        payload,
        lambda: accounting_service.create_sales_order_for_order(order),
        idempotency_key=idempotency_key,
        reference_doctype="Awamir Order Request",
        reference_name=order,
    )


@frappe.whitelist()
def create_work_order_for_order(order, idempotency_key=None):
    require_any_permissions([PERMISSION_ACCOUNTING_REVIEW_INVOICE, PERMISSION_FULFILLMENT_CREATE_WORK_ORDERS])
    payload = {"order": order}
    return run_idempotent(
        "create_work_order_for_order",
        payload,
        lambda: accounting_service.create_work_order_for_order(order),
        idempotency_key=idempotency_key,
        reference_doctype="Awamir Order Request",
        reference_name=order,
    )


@frappe.whitelist()
def post_accepted_payments_to_erpnext(closure=None, order=None, idempotency_key=None):
    require_permissions(PERMISSION_ACCOUNTING_SUBMIT_PAYMENT)
    payload = {"closure": closure, "order": order}
    return run_idempotent(
        "post_accepted_payments_to_erpnext",
        payload,
        lambda: accounting_service.post_accepted_payments_to_erpnext(closure=closure, order=order),
        idempotency_key=idempotency_key,
        reference_doctype="Awamir Daily Cash Closure" if closure else "Awamir Order Request",
        reference_name=closure or order,
    )


@frappe.whitelist()
def create_payment_entry_for_payment(payment, idempotency_key=None):
    require_permissions(PERMISSION_ACCOUNTING_SUBMIT_PAYMENT)
    payload = {"payment": payment}
    return run_idempotent(
        "create_payment_entry_for_payment",
        payload,
        lambda: accounting_service.create_payment_entry_for_payment(payment),
        idempotency_key=idempotency_key,
        reference_doctype="Awamir Order Payment",
        reference_name=payment,
    )


@frappe.whitelist()
def create_sales_invoice_for_order(order, idempotency_key=None):
    require_permissions(PERMISSION_ACCOUNTING_SUBMIT_INVOICE)
    payload = {"order": order}
    return run_idempotent(
        "create_sales_invoice_for_order",
        payload,
        lambda: accounting_service.create_sales_invoice_for_order(order),
        idempotency_key=idempotency_key,
        reference_doctype="Awamir Order Request",
        reference_name=order,
    )


@frappe.whitelist()
def allocate_advance_payment_to_invoice(order, idempotency_key=None):
    require_permissions(PERMISSION_ACCOUNTING_RECONCILE_PAYMENTS)
    payload = {"order": order}
    return run_idempotent(
        "allocate_advance_payment_to_invoice",
        payload,
        lambda: accounting_service.allocate_advance_payment_to_invoice(order),
        idempotency_key=idempotency_key,
        reference_doctype="Awamir Order Request",
        reference_name=order,
    )


@frappe.whitelist()
def get_customer_invoices(customer):
    require_permissions(PERMISSION_ACCOUNTING_VIEW_FINANCIALS)
    return accounting_service.get_customer_invoices(customer)


@frappe.whitelist()
def sync_order_accounting_status(order, idempotency_key=None):
    require_permissions(PERMISSION_ACCOUNTING_VIEW_FINANCIALS)
    payload = {"order": order}
    return run_idempotent(
        "sync_order_accounting_status",
        payload,
        lambda: accounting_service.sync_order_accounting_status(order),
        idempotency_key=idempotency_key,
        reference_doctype="Awamir Order Request",
        reference_name=order,
    )


@frappe.whitelist()
def get_orders_needing_sales_order(limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_ACCOUNTING_REVIEW_INVOICE)
    return accounting_service.get_orders_needing_sales_order(limit_start, limit_page_length)


@frappe.whitelist()
def get_payments_ready_for_erp_posting(limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_ACCOUNTING_REVIEW_PAYMENT)
    return accounting_service.get_payments_ready_for_erp_posting(limit_start, limit_page_length)


@frappe.whitelist()
def get_orders_needing_sales_invoice(limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_ACCOUNTING_REVIEW_INVOICE)
    return accounting_service.get_orders_needing_sales_invoice(limit_start, limit_page_length)


@frappe.whitelist()
def get_invoices_needing_advance_allocation(limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_ACCOUNTING_RECONCILE_PAYMENTS)
    return accounting_service.get_invoices_needing_advance_allocation(limit_start, limit_page_length)


@frappe.whitelist()
def get_accounting_sync_errors(limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_ACCOUNTING_VIEW_FINANCIALS)
    return accounting_service.get_accounting_sync_errors(limit_start, limit_page_length)
