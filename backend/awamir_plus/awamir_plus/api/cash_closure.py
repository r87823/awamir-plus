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
)
from awamir_plus.permissions import get_user_branch, is_awamir_admin, require_roles
from awamir_plus.utils import create_notification, get_cashier_users, make_cash_closure_log, now, to_float


@frappe.whitelist()
def get_my_daily_cash_closure(closure_type=None, date=None):
    require_roles(["Awamir Branch Employee", "Awamir Driver", "Awamir System Admin"])
    date = date or frappe.utils.today()
    user = frappe.session.user
    if is_awamir_admin() and closure_type is None:
        return frappe.get_all("Awamir Daily Cash Closure", filters={"date": date}, fields=["*"], order_by="modified desc")
    closure_type = closure_type or ("driver" if "Awamir Driver" in frappe.get_roles() else "branch_employee")
    closure_name = frappe.db.get_value(
        "Awamir Daily Cash Closure",
        {"user": user, "date": date, "closure_type": closure_type, "status": ["!=", CLOSURE_STATUS_CLOSED]},
        "name",
    )
    if closure_name:
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
    return get_cash_closure_detail(closure.name)


@frappe.whitelist()
def submit_cash_closure(closure):
    require_roles(["Awamir Branch Employee", "Awamir Driver", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
    if not is_awamir_admin() and doc.user != frappe.session.user:
        frappe.throw(_("You can only submit your own cash closure."), frappe.PermissionError)
    old_status = doc.status
    doc.status = CLOSURE_STATUS_SUBMITTED
    doc.submitted_at = now()
    doc.save(ignore_permissions=True)
    frappe.db.set_value("Awamir Order Payment", {"cash_closure": doc.name}, "status", PAYMENT_STATUS_SUBMITTED)
    make_cash_closure_log(doc.name, old_status, doc.status, _("Submitted to cashier."))
    for cashier in get_cashier_users():
        create_notification(cashier, _("Cash Closure Submitted"), _("Cash closure {0} submitted.").format(doc.closure_number), None, "cash_closure_submitted")
    return get_cash_closure_detail(doc.name)


@frappe.whitelist()
def get_submitted_cash_closures(filters=None):
    require_roles(["Awamir Cashier", "Awamir System Admin"])
    query_filters = {"status": ["in", [CLOSURE_STATUS_SUBMITTED, CLOSURE_STATUS_HAS_DIFFERENCE]]}
    return frappe.get_all("Awamir Daily Cash Closure", filters=query_filters, fields=["*"], order_by="submitted_at desc")


@frappe.whitelist()
def get_cash_closure_detail(closure):
    require_roles(["Awamir Branch Employee", "Awamir Driver", "Awamir Cashier", "Awamir Accountant", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
    if not is_awamir_admin() and "Awamir Cashier" not in frappe.get_roles() and "Awamir Accountant" not in frappe.get_roles() and doc.user != frappe.session.user:
        frappe.throw(_("You can only view your own cash closure."), frappe.PermissionError)
    data = doc.as_dict()
    data["payments"] = frappe.get_all("Awamir Order Payment", filters={"cash_closure": doc.name}, fields=["*"], order_by="created_at asc")
    data["logs"] = frappe.get_all("Awamir Cash Closure Log", filters={"closure": doc.name}, fields=["*"], order_by="created_at asc")
    return data


@frappe.whitelist()
def accept_cash_closure(closure, actual_cash=0, actual_card=0, actual_transfer=0, actual_other=0, difference_reason=None, cashier_notes=None):
    require_roles(["Awamir Cashier", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
    old_status = doc.status
    doc.actual_cash = to_float(actual_cash)
    doc.actual_card = to_float(actual_card)
    doc.actual_transfer = to_float(actual_transfer)
    doc.actual_other = to_float(actual_other)
    doc.actual_total = doc.actual_cash + doc.actual_card + doc.actual_transfer + doc.actual_other
    doc.difference_amount = doc.actual_total - to_float(doc.total_amount)
    if doc.difference_amount and not difference_reason:
        frappe.throw(_("Difference reason is required."))
    doc.difference_reason = difference_reason
    doc.cashier = frappe.session.user
    doc.cashier_notes = cashier_notes
    doc.accepted_at = now()
    doc.status = CLOSURE_STATUS_HAS_DIFFERENCE if doc.difference_amount else CLOSURE_STATUS_ACCEPTED
    doc.save(ignore_permissions=True)
    frappe.db.set_value("Awamir Order Payment", {"cash_closure": doc.name}, "status", PAYMENT_STATUS_READY_FOR_ERP)
    make_cash_closure_log(doc.name, old_status, doc.status, cashier_notes or difference_reason)
    create_notification(doc.user, _("Cash Closure Accepted"), _("Your daily cash closure was accepted."), None, "cash_closure_accepted")
    return get_cash_closure_detail(doc.name)


@frappe.whitelist()
def return_cash_closure(closure, reason):
    require_roles(["Awamir Cashier", "Awamir System Admin"])
    if not reason:
        frappe.throw(_("Return reason is required."))
    doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
    old_status = doc.status
    doc.status = CLOSURE_STATUS_RETURNED
    doc.cashier = frappe.session.user
    doc.cashier_notes = reason
    doc.save(ignore_permissions=True)
    frappe.db.set_value("Awamir Order Payment", {"cash_closure": doc.name}, "status", PAYMENT_STATUS_RETURNED)
    make_cash_closure_log(doc.name, old_status, doc.status, reason)
    create_notification(doc.user, _("Cash Closure Returned"), _("Your daily cash closure was returned: {0}").format(reason), None, "cash_closure_returned")
    return get_cash_closure_detail(doc.name)


@frappe.whitelist()
def close_cash_closure(closure):
    require_roles(["Awamir Cashier", "Awamir System Admin"])
    doc = frappe.get_doc("Awamir Daily Cash Closure", closure)
    old_status = doc.status
    doc.status = CLOSURE_STATUS_CLOSED
    doc.closed_at = now()
    doc.save(ignore_permissions=True)
    make_cash_closure_log(doc.name, old_status, doc.status, _("Closed by cashier."))
    create_notification(doc.user, _("Cash Closure Closed"), _("Your daily cash closure was closed."), None, "cash_closure_closed")
    return get_cash_closure_detail(doc.name)


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

