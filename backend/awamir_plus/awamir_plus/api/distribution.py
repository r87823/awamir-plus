import frappe
from frappe import _

from awamir_plus.constants import ORDER_STATUS_READY_FOR_DELIVERY, ORDER_STATUS_SENT_TO_DISTRIBUTION, ORDER_STATUS_SENT_TO_PRODUCTION
from awamir_plus.permissions import is_awamir_admin, require_roles
from awamir_plus.services.accounting import create_work_order_for_order
from awamir_plus.utils import assert_required, create_notification, get_awamir_settings, get_users_with_role, make_status_log


@frappe.whitelist()
def get_distribution_orders():
    require_roles(["Awamir Distribution Manager", "Awamir System Admin"])
    return frappe.get_all(
        "Awamir Order Request",
        filters={"status": ["in", [ORDER_STATUS_SENT_TO_DISTRIBUTION, ORDER_STATUS_READY_FOR_DELIVERY]]},
        fields=["*"],
        order_by="required_date asc",
    )


@frappe.whitelist()
def get_production_departments():
    require_roles(["Awamir Distribution Manager", "Awamir Production User", "Awamir System Admin"])
    return frappe.get_all("Awamir Production Department", filters={"is_active": 1}, fields=["*"], order_by="department_name asc")


@frappe.whitelist()
def get_default_department_for_order(order):
    require_roles(["Awamir Distribution Manager", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Order Request", order)
    for item in doc.items:
        mapping = frappe.get_all(
            "Awamir Product Department Mapping",
            filters={"is_active": 1, "item_code": item.item_code},
            fields=["production_department", "requires_work_order"],
            limit=1,
        )
        if mapping:
            return mapping[0]
    for item in doc.items:
        mapping = frappe.get_all(
            "Awamir Product Department Mapping",
            filters={"is_active": 1, "item_group": item.product_category},
            fields=["production_department", "requires_work_order"],
            limit=1,
        )
        if mapping:
            return mapping[0]
    return None


@frappe.whitelist()
def assign_production_department(order, production_department):
    require_roles(["Awamir Distribution Manager", "Awamir System Admin"])
    assert_required(production_department, "Production department is required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    if doc.status != ORDER_STATUS_SENT_TO_DISTRIBUTION:
        frappe.throw(_("Only orders sent to distribution can be assigned to production."))
    old_status = doc.status
    doc.production_department = production_department
    doc.status = ORDER_STATUS_SENT_TO_PRODUCTION
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, doc.status, _("Assigned to production department {0}.").format(production_department))

    if get_awamir_settings().create_work_order_on_distribution and any(item.requires_work_order for item in doc.items):
        create_work_order_for_order(doc.name)

    create_notification(doc.created_by_user, _("Order Sent To Production"), _("Order {0} was sent to production.").format(doc.order_number), doc.name, "order_sent_to_production")
    for user in get_users_with_role("Awamir Production User"):
        if is_awamir_admin(user):
            create_notification(user, _("New Production Order"), _("Order {0} is assigned for production.").format(doc.order_number), doc.name, "production_order")
    return doc.as_dict()

