import frappe
from frappe import _

from awamir_plus.constants import (
    ORDER_STATUS_DRAFT,
    ORDER_STATUS_PENDING_APPROVAL,
    PAYMENT_STATUS_RECORDED,
    ROLE_BRANCH_SUPERVISOR,
)
from awamir_plus.permissions import get_user_branch, is_awamir_admin, require_branch_scope, require_roles
from awamir_plus.utils import (
    assert_required,
    create_notification,
    extract_coordinates_from_google_maps_url,
    make_status_log,
    parse_json,
    serialize_doc,
    to_float,
)


@frappe.whitelist()
def create_order(order_data):
    return submit_order_for_approval(order_data)


@frappe.whitelist()
def save_order_as_draft(order_data):
    return _save_order(order_data, ORDER_STATUS_DRAFT)


@frappe.whitelist()
def submit_order_for_approval(order_data):
    return _save_order(order_data, ORDER_STATUS_PENDING_APPROVAL)


def _save_order(order_data, status):
    require_roles(["Awamir Branch Employee"])
    data = parse_json(order_data, {})
    items = data.get("items") or []
    assert_required(items, "At least one item is required.")
    assert_required(data.get("customer_phone"), "Customer phone is required.")

    branch = data.get("created_branch") or get_user_branch()
    delivery_type = data.get("delivery_type") or "Pickup"
    pickup_branch = data.get("pickup_branch") or (branch if delivery_type == "Pickup" else None)

    if delivery_type == "Delivery" and not (data.get("delivery_address") or data.get("delivery_location_url")):
        frappe.throw(_("Delivery address or location URL is required."))

    coordinates = extract_coordinates_from_google_maps_url(data.get("delivery_location_url"))
    total_amount = sum(to_float(item.get("amount")) or to_float(item.get("qty")) * to_float(item.get("rate")) for item in items)
    delivery_fee = to_float(data.get("delivery_fee"))
    deposit_amount = to_float(data.get("deposit_amount"))
    if deposit_amount > total_amount + delivery_fee:
        frappe.throw(_("Deposit cannot exceed order total plus delivery fee."))

    doc = frappe.get_doc(
        {
            "doctype": "Awamir Order Request",
            "customer": data.get("customer"),
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
            "latitude": data.get("latitude") or (coordinates or {}).get("latitude"),
            "longitude": data.get("longitude") or (coordinates or {}).get("longitude"),
            "delivery_notes": data.get("delivery_notes"),
            "delivery_fee": delivery_fee,
            "required_date": data.get("required_date"),
            "required_time": data.get("required_time"),
            "status": status,
            "total_amount": total_amount,
            "deposit_amount": deposit_amount,
            "remaining_amount": total_amount + delivery_fee - deposit_amount,
            "created_by_user": frappe.session.user,
            "items": [_make_item(item) for item in items],
            "attachments": data.get("attachments") or [],
        }
    ).insert()

    make_status_log(doc.name, None, status, _("Order created."))
    if deposit_amount > 0:
        _record_deposit(doc, deposit_amount, data)
    if status == ORDER_STATUS_PENDING_APPROVAL:
        for supervisor in _get_branch_supervisors():
            create_notification(supervisor, _("New Order Approval"), _("Order {0} is waiting for approval.").format(doc.order_number), doc.name, "order_submitted")
    return doc.as_dict()


def _make_item(item):
    qty = to_float(item.get("qty")) or 1
    rate = to_float(item.get("rate"))
    return {
        "item_code": item.get("item_code"),
        "item_name": item.get("item_name"),
        "description": item.get("description"),
        "qty": qty,
        "rate": rate,
        "amount": to_float(item.get("amount")) or qty * rate,
        "product_category": item.get("product_category") or item.get("item_group"),
        "requires_work_order": item.get("requires_work_order") or 0,
    }


def _record_deposit(order, amount, data):
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
            "status": PAYMENT_STATUS_RECORDED,
        }
    ).insert(ignore_permissions=True)


def _get_branch_supervisors():
    return [
        row.parent
        for row in frappe.get_all("Has Role", filters={"role": ROLE_BRANCH_SUPERVISOR}, fields=["parent"])
        if not get_user_branch(row.parent) or get_user_branch(row.parent) == get_user_branch()
    ]


@frappe.whitelist()
def get_my_orders():
    require_roles(["Awamir Branch Employee", "Awamir Branch Supervisor", "Awamir System Admin"])
    filters = {}
    if not is_awamir_admin():
        filters["created_branch"] = get_user_branch()
        if "Awamir Branch Employee" in frappe.get_roles() and "Awamir Branch Supervisor" not in frappe.get_roles():
            filters["created_by_user"] = frappe.session.user
    return frappe.get_all("Awamir Order Request", filters=filters, fields=["*"], order_by="modified desc")


@frappe.whitelist()
def get_order_detail(order):
    require_roles(["Awamir Branch Employee", "Awamir Branch Supervisor", "Awamir Distribution Manager", "Awamir Production User", "Awamir Driver", "Awamir Cashier", "Awamir Accountant", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Order Request", order)
    if not is_awamir_admin() and "Awamir Driver" not in frappe.get_roles():
        require_branch_scope(doc.created_branch)
    data = doc.as_dict()
    data["status_logs"] = frappe.get_all("Awamir Order Status Log", filters={"order": doc.name}, fields=["*"], order_by="changed_at asc")
    data["payments"] = frappe.get_all("Awamir Order Payment", filters={"order": doc.name}, fields=["*"], order_by="created_at asc")
    data["delivery_assignment"] = frappe.get_all("Awamir Delivery Assignment", filters={"order": doc.name}, fields=["*"], limit=1)
    return data


@frappe.whitelist()
def upload_order_attachment(order, file, file_type="Other", notes=None):
    require_roles(["Awamir Branch Employee", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Order Request", order)
    require_branch_scope(doc.created_branch)
    doc.append("attachments", {"file": file, "file_type": file_type, "uploaded_by": frappe.session.user, "notes": notes})
    doc.save(ignore_permissions=True)
    return serialize_doc(doc)

