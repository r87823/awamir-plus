import frappe
from frappe import _

from awamir_plus.constants import (
    DELIVERY_BATCH_STATUS_ASSIGNED,
    DELIVERY_BATCH_STATUS_DRAFT,
    ORDER_STATUS_READY_FOR_DELIVERY,
)
from awamir_plus.utils import create_notification, make_status_log, now


def create_batches_for_ready_delivery_orders(branch=None):
    filters = {"status": ORDER_STATUS_READY_FOR_DELIVERY}
    if branch:
        filters["pickup_branch"] = branch
    orders = frappe.get_all(
        "Awamir Order Request",
        filters=filters,
        pluck="name",
        order_by="pickup_branch asc, required_date asc",
    )
    grouped = {}
    for order in orders:
        doc = frappe.get_doc("Awamir Order Request", order)
        destination = doc.pickup_branch or doc.created_branch
        grouped.setdefault(destination, []).append(doc)
    return [
        delivery_batch_response(_get_or_create_batch(destination, rows).name)
        for destination, rows in grouped.items()
        if destination and rows
    ]


def get_delivery_batches(statuses=None, driver=None, destination_branch=None):
    filters = {}
    if statuses:
        filters["status"] = ["in", list(statuses)]
    if driver:
        filters["driver"] = driver
    if destination_branch:
        filters["destination_branch"] = destination_branch
    names = frappe.get_all("Awamir Delivery Batch", filters=filters, pluck="name", order_by="modified desc")
    return [delivery_batch_response(name) for name in names]


def assign_batch_to_driver(batch, driver):
    doc = frappe.get_doc("Awamir Delivery Batch", batch)
    if doc.status == DELIVERY_BATCH_STATUS_ASSIGNED and doc.driver == driver:
        return doc
    if doc.status != DELIVERY_BATCH_STATUS_DRAFT:
        frappe.throw(_("Only draft delivery batches can be assigned."))
    if not frappe.db.exists("User", driver) or "Awamir Driver" not in frappe.get_roles(driver):
        frappe.throw(_("Driver is not active or does not exist."))
    doc.driver = driver
    doc.assigned_by = frappe.session.user
    doc.assigned_at = now()
    doc.status = DELIVERY_BATCH_STATUS_ASSIGNED
    doc.save(ignore_permissions=True)
    create_notification(
        driver,
        _("New Delivery Batch"),
        _("Delivery batch {0} was assigned to you.").format(doc.batch_number),
        None,
        "delivery_batch_assigned",
    )
    for row in doc.orders:
        make_status_log(
            row.order,
            row.status,
            row.status,
            _("Order added to delivery batch {0}.").format(doc.batch_number),
        )
    return doc


def delivery_batch_response(batch):
    doc = frappe.get_doc("Awamir Delivery Batch", batch)
    data = doc.as_dict()
    if doc.driver:
        data["driver_name"] = frappe.db.get_value("User", doc.driver, "full_name") or doc.driver
    return data


def _get_or_create_batch(destination, orders):
    existing = _find_open_batch(destination)
    if existing:
        batch = frappe.get_doc("Awamir Delivery Batch", existing)
        existing_orders = {row.order for row in batch.orders}
        changed = False
        for order in orders:
            if order.name not in existing_orders:
                batch.append("orders", _batch_order_row(order))
                changed = True
        if changed:
            batch.save(ignore_permissions=True)
        return batch
    return frappe.get_doc(
        {
            "doctype": "Awamir Delivery Batch",
            "destination_branch": destination,
            "status": DELIVERY_BATCH_STATUS_DRAFT,
            "orders": [_batch_order_row(order) for order in orders],
        }
    ).insert(ignore_permissions=True)


def _find_open_batch(destination):
    rows = frappe.get_all(
        "Awamir Delivery Batch",
        filters={
            "destination_branch": destination,
            "status": DELIVERY_BATCH_STATUS_DRAFT,
        },
        pluck="name",
        limit=1,
        order_by="creation desc",
    )
    return rows[0] if rows else None


def _batch_order_row(order):
    return {
        "order": order.name,
        "order_number": order.order_number,
        "customer_name": order.customer_name,
        "customer_phone": order.customer_phone,
        "status": order.status,
    }
