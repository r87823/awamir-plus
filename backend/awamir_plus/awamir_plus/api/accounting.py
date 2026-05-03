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
def post_accepted_payments_to_erpnext(closure=None, order=None):
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.post_accepted_payments_to_erpnext(closure=closure, order=order)


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
    return accounting_service.get_customer_invoices(customer)


@frappe.whitelist()
def sync_order_accounting_status(order):
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.sync_order_accounting_status(order)


@frappe.whitelist()
def get_orders_needing_sales_order():
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.get_orders_needing_sales_order()


@frappe.whitelist()
def get_payments_ready_for_erp_posting():
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.get_payments_ready_for_erp_posting()


@frappe.whitelist()
def get_orders_needing_sales_invoice():
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.get_orders_needing_sales_invoice()


@frappe.whitelist()
def get_invoices_needing_advance_allocation():
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.get_invoices_needing_advance_allocation()


@frappe.whitelist()
def get_accounting_sync_errors():
    require_roles(["Awamir Accountant", "Awamir System Admin"])
    return accounting_service.get_accounting_sync_errors()
