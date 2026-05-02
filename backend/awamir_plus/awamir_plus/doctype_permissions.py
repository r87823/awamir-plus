import frappe

from awamir_plus.constants import (
    ROLE_ACCOUNTANT,
    ROLE_BRANCH_EMPLOYEE,
    ROLE_BRANCH_SUPERVISOR,
    ROLE_CASHIER,
    ROLE_DISTRIBUTION_MANAGER,
    ROLE_DRIVER,
    ROLE_PRODUCTION_USER,
)
from awamir_plus.permissions import get_user_branch, get_user_production_department, is_awamir_admin


def order_query_conditions(user):
    if is_awamir_admin(user):
        return ""
    roles = set(frappe.get_roles(user))
    branch = get_user_branch(user)
    production_department = get_user_production_department(user)
    conditions = []

    if ROLE_BRANCH_EMPLOYEE in roles:
        conditions.append(f"`tabAwamir Order Request`.created_by_user = {frappe.db.escape(user)}")
    if ROLE_BRANCH_SUPERVISOR in roles and branch:
        conditions.append(f"`tabAwamir Order Request`.created_branch = {frappe.db.escape(branch)}")
    if ROLE_DISTRIBUTION_MANAGER in roles:
        conditions.append("`tabAwamir Order Request`.status in ('Sent To Distribution', 'Ready For Delivery', 'Delivery Failed')")
    if ROLE_PRODUCTION_USER in roles and production_department:
        conditions.append(f"`tabAwamir Order Request`.production_department = {frappe.db.escape(production_department)}")
    if ROLE_DRIVER in roles:
        conditions.append(f"`tabAwamir Order Request`.assigned_driver = {frappe.db.escape(user)}")
    if ROLE_CASHIER in roles or ROLE_ACCOUNTANT in roles:
        conditions.append("`tabAwamir Order Request`.name is not null")

    return " or ".join(f"({condition})" for condition in conditions) or "1 = 0"


def order_has_permission(doc, user=None, permission_type=None):
    user = user or frappe.session.user
    if is_awamir_admin(user):
        return True
    roles = set(frappe.get_roles(user))
    if ROLE_BRANCH_EMPLOYEE in roles and doc.created_by_user == user:
        return True
    if ROLE_BRANCH_SUPERVISOR in roles and doc.created_branch == get_user_branch(user):
        return True
    if ROLE_DISTRIBUTION_MANAGER in roles and doc.status in ("Sent To Distribution", "Ready For Delivery", "Delivery Failed"):
        return True
    if ROLE_PRODUCTION_USER in roles and doc.production_department == get_user_production_department(user):
        return True
    if ROLE_DRIVER in roles and doc.assigned_driver == user:
        return True
    if ROLE_CASHIER in roles or ROLE_ACCOUNTANT in roles:
        return permission_type == "read"
    return False


def notification_query_conditions(user):
    if is_awamir_admin(user):
        return ""
    return f"`tabAwamir Notification`.user = {frappe.db.escape(user)}"


def notification_has_permission(doc, user=None, permission_type=None):
    user = user or frappe.session.user
    return is_awamir_admin(user) or doc.user == user


def cash_closure_query_conditions(user):
    if is_awamir_admin(user):
        return ""
    roles = set(frappe.get_roles(user))
    if ROLE_CASHIER in roles:
        return "`tabAwamir Daily Cash Closure`.status in ('Submitted To Cashier', 'Has Difference', 'Returned For Review', 'Accepted', 'Closed')"
    if ROLE_ACCOUNTANT in roles:
        return "`tabAwamir Daily Cash Closure`.status in ('Accepted', 'Closed', 'Has Difference')"
    return f"`tabAwamir Daily Cash Closure`.user = {frappe.db.escape(user)}"


def cash_closure_has_permission(doc, user=None, permission_type=None):
    user = user or frappe.session.user
    if is_awamir_admin(user):
        return True
    roles = set(frappe.get_roles(user))
    if doc.user == user:
        return True
    if ROLE_CASHIER in roles:
        return doc.status in ("Submitted To Cashier", "Has Difference", "Returned For Review", "Accepted", "Closed")
    if ROLE_ACCOUNTANT in roles:
        return doc.status in ("Accepted", "Closed", "Has Difference") and permission_type == "read"
    return False


def delivery_assignment_query_conditions(user):
    if is_awamir_admin(user):
        return ""
    roles = set(frappe.get_roles(user))
    if ROLE_DISTRIBUTION_MANAGER in roles:
        return ""
    if ROLE_DRIVER in roles:
        return f"`tabAwamir Delivery Assignment`.driver = {frappe.db.escape(user)}"
    return "1 = 0"


def delivery_assignment_has_permission(doc, user=None, permission_type=None):
    user = user or frappe.session.user
    if is_awamir_admin(user):
        return True
    roles = set(frappe.get_roles(user))
    if ROLE_DISTRIBUTION_MANAGER in roles:
        return True
    if ROLE_DRIVER in roles and doc.driver == user:
        return True
    return False

