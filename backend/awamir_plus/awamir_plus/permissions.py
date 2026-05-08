import frappe
from frappe import _

from awamir_plus.constants import (
    PERMISSION_ACCOUNTING_VIEW_FINANCIALS,
    PERMISSION_CASHBOX_APPROVE,
    PERMISSION_CASHBOX_REVIEW,
    PERMISSION_CASHBOX_VIEW_ALL,
    PERMISSION_CASHBOX_VIEW_OWN,
    PERMISSION_DELIVERY_BATCH_ASSIGN_DRIVER,
    PERMISSION_DELIVERY_COLLECT_CASH,
    PERMISSION_DELIVERY_CONFIRM_DELIVERED,
    PERMISSION_DELIVERY_UPDATE_STATUS,
    PERMISSION_DELIVERY_VIEW_ASSIGNED,
    PERMISSION_FULFILLMENT_ASSIGN_DEPARTMENT,
    PERMISSION_FULFILLMENT_VIEW_QUEUE,
    PERMISSION_ORDER_APPROVE,
    PERMISSION_ORDER_CREATE,
    PERMISSION_ORDER_DELIVER_BRANCH,
    PERMISSION_ORDER_VIEW_BRANCH,
    PERMISSION_PRODUCTION_MARK_READY,
    PERMISSION_SYSTEM_FULL_ACCESS,
    PERMISSION_WORK_ORDER_UPDATE_STATUS,
    PERMISSION_WORK_ORDER_VIEW_DEPARTMENT,
    ROLE_ACCOUNTANT,
    ROLE_BRANCH_EMPLOYEE,
    ROLE_BRANCH_SUPERVISOR,
    ROLE_CASHIER,
    ROLE_DISTRIBUTION_MANAGER,
    ROLE_DRIVER,
    ROLE_PRODUCTION_USER,
    ROLE_SYSTEM_ADMIN,
    ROLE_PERMISSION_MAPPING,
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


def get_user_permissions(user=None):
    permissions = set()
    for role in get_user_roles(user):
        permissions.update(ROLE_PERMISSION_MAPPING.get(role, set()))
    if is_awamir_admin(user):
        permissions.add(PERMISSION_SYSTEM_FULL_ACCESS)
        for role_permissions in ROLE_PERMISSION_MAPPING.values():
            permissions.update(role_permissions)
    return permissions


def has_permission(permission, user=None):
    permissions = get_user_permissions(user)
    return PERMISSION_SYSTEM_FULL_ACCESS in permissions or permission in permissions


def has_any_permission(permissions, user=None):
    return any(has_permission(permission, user=user) for permission in permissions)


def has_all_permissions(permissions, user=None):
    return all(has_permission(permission, user=user) for permission in permissions)


def require_permissions(permissions):
    require_login()
    if isinstance(permissions, str):
        permissions = [permissions]
    if not has_all_permissions(permissions):
        frappe.throw(_("You are not allowed to perform this Awamir Plus action."), frappe.PermissionError)


def require_any_permissions(permissions):
    require_login()
    if isinstance(permissions, str):
        permissions = [permissions]
    if not has_any_permission(permissions):
        frappe.throw(_("You are not allowed to perform this Awamir Plus action."), frappe.PermissionError)


def can_create_order(user=None):
    return has_permission(PERMISSION_ORDER_CREATE, user)


def can_view_branch_orders(user=None):
    return has_any_permission([PERMISSION_ORDER_VIEW_BRANCH, PERMISSION_ORDER_CREATE], user)


def can_approve_orders(user=None):
    return has_permission(PERMISSION_ORDER_APPROVE, user)


def can_view_distribution(user=None):
    return has_permission(PERMISSION_FULFILLMENT_VIEW_QUEUE, user)


def can_assign_production_department(user=None):
    return has_permission(PERMISSION_FULFILLMENT_ASSIGN_DEPARTMENT, user)


def can_view_production_orders(user=None):
    return has_permission(PERMISSION_WORK_ORDER_VIEW_DEPARTMENT, user)


def can_update_production_status(user=None):
    return has_any_permission([PERMISSION_WORK_ORDER_UPDATE_STATUS, PERMISSION_PRODUCTION_MARK_READY], user)


def can_assign_driver(user=None):
    return has_permission(PERMISSION_DELIVERY_BATCH_ASSIGN_DRIVER, user)


def can_view_driver_orders(user=None):
    return has_permission(PERMISSION_DELIVERY_VIEW_ASSIGNED, user)


def can_update_delivery_status(user=None):
    return has_permission(PERMISSION_DELIVERY_UPDATE_STATUS, user)


def can_collect_delivery_payment(user=None):
    return has_permission(PERMISSION_DELIVERY_COLLECT_CASH, user)


def can_view_my_cash_closure(user=None):
    return has_permission(PERMISSION_CASHBOX_VIEW_OWN, user)


def can_submit_cash_closure(user=None):
    return has_permission(PERMISSION_CASHBOX_VIEW_OWN, user)


def can_view_cashier_closures(user=None):
    return has_permission(PERMISSION_CASHBOX_VIEW_ALL, user)


def can_review_cash_closure(user=None):
    return has_permission(PERMISSION_CASHBOX_REVIEW, user)


def can_manage_accounting(user=None):
    return has_permission(PERMISSION_ACCOUNTING_VIEW_FINANCIALS, user)


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
