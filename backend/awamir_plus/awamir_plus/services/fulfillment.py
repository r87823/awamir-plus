import frappe
from frappe import _

from awamir_plus.constants import (
    DEPARTMENT_WORK_ORDER_STATUS_ACCEPTED,
    DEPARTMENT_WORK_ORDER_STATUS_CANCELLED,
    DEPARTMENT_WORK_ORDER_STATUS_DELAYED,
    DEPARTMENT_WORK_ORDER_STATUS_IN_PRODUCTION,
    DEPARTMENT_WORK_ORDER_STATUS_PENDING,
    DEPARTMENT_WORK_ORDER_STATUS_READY,
    DEPARTMENT_WORK_ORDER_STATUS_REJECTED,
    ORDER_STATUS_PRODUCTION_COMPLETED,
    ORDER_STATUS_IN_PRODUCTION,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_PICKUP,
    ORDER_STATUS_SENT_TO_PRODUCTION,
    ORDER_FLOW_STATUS_IN_FULFILLMENT,
    ORDER_FLOW_STATUS_READY,
    PRODUCTION_FLOW_STATUS_DELAYED,
    PRODUCTION_FLOW_STATUS_IN_PRODUCTION,
    PRODUCTION_FLOW_STATUS_PARTIALLY_READY,
    PRODUCTION_FLOW_STATUS_READY,
    PRODUCTION_FLOW_STATUS_REJECTED,
    PRODUCTION_FLOW_STATUS_WORK_ORDERS_CREATED,
)
from awamir_plus.utils import create_notification, make_status_log, now


def create_department_work_orders_for_order(order, fallback_department=None):
    doc = frappe.get_doc("Awamir Order Request", order)
    grouped = _group_items_by_department(doc, fallback_department=fallback_department)
    work_orders = []
    for department, items in grouped.items():
        existing = frappe.db.get_value(
            "Awamir Department Work Order",
            {
                "order": doc.name,
                "department": department,
                "status": ["!=", DEPARTMENT_WORK_ORDER_STATUS_CANCELLED],
            },
            "name",
        )
        if existing:
            work_orders.append(frappe.get_doc("Awamir Department Work Order", existing))
            continue
        work_orders.append(_create_department_work_order(doc, department, items))

    if work_orders and doc.production_department != work_orders[0].department:
        doc.production_department = work_orders[0].department
    if work_orders and doc.production_status != PRODUCTION_FLOW_STATUS_WORK_ORDERS_CREATED:
        doc.production_status = PRODUCTION_FLOW_STATUS_WORK_ORDERS_CREATED
    if work_orders and doc.order_status != ORDER_FLOW_STATUS_IN_FULFILLMENT:
        doc.order_status = ORDER_FLOW_STATUS_IN_FULFILLMENT
    if work_orders and (
        doc.has_value_changed("production_department")
        or doc.has_value_changed("production_status")
        or doc.has_value_changed("order_status")
    ):
        doc.save(ignore_permissions=True)

    return work_orders


def get_department_work_orders(order=None, department=None, statuses=None):
    filters = {}
    if order:
        filters["order"] = order
    if department:
        filters["department"] = department
    if statuses:
        filters["status"] = ["in", list(statuses)]
    names = frappe.get_all(
        "Awamir Department Work Order",
        filters=filters,
        pluck="name",
        order_by="creation asc",
    )
    return [department_work_order_response(name) for name in names]


def department_work_order_response(work_order):
    doc = frappe.get_doc("Awamir Department Work Order", work_order)
    data = doc.as_dict()
    if doc.department:
        data["department_name"] = frappe.db.get_value(
            "Awamir Production Department",
            doc.department,
            "department_name",
        )
        data["department_code"] = frappe.db.get_value(
            "Awamir Production Department",
            doc.department,
            "department_code",
        )
    return data


def update_department_work_order_status(work_order, new_status, notes=None, user=None):
    doc = frappe.get_doc("Awamir Department Work Order", work_order)
    if doc.status == new_status:
        return doc
    old_status = doc.status
    doc.status = new_status
    if new_status == DEPARTMENT_WORK_ORDER_STATUS_ACCEPTED:
        doc.accepted_at = doc.accepted_at or now()
    elif new_status == DEPARTMENT_WORK_ORDER_STATUS_IN_PRODUCTION:
        doc.started_at = doc.started_at or now()
    elif new_status == DEPARTMENT_WORK_ORDER_STATUS_READY:
        doc.ready_at = doc.ready_at or now()
    elif new_status == DEPARTMENT_WORK_ORDER_STATUS_REJECTED:
        doc.rejected_at = doc.rejected_at or now()
        doc.rejection_reason = notes or doc.rejection_reason
    elif new_status == DEPARTMENT_WORK_ORDER_STATUS_DELAYED:
        doc.delay_reason = notes or doc.delay_reason
    doc.save(ignore_permissions=True)
    make_status_log(
        doc.order,
        old_status,
        new_status,
        notes or _("Department work order {0} updated.").format(doc.name),
        changed_by=user,
    )
    _sync_parent_order_from_work_orders(doc.order)
    return doc


def _sync_parent_order_from_work_orders(order):
    order_doc = frappe.get_doc("Awamir Order Request", order)
    rows = frappe.get_all(
        "Awamir Department Work Order",
        filters={"order": order, "status": ["!=", DEPARTMENT_WORK_ORDER_STATUS_CANCELLED]},
        fields=["status"],
    )
    if not rows:
        return order_doc
    statuses = {row.status for row in rows}
    if statuses == {DEPARTMENT_WORK_ORDER_STATUS_READY}:
        old_status = order_doc.status
        order_doc.status = (
            ORDER_STATUS_READY_FOR_PICKUP
            if order_doc.delivery_type == "Pickup"
            else ORDER_STATUS_READY_FOR_DELIVERY
        )
        order_doc.production_status = PRODUCTION_FLOW_STATUS_READY
        order_doc.order_status = ORDER_FLOW_STATUS_READY
        order_doc.save(ignore_permissions=True)
        if old_status != order_doc.status:
            make_status_log(order_doc.name, old_status, order_doc.status, _("All department work orders are ready."))
        return order_doc
    if DEPARTMENT_WORK_ORDER_STATUS_IN_PRODUCTION in statuses and order_doc.status == ORDER_STATUS_SENT_TO_PRODUCTION:
        old_status = order_doc.status
        order_doc.status = ORDER_STATUS_IN_PRODUCTION
        order_doc.production_status = PRODUCTION_FLOW_STATUS_IN_PRODUCTION
        order_doc.order_status = ORDER_FLOW_STATUS_IN_FULFILLMENT
        order_doc.save(ignore_permissions=True)
        make_status_log(order_doc.name, old_status, order_doc.status, _("Department production started."))
        return order_doc
    if DEPARTMENT_WORK_ORDER_STATUS_DELAYED in statuses:
        order_doc.production_status = PRODUCTION_FLOW_STATUS_DELAYED
        order_doc.order_status = ORDER_FLOW_STATUS_IN_FULFILLMENT
        order_doc.save(ignore_permissions=True)
        return order_doc
    if DEPARTMENT_WORK_ORDER_STATUS_REJECTED in statuses and DEPARTMENT_WORK_ORDER_STATUS_READY not in statuses:
        order_doc.production_status = PRODUCTION_FLOW_STATUS_REJECTED
        order_doc.order_status = ORDER_FLOW_STATUS_IN_FULFILLMENT
        order_doc.save(ignore_permissions=True)
        return order_doc
    if statuses.issubset({DEPARTMENT_WORK_ORDER_STATUS_READY, DEPARTMENT_WORK_ORDER_STATUS_REJECTED}):
        old_status = order_doc.status
        order_doc.status = ORDER_STATUS_PRODUCTION_COMPLETED
        order_doc.production_status = PRODUCTION_FLOW_STATUS_PARTIALLY_READY
        order_doc.order_status = ORDER_FLOW_STATUS_IN_FULFILLMENT
        order_doc.save(ignore_permissions=True)
        if old_status != order_doc.status:
            make_status_log(order_doc.name, old_status, order_doc.status, _("Department work orders completed with exceptions."))
    elif DEPARTMENT_WORK_ORDER_STATUS_READY in statuses:
        order_doc.production_status = PRODUCTION_FLOW_STATUS_PARTIALLY_READY
        order_doc.order_status = ORDER_FLOW_STATUS_IN_FULFILLMENT
        order_doc.save(ignore_permissions=True)
    elif statuses.issubset({DEPARTMENT_WORK_ORDER_STATUS_PENDING, DEPARTMENT_WORK_ORDER_STATUS_ACCEPTED}):
        order_doc.production_status = PRODUCTION_FLOW_STATUS_WORK_ORDERS_CREATED
        order_doc.order_status = ORDER_FLOW_STATUS_IN_FULFILLMENT
        order_doc.save(ignore_permissions=True)
    return order_doc


def _group_items_by_department(order_doc, fallback_department=None):
    grouped = {}
    for item in order_doc.items:
        department = _get_item_department(item) or fallback_department
        if not department:
            frappe.throw(_("No production department mapping found for item {0}.").format(item.item_code))
        grouped.setdefault(department, []).append(item)
    return grouped


def _get_item_department(item):
    mapping = _get_department_mapping({"is_active": 1, "item_code": item.item_code})
    if mapping:
        return mapping.production_department
    mapping = _get_department_mapping({"is_active": 1, "item_group": item.product_category, "item_code": ["in", ["", None]]})
    if mapping:
        return mapping.production_department
    mapping = _get_department_mapping({"is_active": 1, "item_group": item.product_category})
    return mapping.production_department if mapping else None


def _get_department_mapping(filters):
    rows = frappe.get_all(
        "Awamir Product Department Mapping",
        filters=filters,
        fields=["production_department", "requires_work_order"],
        limit=1,
    )
    return rows[0] if rows else None


def _create_department_work_order(order_doc, department, items):
    department_doc = frappe.get_doc("Awamir Production Department", department)
    capacity = _department_capacity_snapshot(department)
    work_order = frappe.get_doc(
        {
            "doctype": "Awamir Department Work Order",
            "order": order_doc.name,
            "production_center": getattr(department_doc, "production_center", None),
            "department": department,
            "status": DEPARTMENT_WORK_ORDER_STATUS_PENDING,
            "priority": "Normal",
            "department_daily_capacity": capacity["daily_capacity"],
            "department_open_work_orders_count": capacity["open_work_orders_count"],
            "capacity_warning": capacity["warning"],
            "items": [_work_order_item(row) for row in items],
            "created_by": frappe.session.user,
        }
    ).insert(ignore_permissions=True)
    make_status_log(
        order_doc.name,
        order_doc.status,
        order_doc.status,
        _("Department work order {0} created for {1}.").format(
            work_order.name,
            department_doc.department_name,
        ),
    )
    _notify_production_users(order_doc, department, work_order)
    return work_order


def _department_capacity_snapshot(department):
    daily_capacity = frappe.db.get_value(
        "Awamir Production Department",
        department,
        "daily_capacity",
    ) or 0
    open_count = frappe.db.count(
        "Awamir Department Work Order",
        {
            "department": department,
            "status": [
                "in",
                [
                    DEPARTMENT_WORK_ORDER_STATUS_PENDING,
                    DEPARTMENT_WORK_ORDER_STATUS_ACCEPTED,
                    DEPARTMENT_WORK_ORDER_STATUS_IN_PRODUCTION,
                    DEPARTMENT_WORK_ORDER_STATUS_DELAYED,
                ],
            ],
        },
    )
    warning = None
    if daily_capacity and open_count + 1 > daily_capacity:
        warning = _("Department capacity exceeded: {0}/{1} open work orders.").format(
            open_count + 1,
            daily_capacity,
        )
    return {
        "daily_capacity": daily_capacity,
        "open_work_orders_count": open_count + 1,
        "warning": warning,
    }


def _work_order_item(item):
    return {
        "item_code": item.item_code,
        "item_name": item.item_name,
        "description": item.description,
        "qty": item.qty,
        "rate": item.rate,
        "amount": item.amount,
        "product_category": item.product_category,
        "source_order_item": item.name,
    }


def _notify_production_users(order_doc, department, work_order):
    from awamir_plus.permissions import get_user_production_department

    for row in frappe.get_all("Has Role", filters={"role": "Awamir Production User"}, fields=["parent"]):
        if get_user_production_department(row.parent) == department:
            create_notification(
                row.parent,
                _("New Department Work Order"),
                _("Work order {0} was created for order {1}.").format(
                    work_order.name,
                    order_doc.order_number,
                ),
                order_doc.name,
                "department_work_order_created",
            )
