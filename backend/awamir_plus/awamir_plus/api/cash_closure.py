import frappe
from frappe import _

from awamir_plus.constants import (
    CLOSURE_STATUS_ACCEPTED,
    CLOSURE_STATUS_CLOSED,
    CLOSURE_STATUS_HAS_DIFFERENCE,
    CLOSURE_STATUS_OPEN,
    CLOSURE_STATUS_RETURNED,
    CLOSURE_STATUS_SUBMITTED,
    PAYMENT_STATUS_CASHIER_ACCEPTED,
    PAYMENT_STATUS_IN_DAILY_CLOSURE,
    PAYMENT_STATUS_READY_FOR_ERP,
    PAYMENT_STATUS_RECORDED,
    PAYMENT_STATUS_RETURNED,
    PAYMENT_STATUS_SUBMITTED,
    PERMISSION_ACCOUNTING_VIEW_FINANCIALS,
    PERMISSION_CASHBOX_APPROVE,
    PERMISSION_CASHBOX_CLOSE_DAY,
    PERMISSION_CASHBOX_RETURN,
    PERMISSION_CASHBOX_REVIEW,
    PERMISSION_CASHBOX_VIEW_ALL,
    PERMISSION_CASHBOX_VIEW_OWN,
    PERMISSION_DELIVERY_COLLECT_CASH,
)
from awamir_plus.permissions import get_user_branch, has_permission, is_awamir_admin, require_any_permissions, require_permissions
from awamir_plus.utils import create_notification, get_cashier_users, get_pagination, make_audit_log, make_cash_closure_log, now, parse_json, run_idempotent, to_float


@frappe.whitelist()
def get_my_daily_cash_closure(closure_type=None, date=None):
    require_permissions(PERMISSION_CASHBOX_VIEW_OWN)
    date = date or frappe.utils.today()
    user = frappe.session.user
    if is_awamir_admin() and closure_type is None:
        closures = frappe.get_all("Awamir Daily Cash Closure", filters={"date": date}, pluck="name", order_by="modified desc")
        return [_closure_detail(name) for name in closures]
    closure_type = closure_type or (
        "driver" if has_permission(PERMISSION_DELIVERY_COLLECT_CASH) else "branch_employee"
    )
    closure_name = frappe.db.get_value(
        "Awamir Daily Cash Closure",
        {"user": user, "date": date, "closure_type": closure_type, "status": ["!=", CLOSURE_STATUS_CLOSED]},
        "name",
    )
    if closure_name:
        closure = frappe.get_doc("Awamir Daily Cash Closure", closure_name)
        _attach_open_payments(closure)
        _recalculate_totals(closure.name)
        frappe.db.commit()
        return get_cash_closure_detail(closure_name)
    closure = frappe.get_doc(
        {
            "doctype": "Awamir Daily Cash Closure",
            "closure_type": closure_type,
            "user": user,
            "branch": get_user_branch(),
            "date": date,
            "status": CLOSURE_STATUS_OPEN,
        }
    ).insert(ignore_permissions=True)
    _attach_open_payments(closure)
    _recalculate_totals(closure.name)
    frappe.db.commit()
    return get_cash_closure_detail(closure.name)


@frappe.whitelist()
def submit_cash_closure(closure, idempotency_key=None):
    require_permissions(PERMISSION_CASHBOX_VIEW_OWN)
    payload = {"closure": closure}

    def _execute():
        doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
        if not is_awamir_admin() and doc.user != frappe.session.user:
            frappe.throw(_("You can only submit your own cash closure."), frappe.PermissionError)
        if doc.status == CLOSURE_STATUS_SUBMITTED:
            response = get_cash_closure_detail(doc.name)
            make_audit_log("cash_closure_submit_skipped", status="skipped", reference_doctype="Awamir Daily Cash Closure", reference_name=doc.name, method="submit_cash_closure", response=response)
            return response
        if doc.status not in (CLOSURE_STATUS_OPEN, CLOSURE_STATUS_RETURNED):
            frappe.throw(_("Cash closure cannot be submitted in its current status."))
        _attach_open_payments(doc)
        _recalculate_totals(doc.name)
        doc.reload()
        old_status = doc.status
        doc.status = CLOSURE_STATUS_SUBMITTED
        doc.submitted_at = now()
        doc.save(ignore_permissions=True)
        _set_payment_statuses(doc.name, PAYMENT_STATUS_SUBMITTED)
        make_cash_closure_log(doc.name, old_status, doc.status, _("Submitted to cashier."))
        for cashier in get_cashier_users():
            create_notification(cashier, _("Cash Closure Submitted"), _("Cash closure {0} submitted.").format(doc.closure_number), None, "cash_closure_submitted")
        response = get_cash_closure_detail(doc.name)
        make_audit_log("cash_closure_submitted", reference_doctype="Awamir Daily Cash Closure", reference_name=doc.name, method="submit_cash_closure", response={"closure_id": doc.name, "status": doc.status})
        return response

    return run_idempotent("submit_cash_closure", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Daily Cash Closure", reference_name=closure)


@frappe.whitelist()
def get_submitted_cash_closures(filters=None, limit_start=0, limit_page_length=None):
    require_permissions(PERMISSION_CASHBOX_VIEW_ALL)
    data = parse_json(filters, {}) or {}
    query_filters = {"status": ["in", [CLOSURE_STATUS_SUBMITTED, CLOSURE_STATUS_RETURNED, CLOSURE_STATUS_HAS_DIFFERENCE]]}
    if data.get("date"):
        query_filters["date"] = data.get("date")
    if data.get("branch"):
        query_filters["branch"] = data.get("branch")
    if data.get("closure_type"):
        query_filters["closure_type"] = data.get("closure_type")
    if data.get("status"):
        query_filters["status"] = data.get("status")
    if data.get("user"):
        query_filters["user"] = data.get("user")
    closures = frappe.get_all(
        "Awamir Daily Cash Closure",
        filters=query_filters,
        pluck="name",
        order_by="submitted_at desc, modified desc",
        **get_pagination(
            data.get("limit_start", limit_start),
            data.get("limit_page_length", limit_page_length),
        ),
    )
    return [_closure_detail(name, include_logs=False) for name in closures]


@frappe.whitelist()
def get_cash_closure_detail(closure):
    require_any_permissions([PERMISSION_CASHBOX_VIEW_OWN, PERMISSION_CASHBOX_VIEW_ALL, PERMISSION_ACCOUNTING_VIEW_FINANCIALS])
    doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
    if (
        not is_awamir_admin()
        and not has_permission(PERMISSION_CASHBOX_VIEW_ALL)
        and not has_permission(PERMISSION_ACCOUNTING_VIEW_FINANCIALS)
        and doc.user != frappe.session.user
    ):
        frappe.throw(_("You can only view your own cash closure."), frappe.PermissionError)
    _recalculate_totals(doc.name)
    return _closure_detail(doc.name)


@frappe.whitelist()
def accept_cash_closure(closure, actual_cash=0, actual_card=0, actual_transfer=0, actual_other=0, difference_reason=None, cashier_notes=None, idempotency_key=None):
    require_permissions(PERMISSION_CASHBOX_APPROVE)
    payload = {"closure": closure, "actual_cash": actual_cash, "actual_card": actual_card, "actual_transfer": actual_transfer, "actual_other": actual_other, "difference_reason": difference_reason, "cashier_notes": cashier_notes}

    def _execute():
        doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
        if doc.status not in (CLOSURE_STATUS_SUBMITTED, CLOSURE_STATUS_HAS_DIFFERENCE):
            frappe.throw(_("Only submitted cash closures can be accepted."))
        _recalculate_totals(doc.name)
        doc.reload()
        old_status = doc.status
        doc.actual_cash = to_float(actual_cash)
        doc.actual_card = to_float(actual_card)
        doc.actual_transfer = to_float(actual_transfer)
        doc.actual_other = to_float(actual_other)
        doc.actual_total = doc.actual_cash + doc.actual_card + doc.actual_transfer + doc.actual_other
        doc.difference_amount = doc.actual_total - to_float(doc.total_amount)
        if doc.difference_amount and not (difference_reason or cashier_notes):
            frappe.throw(_("Difference reason is required."))
        doc.difference_reason = difference_reason
        doc.cashier = frappe.session.user
        doc.cashier_notes = cashier_notes
        doc.accepted_at = now()
        doc.status = CLOSURE_STATUS_HAS_DIFFERENCE if doc.difference_amount else CLOSURE_STATUS_ACCEPTED
        doc.save(ignore_permissions=True)
        _set_payment_statuses(doc.name, PAYMENT_STATUS_CASHIER_ACCEPTED)
        make_cash_closure_log(doc.name, old_status, doc.status, cashier_notes or difference_reason)
        create_notification(
            doc.user,
            _("Cash Closure Accepted"),
            _("Your daily cash closure was accepted.").format(doc.closure_number),
            None,
            "cash_closure_difference" if doc.status == CLOSURE_STATUS_HAS_DIFFERENCE else "cash_closure_accepted",
        )
        response = get_cash_closure_detail(doc.name)
        make_audit_log("cash_closure_accepted", reference_doctype="Awamir Daily Cash Closure", reference_name=doc.name, method="accept_cash_closure", payload={"actual_cash": actual_cash, "actual_card": actual_card, "actual_transfer": actual_transfer, "actual_other": actual_other, "difference_reason": difference_reason}, response={"closure_id": doc.name, "status": doc.status, "difference_amount": doc.difference_amount})
        return response

    return run_idempotent("accept_cash_closure", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Daily Cash Closure", reference_name=closure)


@frappe.whitelist()
def return_cash_closure(closure, reason, idempotency_key=None):
    require_permissions(PERMISSION_CASHBOX_RETURN)
    reason = (reason or "").strip()
    if not reason:
        frappe.throw(_("Return reason is required."))
    payload = {"closure": closure, "reason": reason}

    def _execute():
        doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
        if doc.status not in (CLOSURE_STATUS_SUBMITTED, CLOSURE_STATUS_HAS_DIFFERENCE):
            frappe.throw(_("Only submitted cash closures can be returned."))
        old_status = doc.status
        doc.status = CLOSURE_STATUS_RETURNED
        doc.cashier = frappe.session.user
        doc.cashier_notes = reason
        doc.save(ignore_permissions=True)
        _set_payment_statuses(doc.name, PAYMENT_STATUS_RETURNED)
        make_cash_closure_log(doc.name, old_status, doc.status, reason)
        create_notification(doc.user, _("Cash Closure Returned"), _("Your daily cash closure was returned: {0}").format(reason), None, "cash_closure_returned")
        response = get_cash_closure_detail(doc.name)
        make_audit_log("cash_closure_returned", reference_doctype="Awamir Daily Cash Closure", reference_name=doc.name, method="return_cash_closure", payload={"reason": reason}, response={"closure_id": doc.name, "status": doc.status})
        return response

    return run_idempotent("return_cash_closure", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Daily Cash Closure", reference_name=closure)


@frappe.whitelist()
def close_cash_closure(closure, idempotency_key=None):
    require_permissions(PERMISSION_CASHBOX_CLOSE_DAY)
    payload = {"closure": closure}

    def _execute():
        doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
        if doc.status == CLOSURE_STATUS_CLOSED:
            response = get_cash_closure_detail(doc.name)
            make_audit_log("cash_closure_close_skipped", status="skipped", reference_doctype="Awamir Daily Cash Closure", reference_name=doc.name, method="close_cash_closure", response=response)
            return response
        if doc.status not in (CLOSURE_STATUS_ACCEPTED, CLOSURE_STATUS_HAS_DIFFERENCE):
            frappe.throw(_("Cash closure must be accepted before it can be closed."))
        old_status = doc.status
        doc.status = CLOSURE_STATUS_CLOSED
        doc.closed_at = now()
        doc.save(ignore_permissions=True)
        _set_payment_statuses(doc.name, PAYMENT_STATUS_READY_FOR_ERP)
        make_cash_closure_log(doc.name, old_status, doc.status, _("Closed by cashier."))
        create_notification(doc.user, _("Cash Closure Closed"), _("Your daily cash closure was closed."), None, "cash_closure_closed")
        response = get_cash_closure_detail(doc.name)
        make_audit_log("cash_closure_closed", reference_doctype="Awamir Daily Cash Closure", reference_name=doc.name, method="close_cash_closure", response={"closure_id": doc.name, "status": doc.status})
        return response

    return run_idempotent("close_cash_closure", payload, _execute, idempotency_key=idempotency_key, reference_doctype="Awamir Daily Cash Closure", reference_name=closure)


@frappe.whitelist()
def get_cash_closure_payments(closure):
    return get_cash_closure_detail(closure).get("payments", [])


@frappe.whitelist()
def get_cash_closure_logs(closure):
    return get_cash_closure_detail(closure).get("logs", [])


def ensure_daily_closures_for_active_users():
    for user in frappe.get_all("User", filters={"enabled": 1, "user_type": "System User"}, pluck="name"):
        roles = frappe.get_roles(user)
        if "Awamir Branch Employee" in roles or "Awamir Driver" in roles:
            closure_type = "driver" if "Awamir Driver" in roles else "branch_employee"
            if not frappe.db.exists("Awamir Daily Cash Closure", {"user": user, "date": frappe.utils.today(), "closure_type": closure_type}):
                frappe.get_doc(
                    {
                        "doctype": "Awamir Daily Cash Closure",
                        "closure_type": closure_type,
                        "user": user,
                        "branch": get_user_branch(user),
                        "date": frappe.utils.today(),
                    }
                ).insert(ignore_permissions=True)


def _attach_open_payments(closure):
    payments = frappe.get_all(
        "Awamir Order Payment",
        filters={
            "received_by_user": closure.user,
            "created_at": ["between", [f"{closure.date} 00:00:00", f"{closure.date} 23:59:59"]],
            "status": ["in", [PAYMENT_STATUS_RECORDED, PAYMENT_STATUS_RETURNED]],
        },
        pluck="name",
    )
    for payment in payments:
        frappe.db.set_value("Awamir Order Payment", payment, {"cash_closure": closure.name, "status": PAYMENT_STATUS_IN_DAILY_CLOSURE})


def _recalculate_totals(closure_name):
    closure = frappe.get_doc("Awamir Daily Cash Closure", closure_name)
    totals = {"Cash": 0, "Card": 0, "Transfer": 0, "Other": 0}
    for payment in frappe.get_all("Awamir Order Payment", filters={"cash_closure": closure.name}, fields=["payment_method", "amount"]):
        totals[payment.payment_method if payment.payment_method in totals else "Other"] += to_float(payment.amount)
    closure.total_cash = totals["Cash"]
    closure.total_card = totals["Card"]
    closure.total_transfer = totals["Transfer"]
    closure.total_other = totals["Other"]
    closure.save(ignore_permissions=True)


def _set_payment_statuses(closure_name, status):
    for payment in frappe.get_all("Awamir Order Payment", filters={"cash_closure": closure_name}, pluck="name"):
        frappe.db.set_value("Awamir Order Payment", payment, "status", status)


def _closure_detail(closure_name, include_logs=True):
    doc = frappe.get_doc("Awamir Daily Cash Closure", closure_name)
    payments = [_payment_row(row.name) for row in frappe.get_all("Awamir Order Payment", filters={"cash_closure": doc.name}, fields=["name"], order_by="created_at asc")]
    logs = frappe.get_all("Awamir Cash Closure Log", filters={"closure": doc.name}, fields=["*"], order_by="created_at asc") if include_logs else []
    data = doc.as_dict()
    data.update(
        {
            "closure_id": doc.name,
            "closure_number": doc.closure_number or doc.name,
            "owner_name": frappe.db.get_value("User", doc.user, "full_name") or doc.user,
            "owner_role_label": _("Driver") if doc.closure_type == "driver" else _("Branch Employee"),
            "payments_count": len(payments),
            "payments": payments,
            "logs": logs,
            "totals": {
                "total_cash": to_float(doc.total_cash),
                "total_card": to_float(doc.total_card),
                "total_transfer": to_float(doc.total_transfer),
                "total_other": to_float(doc.total_other),
                "total_amount": to_float(doc.total_amount),
            },
        }
    )
    return data


def _payment_row(payment_name):
    payment = frappe.get_doc("Awamir Order Payment", payment_name)
    order_number = payment.order
    customer_name = payment.customer
    if payment.order:
        order = frappe.db.get_value("Awamir Order Request", payment.order, ["order_number", "customer_name"], as_dict=True)
        if order:
            order_number = order.order_number or payment.order
            customer_name = order.customer_name or payment.customer
    data = payment.as_dict()
    data.update(
        {
            "payment_id": payment.name,
            "order_number": order_number,
            "customer_name": customer_name,
        }
    )
    return data
