import frappe
from frappe import _

from awamir_plus.constants import (
    ORDER_STATUS_ASSIGNED_TO_DRIVER,
    ORDER_STATUS_DELIVERY_FAILED,
    ORDER_STATUS_DRIVER_PICKED_UP,
    ORDER_STATUS_OUT_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_SENT_TO_DISTRIBUTION,
    ORDER_STATUS_SENT_TO_PRODUCTION,
    PERMISSION_FULFILLMENT_ASSIGN_DEPARTMENT,
    PERMISSION_FULFILLMENT_CREATE_WORK_ORDERS,
    PERMISSION_FULFILLMENT_VIEW_QUEUE,
    PERMISSION_WORK_ORDER_VIEW_DEPARTMENT,
)
from awamir_plus.permissions import get_user_branch, get_user_production_department, is_awamir_admin, require_any_permissions, require_permissions
from awamir_plus.services.fulfillment import (
    create_department_work_orders_for_order,
    get_department_work_orders as get_department_work_orders_for_order,
)
from awamir_plus.utils import apply_order_flow_statuses, assert_required, create_notification, get_pagination, get_users_with_role, make_audit_log, make_status_log, run_idempotent


@frappe.whitelist()
def get_distribution_orders(status=None, limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_FULFILLMENT_VIEW_QUEUE)
    allowed_statuses = [
        ORDER_STATUS_SENT_TO_DISTRIBUTION,
        ORDER_STATUS_READY_FOR_DELIVERY,
        ORDER_STATUS_ASSIGNED_TO_DRIVER,
        ORDER_STATUS_DRIVER_PICKED_UP,
        ORDER_STATUS_OUT_FOR_DELIVERY,
        ORDER_STATUS_DELIVERY_FAILED,
    ]
    filters = {
        "status": status if status in allowed_statuses else ["in", allowed_statuses]
    }
    if not is_awamir_admin() and get_user_branch():
        filters["created_branch"] = get_user_branch()
    orders = frappe.get_all(
        "Awamir Order Request",
        filters=filters,
        pluck="name",
        order_by="required_date asc",
        **get_pagination(limit_start, limit_page_length),
    )
    from awamir_plus.api.orders import get_order_detail

    return [get_order_detail(order) for order in orders]


@frappe.whitelist()
def get_production_departments():
    require_any_permissions([PERMISSION_FULFILLMENT_VIEW_QUEUE, PERMISSION_WORK_ORDER_VIEW_DEPARTMENT])
    departments = frappe.get_all("Awamir Production Department", filters={"is_active": 1}, pluck="name", order_by="department_name asc")
    return [_department_response(department) for department in departments]


@frappe.whitelist()
def get_default_department_for_order(order=None, order_id=None):
    require_permissions(PERMISSION_FULFILLMENT_ASSIGN_DEPARTMENT)
    doc = frappe.get_doc("Awamir Order Request", order or order_id)
    if not is_awamir_admin() and get_user_branch() and doc.created_branch != get_user_branch():
        frappe.throw(_("You can only distribute orders for your branch."), frappe.PermissionError)
    for item in doc.items:
        mapping = _get_department_mapping({"is_active": 1, "item_code": item.item_code})
        if mapping:
            return _mapping_response(mapping, "item_code")
    for item in doc.items:
        mapping = _get_department_mapping(
            {"is_active": 1, "item_group": item.product_category, "item_code": ["in", ["", None]]}
        )
        if not mapping:
            mapping = _get_department_mapping({"is_active": 1, "item_group": item.product_category})
        if mapping:
            return _mapping_response(mapping, "item_group")
    return None


@frappe.whitelist()
def assign_production_department(order=None, production_department=None, order_id=None, idempotency_key=None):
    require_permissions(PERMISSION_FULFILLMENT_ASSIGN_DEPARTMENT)
    order = order or order_id
    production_department = (production_department or "").strip()
    assert_required(order, "Order is required.")
    assert_required(production_department, "Production department is required.")
    payload = {"order": order, "production_department": production_department}

    def _execute():
        if not frappe.db.exists("Awamir Production Department", {"name": production_department, "is_active": 1}):
            frappe.throw(_("Production department is not active or does not exist."))
        doc = frappe.get_doc("Awamir Order Request", order)
        if not is_awamir_admin() and get_user_branch() and doc.created_branch != get_user_branch():
            frappe.throw(_("You can only distribute orders for your branch."), frappe.PermissionError)
        if doc.status == ORDER_STATUS_SENT_TO_PRODUCTION and doc.production_department == production_department:
            response = _distribution_response(doc, _("Order is already sent to production."))
            make_audit_log("production_assignment_skipped", status="skipped", reference_doctype="Awamir Order Request", reference_name=doc.name, method="assign_production_department", payload={"production_department": production_department}, response=response)
            return response
        if doc.status != ORDER_STATUS_SENT_TO_DISTRIBUTION:
            frappe.throw(_("Only orders sent to distribution can be assigned to production."))
        old_status = doc.status
        doc.production_department = production_department
        doc.status = ORDER_STATUS_SENT_TO_PRODUCTION
        apply_order_flow_statuses(doc)
        doc.save(ignore_permissions=True)
        work_orders = create_department_work_orders_for_order(doc.name, fallback_department=production_department)
        make_status_log(doc.name, old_status, doc.status, _("Assigned to production department {0}.").format(production_department))

        create_notification(doc.created_by_user, _("Order Sent To Production"), _("Order {0} was sent to production.").format(doc.order_number), doc.name, "order_sent_to_production")
        for user in get_users_with_role("Awamir Production User"):
            if get_user_production_department(user) == production_department or is_awamir_admin(user):
                create_notification(user, _("New Production Order"), _("Order {0} is assigned for production.").format(doc.order_number), doc.name, "order_sent_to_production")
        response = _distribution_response(doc, _("Order assigned to production successfully."))
        response["department_work_orders"] = [work_order.as_dict() for work_order in work_orders]
        make_audit_log("production_department_assigned", reference_doctype="Awamir Order Request", reference_name=doc.name, method="assign_production_department", payload={"production_department": production_department}, response=response)
        return response

    return run_idempotent("assign_production_department", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Order Request", reference_name=order)


@frappe.whitelist()
def create_department_work_orders(order=None, order_id=None, fallback_department=None, idempotency_key=None):
    require_permissions(PERMISSION_FULFILLMENT_CREATE_WORK_ORDERS)
    order = order or order_id
    assert_required(order, "Order is required.")
    payload = {"order": order, "fallback_department": fallback_department}

    def _execute():
        doc = frappe.get_doc("Awamir Order Request", order)
        if not is_awamir_admin() and get_user_branch() and doc.created_branch != get_user_branch():
            frappe.throw(_("You can only distribute orders for your branch."), frappe.PermissionError)
        work_orders = create_department_work_orders_for_order(
            doc.name,
            fallback_department=fallback_department or doc.production_department,
        )
        response = {
            "order_id": doc.name,
            "order_number": doc.order_number,
            "work_orders": [work_order.as_dict() for work_order in work_orders],
            "message": _("Department work orders are ready."),
        }
        make_audit_log("department_work_orders_created", reference_doctype="Awamir Order Request", reference_name=doc.name, method="create_department_work_orders", payload={"fallback_department": fallback_department}, response=response)
        return response

    return run_idempotent("create_department_work_orders", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Order Request", reference_name=order)


@frappe.whitelist()
def get_department_work_orders(order=None, department=None):
    require_any_permissions([PERMISSION_FULFILLMENT_VIEW_QUEUE, PERMISSION_WORK_ORDER_VIEW_DEPARTMENT])
    if not is_awamir_admin() and not department:
        department = get_user_production_department()
    return get_department_work_orders_for_order(order=order, department=department)


def _get_department_mapping(filters):
    rows = frappe.get_all(
        "Awamir Product Department Mapping",
        filters=filters,
        fields=["production_department", "requires_work_order"],
        limit=1,
    )
    return rows[0] if rows else None


def _mapping_response(mapping, source):
    return {
        "production_department": mapping.production_department,
        "requires_work_order": mapping.requires_work_order,
        "source": source,
        "department": _department_response(mapping.production_department),
    }


def _department_response(department):
    if not department:
        return None
    doc = frappe.get_doc("Awamir Production Department", department)
    return {
        "id": doc.name,
        "name": doc.department_name,
        "code": doc.department_code,
        "production_center": getattr(doc, "production_center", None),
        "branch": doc.branch,
        "daily_capacity": getattr(doc, "daily_capacity", 0),
        "is_active": doc.is_active,
        "department_name": doc.department_name,
        "department_code": doc.department_code,
    }


def _distribution_response(doc, message):
    from awamir_plus.api.orders import get_order_detail

    return {
        "order_id": doc.name,
        "order_number": doc.order_number,
        "status": doc.status,
        "production_department": doc.production_department,
        "message": message,
        "order": get_order_detail(doc.name),
    }
