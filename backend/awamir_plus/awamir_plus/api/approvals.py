import frappe
from frappe import _

from awamir_plus.constants import (
    ORDER_STATUS_PENDING_APPROVAL,
    ORDER_STATUS_REJECTED,
    ORDER_STATUS_RETURNED,
    ORDER_STATUS_SENT_TO_DISTRIBUTION,
    PERMISSION_ORDER_APPROVE,
    PERMISSION_ORDER_REJECT,
    PERMISSION_ORDER_RETURN_FOR_EDIT,
    PERMISSION_ORDER_VIEW_BRANCH,
)
from awamir_plus.permissions import get_user_branch, is_awamir_admin, require_branch_scope, require_permissions
from awamir_plus.utils import apply_order_flow_statuses, assert_required, create_notification, get_awamir_settings, get_pagination, get_users_with_role, make_audit_log, make_status_log, now, run_idempotent


@frappe.whitelist()
def get_pending_supervisor_approvals(limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_ORDER_VIEW_BRANCH)
    filters = {"status": ORDER_STATUS_PENDING_APPROVAL}
    if not is_awamir_admin():
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
def approve_order(order, idempotency_key=None):
    require_permissions(PERMISSION_ORDER_APPROVE)
    payload = {"order": order}

    def _execute():
        doc = frappe.get_doc("Awamir Order Request", order)
        require_branch_scope(doc.created_branch)
        if doc.status == ORDER_STATUS_SENT_TO_DISTRIBUTION:
            response = _approval_response(doc, _("Order is already sent to distribution."))
            make_audit_log("order_approve_skipped", status="skipped", reference_doctype="Awamir Order Request", reference_name=doc.name, method="approve_order", response=response)
            return response
        if doc.status != ORDER_STATUS_PENDING_APPROVAL:
            frappe.throw(_("Only orders pending supervisor approval can be approved."))

        old_status = doc.status
        doc.status = ORDER_STATUS_SENT_TO_DISTRIBUTION
        doc.approved_by = frappe.session.user
        doc.approved_at = now()
        apply_order_flow_statuses(doc)
        doc.save(ignore_permissions=True)
        make_status_log(doc.name, old_status, doc.status, _("Approved by supervisor."))
        _maybe_create_sales_order_on_approval(doc)

        create_notification(doc.created_by_user, _("Order Approved"), _("Order {0} approved and sent to distribution.").format(doc.order_number), doc.name, "order_approved")
        for user in get_users_with_role("Awamir Distribution Manager"):
            create_notification(user, _("New Distribution Order"), _("Order {0} is waiting for distribution.").format(doc.order_number), doc.name, "order_sent_to_distribution")
        response = _approval_response(doc, _("Order approved and sent to distribution."))
        make_audit_log("order_approved", reference_doctype="Awamir Order Request", reference_name=doc.name, method="approve_order", response=response)
        return response

    return run_idempotent("approve_order", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Order Request", reference_name=order)


@frappe.whitelist()
def reject_order(order, reason, idempotency_key=None):
    require_permissions(PERMISSION_ORDER_REJECT)
    reason = (reason or "").strip()
    assert_required(reason, "Rejection reason is required.")
    payload = {"order": order, "reason": reason}

    def _execute():
        doc = frappe.get_doc("Awamir Order Request", order)
        require_branch_scope(doc.created_branch)
        if doc.status == ORDER_STATUS_REJECTED:
            response = _approval_response(doc, _("Order is already rejected."))
            make_audit_log("order_reject_skipped", status="skipped", reference_doctype="Awamir Order Request", reference_name=doc.name, method="reject_order", response=response)
            return response
        if doc.status != ORDER_STATUS_PENDING_APPROVAL:
            frappe.throw(_("Only orders pending supervisor approval can be rejected."))
        old_status = doc.status
        doc.status = ORDER_STATUS_REJECTED
        apply_order_flow_statuses(doc)
        doc.save(ignore_permissions=True)
        make_status_log(doc.name, old_status, doc.status, reason)
        create_notification(doc.created_by_user, _("Order Rejected"), _("Order {0} was rejected: {1}").format(doc.order_number, reason), doc.name, "order_rejected")
        response = _approval_response(doc, _("Order rejected."))
        make_audit_log("order_rejected", reference_doctype="Awamir Order Request", reference_name=doc.name, method="reject_order", payload={"reason": reason}, response=response)
        return response

    return run_idempotent("reject_order", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Order Request", reference_name=order)


@frappe.whitelist()
def return_order_for_edit(order, notes=None, note=None, idempotency_key=None):
    require_permissions(PERMISSION_ORDER_RETURN_FOR_EDIT)
    notes = (notes or note or "").strip()
    assert_required(notes, "Return notes are required.")
    payload = {"order": order, "notes": notes}

    def _execute():
        doc = frappe.get_doc("Awamir Order Request", order)
        require_branch_scope(doc.created_branch)
        if doc.status == ORDER_STATUS_RETURNED:
            response = _approval_response(doc, _("Order is already returned for edit."))
            make_audit_log("order_return_skipped", status="skipped", reference_doctype="Awamir Order Request", reference_name=doc.name, method="return_order_for_edit", response=response)
            return response
        if doc.status != ORDER_STATUS_PENDING_APPROVAL:
            frappe.throw(_("Only orders pending supervisor approval can be returned for edit."))
        old_status = doc.status
        doc.status = ORDER_STATUS_RETURNED
        apply_order_flow_statuses(doc)
        doc.save(ignore_permissions=True)
        make_status_log(doc.name, old_status, doc.status, notes)
        create_notification(doc.created_by_user, _("Order Returned"), _("Order {0} returned for edit.").format(doc.order_number), doc.name, "order_returned")
        response = _approval_response(doc, _("Order returned for edit."))
        make_audit_log("order_returned_for_edit", reference_doctype="Awamir Order Request", reference_name=doc.name, method="return_order_for_edit", payload={"notes": notes}, response=response)
        return response

    return run_idempotent("return_order_for_edit", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Order Request", reference_name=order)


def _approval_response(doc, message):
    from awamir_plus.api.orders import get_order_detail

    return {
        "order_id": doc.name,
        "order_number": doc.order_number,
        "status": doc.status,
        "message": message,
        "order": get_order_detail(doc.name),
    }


def _maybe_create_sales_order_on_approval(doc):
    settings = get_awamir_settings()
    if not frappe.utils.cint(settings.create_sales_order_on_approval):
        return
    try:
        from awamir_plus.services.accounting import create_sales_order_for_order

        create_sales_order_for_order(doc.name)
    except Exception as exc:
        doc.reload()
        doc.erp_sync_error = _("تعذر إنشاء Sales Order تلقائياً عند الموافقة: {0}").format(str(exc))
        doc.save(ignore_permissions=True)
        make_status_log(doc.name, doc.status, doc.status, doc.erp_sync_error)
