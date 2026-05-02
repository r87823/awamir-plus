import frappe
from frappe import _

from awamir_plus.constants import ORDER_STATUS_PENDING_APPROVAL, ORDER_STATUS_REJECTED, ORDER_STATUS_RETURNED, ORDER_STATUS_SENT_TO_DISTRIBUTION
from awamir_plus.permissions import get_user_branch, is_awamir_admin, require_branch_scope, require_roles
from awamir_plus.services.accounting import create_sales_order_for_order
from awamir_plus.utils import assert_required, create_notification, get_awamir_settings, get_users_with_role, make_status_log, now


@frappe.whitelist()
def get_pending_supervisor_approvals():
    require_roles(["Awamir Branch Supervisor", "Awamir System Admin"])
    filters = {"status": ORDER_STATUS_PENDING_APPROVAL}
    if not is_awamir_admin():
        filters["created_branch"] = get_user_branch()
    return frappe.get_all("Awamir Order Request", filters=filters, fields=["*"], order_by="required_date asc")


@frappe.whitelist()
def approve_order(order):
    require_roles(["Awamir Branch Supervisor", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Order Request", order)
    require_branch_scope(doc.created_branch)
    if doc.status != ORDER_STATUS_PENDING_APPROVAL:
        frappe.throw(_("Only orders pending supervisor approval can be approved."))

    old_status = doc.status
    doc.status = ORDER_STATUS_SENT_TO_DISTRIBUTION
    doc.approved_by = frappe.session.user
    doc.approved_at = now()
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, doc.status, _("Approved by supervisor."))

    settings = get_awamir_settings()
    if settings.create_sales_order_on_approval:
        create_sales_order_for_order(doc.name)

    create_notification(doc.created_by_user, _("Order Approved"), _("Order {0} approved and sent to distribution.").format(doc.order_number), doc.name, "order_approved")
    for user in get_users_with_role("Awamir Distribution Manager"):
        create_notification(user, _("New Distribution Order"), _("Order {0} is waiting for distribution.").format(doc.order_number), doc.name, "order_sent_to_distribution")
    return doc.as_dict()


@frappe.whitelist()
def reject_order(order, reason):
    require_roles(["Awamir Branch Supervisor", "Awamir System Admin"])
    assert_required(reason, "Rejection reason is required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    require_branch_scope(doc.created_branch)
    old_status = doc.status
    doc.status = ORDER_STATUS_REJECTED
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, doc.status, reason)
    create_notification(doc.created_by_user, _("Order Rejected"), _("Order {0} was rejected: {1}").format(doc.order_number, reason), doc.name, "order_rejected")
    return doc.as_dict()


@frappe.whitelist()
def return_order_for_edit(order, notes):
    require_roles(["Awamir Branch Supervisor", "Awamir System Admin"])
    assert_required(notes, "Return notes are required.")
    doc = frappe.get_doc("Awamir Order Request", order)
    require_branch_scope(doc.created_branch)
    old_status = doc.status
    doc.status = ORDER_STATUS_RETURNED
    doc.save(ignore_permissions=True)
    make_status_log(doc.name, old_status, doc.status, notes)
    create_notification(doc.created_by_user, _("Order Returned"), _("Order {0} returned for edit.").format(doc.order_number), doc.name, "order_returned")
    return doc.as_dict()

