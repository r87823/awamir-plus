import frappe

from awamir_plus.constants import LEGACY_ROLE_TO_SEMANTIC_ROLE
from awamir_plus.permissions import (
    get_user_branch,
    get_user_permissions,
    get_user_production_department,
    get_user_roles,
    require_login,
)


@frappe.whitelist()
def get_current_user():
    require_login()
    user = frappe.get_doc("User", frappe.session.user)
    roles = sorted(role for role in get_user_roles(user.name) if role.startswith("Awamir") or role == "System Manager")
    semantic_roles = sorted(
        {
            LEGACY_ROLE_TO_SEMANTIC_ROLE[role]
            for role in roles
            if role in LEGACY_ROLE_TO_SEMANTIC_ROLE
        }
    )
    driver_profile = {"user": user.name} if "Awamir Driver" in roles else None

    return {
        "id": user.name,
        "full_name": user.full_name,
        "email": user.email,
        "roles": roles,
        "semantic_roles": semantic_roles,
        "permissions": sorted(get_user_permissions(user.name)),
        "branch": get_user_branch(user.name),
        "production_department": get_user_production_department(user.name),
        "driver_profile": driver_profile,
    }
