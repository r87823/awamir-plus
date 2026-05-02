#!/usr/bin/env python3
import ast
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "awamir_plus"
DOCTYPE_ROOT = APP / "awamir_plus" / "doctype"

REQUIRED_DOCTYPES = [
    "awamir_order_request",
    "awamir_order_request_item",
    "awamir_order_attachment",
    "awamir_order_status_log",
    "awamir_order_payment",
    "awamir_daily_cash_closure",
    "awamir_cash_closure_log",
    "awamir_delivery_assignment",
    "awamir_notification",
    "awamir_production_department",
    "awamir_product_department_mapping",
    "awamir_app_settings",
]

REQUIRED_API_FUNCTIONS = {
    "auth.py": ["get_current_user"],
    "products.py": ["get_categories", "get_products_by_category", "get_product_price", "get_product_department_mapping"],
    "customers.py": ["search_customer_by_phone", "search_customer_by_name", "create_customer", "get_customer_addresses", "create_customer_address", "update_customer_address", "extract_coordinates_from_google_maps_url"],
    "orders.py": ["create_order", "save_order_as_draft", "submit_order_for_approval", "get_my_orders", "get_order_detail", "upload_order_attachment"],
    "approvals.py": ["get_pending_supervisor_approvals", "approve_order", "reject_order", "return_order_for_edit"],
    "distribution.py": ["get_distribution_orders", "get_production_departments", "get_default_department_for_order", "assign_production_department"],
    "production.py": ["get_production_orders", "update_production_status"],
    "delivery.py": ["get_pickup_orders", "mark_pickup_order_delivered", "collect_remaining_payment", "get_available_drivers", "assign_driver_to_order", "get_driver_orders", "update_delivery_status", "mark_delivery_failed", "collect_delivery_payment"],
    "cash_closure.py": ["get_my_daily_cash_closure", "submit_cash_closure", "get_submitted_cash_closures", "get_cash_closure_detail", "accept_cash_closure", "return_cash_closure", "close_cash_closure"],
    "accounting.py": ["create_sales_order_for_order", "create_work_order_for_order", "post_accepted_payments_to_erpnext", "create_payment_entry_for_payment", "create_sales_invoice_for_order", "allocate_advance_payment_to_invoice", "get_customer_invoices", "sync_order_accounting_status"],
    "notifications.py": ["get_notifications", "mark_notification_as_read", "mark_all_notifications_as_read"],
}


def main():
    errors = []
    for doctype in REQUIRED_DOCTYPES:
        folder = DOCTYPE_ROOT / doctype
        if not folder.exists():
            errors.append(f"Missing DocType folder: {doctype}")
            continue
        json_file = folder / f"{doctype}.json"
        py_file = folder / f"{doctype}.py"
        if not json_file.exists():
            errors.append(f"Missing DocType JSON: {json_file}")
        else:
            json.loads(json_file.read_text())
        if not py_file.exists():
            errors.append(f"Missing DocType controller: {py_file}")

    for filename, functions in REQUIRED_API_FUNCTIONS.items():
        path = APP / "api" / filename
        if not path.exists():
            errors.append(f"Missing API file: {filename}")
            continue
        module = ast.parse(path.read_text())
        exported = {node.name for node in module.body if isinstance(node, ast.FunctionDef)}
        for function in functions:
            if function not in exported:
                errors.append(f"Missing API function {function} in {filename}")

    for fixture in ["role.json", "module_def.json", "custom_field.json"]:
        path = APP / "fixtures" / fixture
        if not path.exists():
            errors.append(f"Missing fixture: {fixture}")
        else:
            json.loads(path.read_text())

    if errors:
        print("\n".join(errors))
        raise SystemExit(1)
    print("Awamir Plus Frappe app structure verified.")


if __name__ == "__main__":
    main()
