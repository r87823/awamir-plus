import frappe
from frappe import _

from awamir_plus.constants import (
    ROLE_ACCOUNTANT,
    ROLE_BRANCH_EMPLOYEE,
    ROLE_BRANCH_SUPERVISOR,
    ROLE_CASHIER,
    ROLE_DISTRIBUTION_MANAGER,
    ROLE_DRIVER,
    ROLE_PRODUCTION_USER,
    ROLE_SYSTEM_ADMIN,
)


def require_login():
    if frappe.session.user == "Guest":
        frappe.throw(_("Authentication required"), frappe.PermissionError)


def get_user_roles(user=None):
    user = user or frappe.session.user
    return set(frappe.get_roles(user))


def is_awamir_admin(user=None):
    roles = get_user_roles(user)
    return "System Manager" in roles or ROLE_SYSTEM_ADMIN in roles


def has_any_role(allowed_roles, user=None):
    roles = get_user_roles(user)
    return is_awamir_admin(user) or bool(roles.intersection(set(allowed_roles)))


def require_roles(allowed_roles):
    require_login()
    if not has_any_role(allowed_roles):
        frappe.throw(_("You are not allowed to perform this Awamir Plus action."), frappe.PermissionError)


def can_create_order(user=None):
    return has_any_role([ROLE_BRANCH_EMPLOYEE], user)


def can_view_branch_orders(user=None):
    return has_any_role([ROLE_BRANCH_EMPLOYEE, ROLE_BRANCH_SUPERVISOR], user)


def can_approve_orders(user=None):
    return has_any_role([ROLE_BRANCH_SUPERVISOR], user)


def can_view_distribution(user=None):
    return has_any_role([ROLE_DISTRIBUTION_MANAGER], user)


def can_assign_production_department(user=None):
    return has_any_role([ROLE_DISTRIBUTION_MANAGER], user)


def can_view_production_orders(user=None):
    return has_any_role([ROLE_PRODUCTION_USER], user)


def can_update_production_status(user=None):
    return has_any_role([ROLE_PRODUCTION_USER], user)


def can_assign_driver(user=None):
    return has_any_role([ROLE_DISTRIBUTION_MANAGER], user)


def can_view_driver_orders(user=None):
    return has_any_role([ROLE_DRIVER], user)


def can_update_delivery_status(user=None):
    return has_any_role([ROLE_DRIVER], user)


def can_collect_delivery_payment(user=None):
    return has_any_role([ROLE_DRIVER], user)


def can_view_my_cash_closure(user=None):
    return has_any_role([ROLE_BRANCH_EMPLOYEE, ROLE_DRIVER], user)


def can_submit_cash_closure(user=None):
    return has_any_role([ROLE_BRANCH_EMPLOYEE, ROLE_DRIVER], user)


def can_view_cashier_closures(user=None):
    return has_any_role([ROLE_CASHIER], user)


def can_review_cash_closure(user=None):
    return has_any_role([ROLE_CASHIER], user)


def can_manage_accounting(user=None):
    return has_any_role([ROLE_ACCOUNTANT], user)


def can_manage_settings(user=None):
    return is_awamir_admin(user)


def require_branch_scope(doc_branch, user=None):
    if is_awamir_admin(user):
        return
    user_branch = get_user_branch(user)
    if doc_branch and user_branch and doc_branch != user_branch:
        frappe.throw(_("You can only access Awamir Plus documents for your branch."), frappe.PermissionError)


def get_user_branch(user=None):
    user = user or frappe.session.user

    branch = frappe.defaults.get_user_default("Branch", user)
    if branch:
        return branch

    try:
        branch = frappe.db.get_value(
            "User Permission",
            {
                "user": user,
                "allow": "Branch",
                "applicable_for": ["in", ("", None)],
            },
            "for_value",
        )
        if branch:
            return branch
    except Exception:
        pass

    try:
        employee = frappe.db.get_value("Employee", {"user_id": user, "status": "Active"}, "branch")
        if employee:
            return employee
    except Exception:
        pass

    return None


def get_user_production_department(user=None):
    user = user or frappe.session.user
    department = frappe.defaults.get_user_default("Awamir Production Department", user)
    if department:
        return department

    try:
        return frappe.db.get_value(
            "User Permission",
            {
                "user": user,
                "allow": "Awamir Production Department",
                "applicable_for": ["in", ("", None)],
            },
            "for_value",
        )
    except Exception:
        return None


def get_driver_user(user=None):
    user = user or frappe.session.user
    if ROLE_DRIVER in get_user_roles(user) or is_awamir_admin(user):
        return user
    return None
