import frappe

from awamir_plus.permissions import require_roles
from awamir_plus.services import accounting as accounting_service


@frappe.whitelist()
def create_sales_order_for_order(order):
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.create_sales_order_for_order(order)


@frappe.whitelist()
def create_work_order_for_order(order):
    require_roles(["Awamir Accountant", "Awamir Distribution Manager", "Awamir System Admin"])
    return accounting_service.create_work_order_for_order(order)


@frappe.whitelist()
def post_accepted_payments_to_erpnext(closure):
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.post_accepted_payments_to_erpnext(closure)


@frappe.whitelist()
def create_payment_entry_for_payment(payment):
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.create_payment_entry_for_payment(payment)


@frappe.whitelist()
def create_sales_invoice_for_order(order):
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.create_sales_invoice_for_order(order)


@frappe.whitelist()
def allocate_advance_payment_to_invoice(order):
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.allocate_advance_payment_to_invoice(order)


@frappe.whitelist()
def get_customer_invoices(customer):
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return frappe.get_all("Sales Invoice", filters={"customer": customer}, fields=["name", "posting_date", "grand_total", "outstanding_amount", "status"], order_by="posting_date desc")


@frappe.whitelist()
def sync_order_accounting_status(order):
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.sync_order_accounting_status(order)

