import frappe

from awamir_plus.permissions import get_user_branch, get_user_production_department, get_user_roles, require_login


@frappe.whitelist()
def get_current_user():
    require_login()
    user = frappe.get_doc("User", frappe.session.user)
    roles = sorted(role for role in get_user_roles(user.name) if role.startswith("Awamir") or role == "System Manager")
    driver_profile = {"user": user.name} if "Awamir Driver" in roles else None

    return {
        "id": user.name,
        "full_name": user.full_name,
        "email": user.email,
        "roles": roles,
        "branch": get_user_branch(user.name),
        "production_department": get_user_production_department(user.name),
        "driver_profile": driver_profile,
    }

